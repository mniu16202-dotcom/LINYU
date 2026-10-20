import Foundation

/// 服务端的时间格式与时长文案。
///
/// `consumeDate` 一类的字段是**紧凑本地时间** `yyyyMMddHHmmss`，
/// 且是「下单那一刻」而非结算时刻。时区固定按东八区解析，
/// 避免 CI/设备时区差异导致单测飘。
public enum ServerClock {
    public static let timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .current

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }

    public static func date(fromCompact value: String) -> Date? {
        guard value.count == 14, value.allSatisfy({ $0.isNumber }) else { return nil }
        return formatter().date(from: value)
    }

    public static func compact(from date: Date) -> String {
        formatter().string(from: date)
    }

    /// `754` → `"12分34秒"`；不足一分钟只给秒。
    public static func durationText(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secondsPart = total % 60
        if minutes == 0 { return "\(secondsPart)秒" }
        return "\(minutes)分\(secondsPart)秒"
    }
}
