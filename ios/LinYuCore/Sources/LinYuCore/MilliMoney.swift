import Foundation

/// 金额单位换算。
///
/// 这套接口的金额单位**不统一**，而且同名不同单位：
///
/// | 接口 | 字段 | 单位 |
/// |---|---|---|
/// | `/order/consumeOrder/result/query` | `consumeMoney`（数字） | **厘**（1/1000 元） |
/// | `/order/query/account/bill/list` | `consumeMoney`（字符串） | **元** |
/// | `/device/info/mac` | `withholdMoney` | **元** |
/// | `/order/tcpDevice/query/downRateResult` | `preDeductMoney` | **厘** |
///
/// 算错不会报错，只会**静默错 1000 倍**——用了 0.04 元，界面写「¥40.00」。
/// 安卓侧对应 `utils/MoneyFormat.milliToYuan`。
public enum MilliMoney {

    public static func yuan(fromMilli milli: Int) -> Double {
        Double(milli) / 1000.0
    }

    /// 与安卓 `MoneyFormat.format` 一致：保留 3 位小数（精度到厘），
    /// 末位为 0 时收敛成 2 位——有些学校的精度只到分，硬留 3 位会多一个无意义的 0。
    public static func formatted(_ yuan: Double) -> String {
        var text = String(format: "%.3f", yuan)
        if text.hasSuffix("0") { text.removeLast() }
        return text
    }

    public static func withSymbol(_ yuan: Double) -> String {
        "¥" + formatted(yuan)
    }
}
