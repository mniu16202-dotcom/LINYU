import Foundation

/// 短信验证码接口的 `secret` 参数。
///
/// 官方 App 的 secret 看起来像随机值，实际完全由手机号推导：
///
/// ```
/// secret = MD5( 手机号前 3 位 + 手机号后 4 位 + "klcx" )
/// ```
///
/// 因为不含任何设备侧密钥，任何手机号都能在本地算出自己的 secret，
/// 所以短信登录可以纯客户端实现。对应安卓 `utils/SignUtils.kt`。
public enum SmsSecret {
    /// 手机号非法时返回 nil。
    public static func secret(for telephone: String) -> String? {
        guard isWellFormed(telephone) else { return nil }
        let raw = String(telephone.prefix(3)) + String(telephone.suffix(4)) + "klcx"
        return Digest.md5Hex(raw)
    }

    public static func isWellFormed(_ telephone: String) -> Bool {
        telephone.count == 11 && telephone.allSatisfy { $0.isNumber }
    }
}
