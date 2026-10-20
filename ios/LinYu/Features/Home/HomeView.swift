import SwiftUI

/// M1 的落地页：只证明"登录成功且会话可持久化"。
/// M2 起这里会被替换成设备列表 + 扫码入口。
struct HomeView: View {

    @EnvironmentObject private var session: AppSession
    @State private var showingSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if let auth = session.auth {
                    Section("账号") {
                        LabeledContent("手机号", value: auth.telephone)
                        if let name = auth.displayName, !name.isEmpty {
                            LabeledContent("姓名", value: name)
                        }
                        LabeledContent("学校 ID", value: auth.projectId.isEmpty ? "—" : auth.projectId)
                        LabeledContent("账号 ID", value: auth.accountId.isEmpty ? "—" : auth.accountId)
                    }
                }

                Section("下一步") {
                    Label("扫码绑定设备", systemImage: "qrcode.viewfinder")
                    Label("开阀 / 关阀 / 结算", systemImage: "drop.fill")
                    Label("用量与金额", systemImage: "creditcard")
                }
                .foregroundStyle(.secondary)

                Section {
                    Button("退出登录", role: .destructive) {
                        showingSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("淋浴")
            .confirmationDialog("确定退出登录？", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) {
                    session.signOut()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppSession())
}
