import Foundation

/// 设备二维码的内容解析。
///
/// 趣智校园设备上的二维码形如：
///
/// ```
/// KLCXKJ-Water,M,AABBCCDDEEFF
/// ```
///
/// **不是 URL、不是 JSON、没有签名**，只有逗号分隔的字段，最后一段就是设备码
/// （12 位十六进制，与设备 MAC 同值）。也正因为没有签名，这是 iOS 端
/// 唯一能拿到设备 MAC 的可靠入口——CoreBluetooth 拿不到对端 MAC。
public enum QRPayload {
    /// 二维码里必须出现的设备名前缀（大小写不敏感）
    public static let devicePrefix = "KLCXKJ-Water"

    /// 从原始扫码内容里取出 12 位设备码；不是本系统的设备码时返回 nil。
    public static func deviceCode(from raw: String) -> String? {
        guard raw.range(of: devicePrefix, options: .caseInsensitive) != nil else { return nil }
        guard let last = raw.split(separator: ",").last else { return nil }
        return MacFormat.normalize(String(last))
    }
}
