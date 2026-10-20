import Foundation

/// 服务端 `errorCode` 的语义。
///
/// - Important: **HTTP 200 不代表成功**，成功也不是 `state == 0`。
///   订单成功语义是 `state == 1 && result == 0`，只存在于响应体里。
public enum ServerErrorCode: Int, Sendable {
    case ok = 0
    /// 签名错（`xfData` / `randomNumber` 大小写写错就会出这个）
    case signatureInvalid = 170
    /// 加密校验失败
    case cryptoFailed = 226
    /// 设备不在线——蓝牙表的云端下发必然回它
    case deviceOffline = 306
    /// 已有订单 / 正在关闭中
    case orderInProgress = 307
    /// 缺参数或查不到
    case parameterMissing = 4004
}

public struct ServerError: Error, Equatable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    /// 设备不在线。对云端通道来说，这通常意味着这台其实是蓝牙表。
    public var isDeviceOffline: Bool { code == ServerErrorCode.deviceOffline.rawValue }

    public var isOrderInProgress: Bool { code == ServerErrorCode.orderInProgress.rawValue }

    /// 会话失效，需要重新登录。
    public var requiresLogin: Bool { code == 401 || code == 403 }

    /// 给用户看的话。优先用服务端原文，缺省时才用内置映射。
    public var displayMessage: String {
        if !message.isEmpty { return message }
        guard let known = ServerErrorCode(rawValue: code) else {
            return "服务端返回错误（\(code)）"
        }
        switch known {
        case .ok:
            return "操作成功"
        case .signatureInvalid:
            return "签名校验失败（170）"
        case .cryptoFailed:
            return "设备数据校验失败（226），请重试"
        case .deviceOffline:
            return "设备不在线（306）"
        case .orderInProgress:
            return "该设备已有订单或正在关闭（307）"
        case .parameterMissing:
            return "参数缺失或设备不存在（4004）"
        }
    }
}
