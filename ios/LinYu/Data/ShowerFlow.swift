import Foundation
import LinYuCore

/// 开阀 / 关阀的编排。
///
/// 只做流程与判读，不碰 UI、不持有状态——状态留在 `AppSession`，
/// 这样这套最容易出错的轮询逻辑能被单独读懂和替换。
enum ShowerFlow {

    struct Opened {
        let orderNo: String
        let startedAt: Date
        let preDeductYuan: Double
        /// 是否拿到了服务端确认（false 表示靠 `queryUsing` 兜底找回的订单号）
        let confirmed: Bool
    }

    struct Settled {
        let amountYuan: Double
        let seconds: Int
        /// 是否确认设备已停（false 表示没拿到可靠信号，界面要提醒用户去确认）
        let closed: Bool
    }

    // MARK: - 开阀

    static func open(api: APIClient, snCode: String) async throws -> Opened {
        try await api.downRate(snCode: snCode)

        for attempt in 0..<ValvePolicy.confirmAttempts {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: ValvePolicy.confirmIntervalNanoseconds)
            }
            let result = try await api.downRateResult(snCode: snCode)
            guard let result,
                  let orderNo = result.orderNumber,
                  OrderOutcome.isOpened(state: result.stateValue, result: result.resultValue) else {
                continue
            }
            let startedAt = result.consumeDate.flatMap(ServerClock.date(fromCompact:)) ?? Date()
            return Opened(
                orderNo: orderNo,
                startedAt: startedAt,
                preDeductYuan: result.preDeductYuan,
                confirmed: true
            )
        }

        // 确认超时：结果**未知**，不是失败。费率可能已经下到设备上、水已经在流，
        // 所以先去问服务端"这台设备有没有进行中的订单"，拿到订单号就还能关阀结算。
        if let using = try? await api.queryUsing(snCode: snCode),
           let orderNo = using?.orderNumber {
            return Opened(orderNo: orderNo, startedAt: Date(), preDeductYuan: 0, confirmed: false)
        }

        throw ServerError(code: -4, message: "开阀结果未知：没有收到服务端确认，也没有查到进行中的订单。请到设备旁确认，必要时手动关阀。")
    }

    // MARK: - 关阀 + 结算

    static func close(
        api: APIClient,
        snCode: String,
        orderNo: String,
        startedAt: Date
    ) async throws -> Settled {
        try await api.closeOrder(snCode: snCode, orderNo: orderNo)

        let closed = await waitUntilStopped(api: api, snCode: snCode)

        var amountYuan = 0.0
        if let consume = try? await api.consumeResult(snCode: snCode, orderNo: orderNo) {
            amountYuan = consume?.consumeYuan ?? 0
        }
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        return Settled(amountYuan: amountYuan, seconds: seconds, closed: closed)
    }

    /// 用 `queryUsing` 判断设备是否真的停了。三态：在用 / 空闲 / 不确定。
    private static func waitUntilStopped(api: APIClient, snCode: String) async -> Bool {
        for attempt in 0..<ValvePolicy.confirmAttempts {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: ValvePolicy.confirmIntervalNanoseconds)
            }
            do {
                let using = try await api.queryUsing(snCode: snCode)
                let state = UsingState.resolve(
                    errorCode: nil,
                    orderNo: using?.orderNumber,
                    requestFailed: false
                )
                switch state {
                case .idle:
                    return true
                case .inUse, .unknown:
                    continue
                }
            } catch let error as ServerError {
                // 307 = 还在用，继续等
                if error.isOrderInProgress { continue }
                // 其他错误算"不确定"，继续试
                continue
            } catch {
                continue
            }
        }
        return false
    }
}
