import LinYuCore
import SwiftUI

/// 设备详情：按设备码查台账并展示，然后下发费率（开阀）。
struct DeviceDetailView: View {

    let code: String
    /// 开阀成功后由上层关闭扫码 sheet，让"使用中"页面露出来
    let onShowerStarted: () -> Void

    @EnvironmentObject private var session: AppSession
    @State private var phase: Phase = .loading
    @State private var isStarting = false
    @State private var startError: String?

    enum Phase {
        case loading
        case failed(String)
        case loaded(DeviceInfo)
    }

    init(code: String, onShowerStarted: @escaping () -> Void) {
        self.code = code
        self.onShowerStarted = onShowerStarted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch phase {
                case .loading:
                    HStack {
                        Spacer()
                        ProgressView("查询设备…")
                        Spacer()
                    }
                    .padding(.top, 80)
                case .failed(let message):
                    failedView(message)
                case .loaded(let device):
                    loadedView(device)
                }
            }
            .padding(20)
        }
        .navigationTitle("设备详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - 子视图

    private func loadedView(_ device: DeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(device.kind.emoji)
                        .font(.title)
                    Text(device.kind.title)
                        .font(.title2.bold())
                }
                Text(device.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                row("类型", device.kind.typeLabel)
                row("SN 码", device.snCode ?? "—")
                row("MAC 地址", device.displayMac)
                row("预扣金额", device.withholdMoneyText)
                row("状态", "空闲")
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

            if device.needsBluetoothControl {
                Text("服务端把这台设备标记为蓝牙表。当前版本只支持云端通道，暂时无法开阀。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await start(device) }
            } label: {
                if isStarting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text(device.kind.startActionTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isStarting)

            if let startError {
                Text(startError)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("设备码 \(code)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("查询失败", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.callout)
            Text("设备码 \(code)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await load() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 40)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - 数据

    private func load() async {
        phase = .loading
        do {
            let info = try await session.api.deviceInfo(code: code)
            phase = .loaded(info)
        } catch let error as ServerError {
            phase = .failed(error.displayMessage)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func start(_ device: DeviceInfo) async {
        isStarting = true
        startError = nil
        do {
            try await session.beginShower(device: device, code: code)
            onShowerStarted()
        } catch let error as ServerError {
            if error.isDeviceOffline {
                startError = "设备不在线（306）：云端下发到不了这台设备。它很可能是不联网的蓝牙表，而当前 iOS 版本只实现了云端通道。"
            } else {
                startError = error.displayMessage
            }
        } catch {
            startError = error.localizedDescription
        }
        isStarting = false
    }
}
