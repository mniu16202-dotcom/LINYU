import Foundation

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
}
