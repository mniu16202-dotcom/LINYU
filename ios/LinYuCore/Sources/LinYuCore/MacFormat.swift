import Foundation

/// 「空口广播地址 ↔ 服务端台账 MAC」换算。
///
/// 服务端 `/device/info/mac` 拿 MAC 当**字符串**去查台账，而设备广播出来的地址
/// 与台账里存的不是同一个：按蓝牙规范，随机静态地址的最高两位必须为 1，
/// 于是设备把自己的公开 MAC 置上这两位当作广播地址（`00:...` → `C0:...`）。
///
/// 两个方向都只差首字节的最高两位，其余 40 位相同。对应安卓 `data/MacFormat.kt`。
///
/// - Important: 这不是万能公式。设备若用完全随机的静态地址或 RPA，
///   两个地址毫无关系，换算必然失败——所以查台账时**原样地址永远排第一**。
public enum MacFormat {

    /// 规范化：只保留十六进制字符、12 位、大写。不是 MAC 时返回 nil。
    public static func normalize(_ mac: String) -> String? {
        let hex = mac.filter { $0.isHexDigit }
        guard hex.count == 12 else { return nil }
        return hex.uppercased()
    }

    /// 广播地址 → 台账 MAC（清掉首字节最高两位）。本来就是公开地址时返回 nil。
    public static func publicAddress(of mac: String) -> String? {
        guard let canonical = normalize(mac) else { return nil }
        guard let first = UInt8(canonical.prefix(2), radix: 16) else { return nil }
        guard first & 0xC0 != 0 else { return nil }
        let stripped = String(format: "%02X", first & 0x3F)
        return stripped + String(canonical.dropFirst(2))
    }

    /// 台账 MAC → 蓝牙连接地址（首字节最高两位置 1）。推不出来时返回规范化后的输入。
    public static func connectAddress(for ledgerMac: String) -> String {
        guard let canonical = normalize(ledgerMac) else { return ledgerMac }
        guard let first = UInt8(canonical.prefix(2), radix: 16) else { return canonical }
        guard first & 0xC0 == 0 else { return canonical }
        let raised = String(format: "%02X", first | 0xC0)
        return raised + String(canonical.dropFirst(2))
    }

    /// 查设备信息时依次尝试的候选，**第一个永远是原样**。
    ///
    /// 顺序不能倒：台账里存的就是广播地址的学校必须第一次就命中，
    /// 倒了会让每次扫码都平白多一次请求。
    public static func lookupVariants(for mac: String) -> [String] {
        guard let canonical = normalize(mac) else { return [mac] }
        var variants = [mac]
        if let derived = publicAddress(of: canonical) {
            let lowercase = derived.lowercased()
            if lowercase != mac {
                variants.append(lowercase)
            }
        }
        return variants
    }
}
