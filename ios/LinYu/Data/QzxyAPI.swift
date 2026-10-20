import Foundation
import LinYuCore

/// 主链路用到的接口。签名与参数一栏都得照抄安卓，别凭感觉改。
extension APIClient {

    /// 发送短信验证码。
    ///
    /// `secret` 由手机号本地推导（见 `SmsSecret`），所以任何手机号都能用。
    /// 这个接口**不能**带认证参数——本身就是用来换认证凭证的。
    func sendVerificationCode(telephone: String, secret: String) async throws {
        try await getVoid(
            "/user/verification/code/get",
            params: [
                "telephone": telephone,
                "typeId": "3",
                "platform": "1",
                "secret": secret
            ],
            includeAuth: false
        )
    }

    /// 短信验证码登录（未注册的手机会自动注册）。
    func login(telephone: String, smsCode: String) async throws -> LoginResult {
        try await post(
            "/user/registerAndLogin",
            params: [
                "telephone": telephone,
                "smsCode": smsCode,
                "type": "5",
                "phoneSystem": "android",
                "version": APIConstants.clientVersion
            ],
            includeAuth: false
        )
    }

    /// 按 MAC 从台账查设备详情。
    ///
    /// 服务端拿 MAC 当**字符串**查，而二维码给的 12 位设备码与台账里存的可能差
    /// 首字节最高两位，所以按候选顺序逐个试——原样第一、换算值第二。
    /// 候选人顺序不能倒：多数学校第一次就命中，倒了会让每次扫码都多一次请求。
    func deviceInfo(code: String) async throws -> DeviceInfo {
        for candidate in MacFormat.lookupVariants(for: code) {
            let info: DeviceInfo? = try await getOptional(
                "/device/info/mac",
                params: ["macAddress": candidate]
            )
            if let info { return info }
        }
        throw ServerError(code: 4004, message: "没查到这台设备，可能不是本校区的设备")
    }
}
