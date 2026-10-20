import CryptoKit
import Foundation

/// 协议里用到的摘要算法。
///
/// 趣智校园把 MD5 当成签名/口令的传输格式（短信 secret、密码），
/// 安全性很低，但客户端必须照抄，改不了。
public enum Digest {
    /// 32 位小写十六进制 MD5。
    public static func md5Hex(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
