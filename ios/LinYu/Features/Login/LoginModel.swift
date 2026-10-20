import Combine
import Foundation
import LinYuCore

/// 登录页的状态与动作。
///
/// 类本身不加 `@MainActor`：`@StateObject` 的初始化发生在视图构造期，
/// 给整个类加隔离会让初始化变成跨 actor 调用。改为在方法上标记，
/// 效果一样但不会给编译期埋雷。
final class LoginModel: ObservableObject {

    @Published var phone: String = ""
    @Published var code: String = ""
    @Published var cooldown: Int = 0
    @Published var isSending: Bool = false
    @Published var isSigningIn: Bool = false
    @Published var message: String?
    @Published var signedInContext: AuthContext?

    private let api = APIClient()
    private var cooldownTask: Task<Void, Never>?

    // MARK: - 派生状态

    var trimmedPhone: String {
        phone.trimmingCharacters(in: .whitespaces)
    }

    var trimmedCode: String {
        code.trimmingCharacters(in: .whitespaces)
    }

    var canSendCode: Bool {
        SmsSecret.isWellFormed(trimmedPhone) && cooldown == 0 && !isSending
    }

    var canSignIn: Bool {
        SmsSecret.isWellFormed(trimmedPhone) && trimmedCode.count >= 4 && !isSigningIn
    }

    var sendCodeTitle: String {
        if cooldown > 0 { return "\(cooldown)s" }
        return isSending ? "发送中…" : "发送验证码"
    }

    // MARK: - 动作

    @MainActor
    func sendCode() async {
        guard canSendCode else {
            message = "请先输入正确的 11 位手机号"
            return
        }
        guard let secret = SmsSecret.secret(for: trimmedPhone) else {
            message = "手机号格式不正确"
            return
        }

        isSending = true
        message = nil
        do {
            try await api.sendVerificationCode(telephone: trimmedPhone, secret: secret)
            startCooldown()
            message = "验证码已发送，请查收短信"
        } catch {
            message = Self.describe(error)
        }
        isSending = false
    }

    @MainActor
    func signIn() async {
        guard canSignIn else {
            message = "请输入手机号与短信验证码"
            return
        }

        isSigningIn = true
        message = nil
        do {
            let result = try await api.login(telephone: trimmedPhone, smsCode: trimmedCode)
            guard let context = AuthContext(loginResult: result, fallbackTelephone: trimmedPhone) else {
                message = "登录响应缺少 loginCode，无法维持会话"
                isSigningIn = false
                return
            }
            signedInContext = context
        } catch {
            message = Self.describe(error)
        }
        isSigningIn = false
    }

    // MARK: - 冷却计时

    @MainActor
    private func startCooldown() {
        cooldown = 60
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while self.cooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.cooldown -= 1
            }
        }
    }

    // MARK: - 错误文案

    private static func describe(_ error: Error) -> String {
        if let serverError = error as? ServerError {
            return serverError.displayMessage
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "网络未连接"
            case .timedOut:
                return "请求超时，请重试"
            default:
                return "网络异常：\(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}
