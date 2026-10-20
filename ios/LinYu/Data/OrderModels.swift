import Foundation
import LinYuCore

/// `/order/tcpDevice/query/downRateResult` 的 `data`。
///
/// 字段全部宽容解码：`state` / `result` 有的学校给数字、有的给字符串，
/// 硬编码成 `Int` 会在某些环境上直接解析失败，而失败会被误读成"还没开好"。
struct RateOrderResult: Decodable {
    let orderNo: LossyString?
    let state: LossyString?
    let resultCode: LossyString?
    let consumeDate: String?
    /// 预扣金额，单位**厘**
    let preDeductMoney: LossyDouble?
    /// 自动关停秒数（部分学校不返回）
    let autoDisConTime: LossyString?

    private enum CodingKeys: String, CodingKey {
        case orderNo
        case state
        case resultCode = "result"
        case consumeDate
        case preDeductMoney
        case autoDisConTime
    }

    var stateValue: Int? { state.flatMap { Int($0.value) } }
    var resultValue: Int? { resultCode.flatMap { Int($0.value) } }
    var orderNumber: String? {
        guard let value = orderNo?.value, !value.isEmpty else { return nil }
        return value
    }
    /// 厘 → 元
    var preDeductYuan: Double { MilliMoney.yuan(fromMilli: Int(preDeductMoney?.value ?? 0)) }
    var autoDisConSeconds: Int? { autoDisConTime.flatMap { Int($0.value) } }
}

/// `/order/tcpDevice/query/rateOrder/using` 的 `data`。
///
/// `orderNo` 为 null 表示没有进行中的订单；`isOwner` 为 false 表示是**别人**的单，
/// 绝不能当成自己的恢复。
struct UsingResult: Decodable {
    let orderNo: LossyString?
    let isOwner: Bool?

    var orderNumber: String? {
        guard let value = orderNo?.value, !value.isEmpty else { return nil }
        return value
    }
}

/// `/order/consumeOrder/result/query` 的 `data`。
struct ConsumeResult: Decodable {
    /// 单位**厘**（1/1000 元），不是元、也不是分
    let consumeMoney: LossyDouble?
    let consumeTime: String?
    let consumeDate: String?
    let orderNo: LossyString?

    var consumeYuan: Double { MilliMoney.yuan(fromMilli: Int(consumeMoney?.value ?? 0)) }
}
