import LinYuCore
import SwiftUI

/// 设备详情：按设备码查台账并展示。
///
/// M2 的验收点就是这一页——能扫到码、能查到设备、字段与服务端一致。
/// 开阀按钮留到 M3 接。
struct DeviceDetailView: View {

    let code: String

    @EnvironmentObject private var session: AppSession
    @State private var phase: Phase = .loading

    enum Phase {
        case loading
        case failed(String)
        case loaded(DeviceInfo)
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
                // M3：下发费率
            } label: {
                Text("\(device.kind.startActionTitle)（M3 接入）")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)

            Text("设备码 \(code)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("查询失败", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
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
}
