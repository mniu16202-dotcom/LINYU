import Combine
import Foundation
import LinYuCore

/// App 级的会话状态：唯一持有 `AuthContext` 的地方。
///
/// 登录态进 Keychain，冷启动时同步恢复，因此不需要异步 `restore()`，
/// 也就不会出现"首帧闪一下登录页"的抖动。
final class AppSession: ObservableObject {

    @Published private(set) var auth: AuthContext?

    let api = APIClient()

    private static let keychainAccount = "session.v1"

    init() {
        guard let data = KeychainStore.load(account: Self.keychainAccount),
              let restored = try? JSONDecoder().decode(AuthContext.self, from: data) else {
            return
        }
        auth = restored
        api.auth = restored
    }

    @MainActor
    func signIn(_ context: AuthContext) {
        auth = context
        api.auth = context
        if let data = try? JSONEncoder().encode(context) {
            KeychainStore.save(data, account: Self.keychainAccount)
        }
    }

    @MainActor
    func signOut() {
        auth = nil
        api.auth = nil
        KeychainStore.delete(account: Self.keychainAccount)
    }
}
