import Combine
import Foundation
import LinYuCore

/// 一次用水的状态机。
enum ShowerPhase: Equatable {
    case opening
    case using
    case closing
    case settled(amountYuan: Double, seconds: Int, closed: Bool)
    case failed(String)
}

/// 进行中的用水会话。
struct ActiveShower: Identifiable, Equatable {
    let id = UUID()
    var orderNo: String
    var snCode: String
    var deviceName: String
    var kind: DeviceKind
    var startedAt: Date
    var preDeductYuan: Double
    var phase: ShowerPhase
}

/// App 级的会话状态：唯一持有 `AuthContext` 与「当前这一单」的地方。
///
/// 登录态进 Keychain，冷启动时同步恢复，因此不需要异步 `restore()`，
/// 也就不会出现"首帧闪一下登录页"的抖动。
final class AppSession: ObservableObject {

    @Published private(set) var auth: AuthContext?

    /// 当前用水会话。非 nil 时界面显示"使用中"页面。
    @Published private(set) var active: ActiveShower?

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

    // MARK: - 登录

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
        active = nil
        KeychainStore.delete(account: Self.keychainAccount)
    }

    // MARK: - 用水

    /// 下发费率（开阀）并进入"使用中"。失败时抛出，界面负责展示原因。
    @MainActor
    func beginShower(device: DeviceInfo, code: String) async throws {
        let snCode = device.snCode ?? code
        active = ActiveShower(
            orderNo: "",
            snCode: snCode,
            deviceName: device.displayName,
            kind: device.kind,
            startedAt: Date(),
            preDeductYuan: 0,
            phase: .opening
        )
        do {
            let opened = try await ShowerFlow.open(api: api, snCode: snCode)
            active?.orderNo = opened.orderNo
            active?.startedAt = opened.startedAt
            active?.preDeductYuan = opened.preDeductYuan
            active?.phase = .using
        } catch {
            active = nil
            throw error
        }
    }

    /// 关阀 + 结算。失败不抛而是落到 `.failed`，因为此时"还在用水"这件事更重要。
    @MainActor
    func endShower() async {
        guard var current = active else { return }
        guard !current.orderNo.isEmpty else {
            current.phase = .failed("没有拿到订单号，无法关阀。请到设备旁处理。")
            active = current
            return
        }

        current.phase = .closing
        active = current

        do {
            let settled = try await ShowerFlow.close(
                api: api,
                snCode: current.snCode,
                orderNo: current.orderNo,
                startedAt: current.startedAt
            )
            current.phase = .settled(
                amountYuan: settled.amountYuan,
                seconds: settled.seconds,
                closed: settled.closed
            )
        } catch let error as ServerError {
            current.phase = .failed(error.displayMessage)
        } catch {
            current.phase = .failed(error.localizedDescription)
        }
        active = current
    }

    @MainActor
    func clearShower() {
        active = nil
    }
}
