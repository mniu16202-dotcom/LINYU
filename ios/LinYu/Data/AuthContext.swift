import Foundation
import LinYuCore

/// 服务端约定的客户端版本与地址。
///
/// `version` 沿用安卓端的 `6.5.28`：这是客户端伪装成官方 App 的版本号，
/// 换了可能触发服务端未知分支，不要随手改。
enum APIConstants {
    static let baseURLString = "https://v3-api.china-qzxy.cn"
    static let clientVersion = "6.5.28"
}

/// 登录成功后拿到的会话凭证。
///
/// 这份东西会进 Keychain，所以必须是纯 `Codable` 值类型。
struct AuthContext: Codable, Equatable {
    var loginCode: String
    var userId: String
    var accountId: String
    var projectId: String
    var telephone: String
    var displayName: String?

    /// 官方 v3 API 固定要求的配置请求头取值。缺了它，蓝牙结算会报 226。
    static let configKeys = "module_list,advertise_type,question_list,service_phone_list,"
        + "banner_list_app,activity_list_app,aliCard_popup_config"

    init(
        loginCode: String,
        userId: String,
        accountId: String,
        projectId: String,
        telephone: String,
        displayName: String?
    ) {
        self.loginCode = loginCode
        self.userId = userId
        self.accountId = accountId
        self.projectId = projectId
        self.telephone = telephone
        self.displayName = displayName
    }

    init?(loginResult: LoginResult, fallbackTelephone: String) {
        guard !loginResult.loginCode.isEmpty else { return nil }
        self.loginCode = loginResult.loginCode
        self.userId = loginResult.userId?.value ?? ""
        self.accountId = loginResult.userAccount?.accountId?.value ?? ""
        self.projectId = loginResult.userAccount?.projectId?.value ?? ""
        self.telephone = loginResult.telephone ?? fallbackTelephone
        self.displayName = loginResult.userAccount?.name
    }

    /// 每个已登录请求都要带的认证参数。
    ///
    /// - Important: `telephone` 与 `telPhone` **两个都要传**，值相同。
    ///   少传 `telPhone` 时 `/settlement/campus/userInfo` 会返回
    ///   `errorCode=1 手机号不能为空`，但 HTTP 仍是 200。
    var authFields: [String: String] {
        [
            "loginCode": loginCode,
            "userId": userId,
            "accountId": accountId,
            "projectId": projectId,
            "telephone": telephone,
            "telPhone": telephone,
            "phoneSystem": "android",
            "version": APIConstants.clientVersion
        ]
    }

    var hasProjectContext: Bool {
        !projectId.isEmpty && projectId != "0"
    }
}
