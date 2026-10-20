import Foundation

/// 服务端的金额单位是**分**，显示前必须换算。
public enum MoneyFormat {
    /// `1234` → `"12.34"`；`5` → `"0.05"`。
    public static func yuanString(fromCents cents: Int) -> String {
        let isNegative = cents < 0
        let magnitude = isNegative ? -cents : cents
        let major = magnitude / 100
        let minor = magnitude % 100
        return (isNegative ? "-" : "") + "\(major)." + String(format: "%02d", minor)
    }
}
