import Foundation

/// 开阀 / 关阀过程中的判读规则与轮询策略。
///
/// 这几条都是"写错不会报错、只会静默出错"的地方，所以单独放成可测的纯逻辑。
public enum ValvePolicy {
    /// 确认开阀 / 关阀的轮询间隔
    public static let confirmIntervalNanoseconds: UInt64 = 800_000_000

    /// 最多轮询几次（8 × 0.8s ≈ 6.4s）
    public static let confirmAttempts = 8
}

/// 开阀是否成功。
///
/// - Important: **不是 `state == 0`**，也不是 HTTP 200 就算成功。
///   实测成功时是 `state == 1 && result == 0`，两个都要看。
public enum OrderOutcome {
    public static func isOpened(state: Int?, result: Int?) -> Bool {
        state == 1 && result == 0
    }
}

/// `queryUsing` 的三态结果。
///
/// - Important: 关阀后"设备到底停没停"的唯一可靠信号就是这个接口；
///   `closeOrder/result/query` 的 `data` 恒为 `null`，拿它当证据等于没确认。
///   请求本身失败时必须返回 `.unknown`——**绝不能当成"已经停了"**。
public enum UsingState: Equatable, Sendable {
    case inUse(orderNo: String)
    case idle
    case unknown

    public static func resolve(errorCode: Int?, orderNo: String?, requestFailed: Bool) -> UsingState {
        if requestFailed { return .unknown }
        if errorCode == ServerErrorCode.orderInProgress.rawValue {
            return .inUse(orderNo: orderNo ?? "")
        }
        if let orderNo, !orderNo.isEmpty {
            return .inUse(orderNo: orderNo)
        }
        if errorCode == nil || errorCode == ServerErrorCode.ok.rawValue {
            return .idle
        }
        return .unknown
    }

    public var isInUse: Bool {
        if case .inUse = self { return true }
        return false
    }
}
