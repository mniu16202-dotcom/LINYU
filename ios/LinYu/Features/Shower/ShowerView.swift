import LinYuCore
import SwiftUI

/// 使用中页面。`AppSession.active` 非 nil 时由 `RootView` 直接显示这一页，
/// 不走 sheet——安卓那边也是"使用页替换主页面"的交互。
struct ShowerView: View {

    @EnvironmentObject private var session: AppSession

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if let active = session.active {
                content(for: active)
            }
        }
    }

    @ViewBuilder
    private func content(for active: ActiveShower) -> some View {
        switch active.phase {
        case .opening:
            busyView(title: "正在开阀…", subtitle: "下发费率中，请稍等")
        case .using:
            usingView(active)
        case .closing:
            busyView(title: "正在关阀并结算…", subtitle: "请不要离开")
        case .settled(let amount, let seconds, let closed):
            settledView(active, amount: amount, seconds: seconds, closed: closed)
        case .failed(let message):
            failedView(active, message: message)
        }
    }

    // MARK: - 子视图

    private func busyView(title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(title).font(.headline)
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func usingView(_ active: ActiveShower) -> some View {
        VStack(spacing: 18) {
            Spacer()

            Text(active.kind.emoji)
                .font(.system(size: 56))
            Text(active.deviceName)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(active.kind.usingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: active.startedAt, by: 1)) { context in
                Text(ServerClock.durationText(seconds: context.date.timeIntervalSince(active.startedAt)))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            if active.preDeductYuan > 0 {
                Text("预扣 \(MilliMoney.withSymbol(active.preDeductYuan))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("离开 App 后计时会暂停，但设备侧的闲置超时会照常自动关阀。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                Task { await session.endShower() }
            } label: {
                Text("结束用水")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(28)
    }

    private func settledView(_ active: ActiveShower, amount: Double, seconds: Int, closed: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: closed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(closed ? Color.green : Color.orange)

            Text(closed ? "已结束用水" : "已请求关闭，但没收到确认")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("本次消费 \(MilliMoney.withSymbol(amount))")
                .font(.title2)
            Text("用时 \(ServerClock.durationText(seconds: seconds))")
                .foregroundStyle(.secondary)

            if !closed {
                Text("没能从服务端确认设备已停。请回到设备旁确认水是否关掉，必要时再点一次结束用水。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                session.clearShower()
            } label: {
                Text("完成")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }

    private func failedView(_ active: ActiveShower, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.orange)
            Text("操作失败")
                .font(.title3.bold())
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)

            if !active.orderNo.isEmpty {
                Button {
                    Task { await session.endShower() }
                } label: {
                    Text("重试关阀")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }

            Button("返回首页") {
                session.clearShower()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}
