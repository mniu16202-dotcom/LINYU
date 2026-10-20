import SwiftUI

/// 登录后的主页面。
///
/// M2 阶段只放"扫码找设备"和账号信息；M3 起这里会长出"使用中"状态。
struct HomeView: View {

    @EnvironmentObject private var session: AppSession
    @State private var showingScanner = false
    @State private var showingSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("扫码绑定设备", systemImage: "qrcode.viewfinder")
                    }
                } header: {
                    Text("找设备")
                } footer: {
                    Text("对准水表上的二维码；也可以进扫码页后手动输入设备码。")
                }

                if let auth = session.auth {
                    Section("账号") {
                        LabeledContent("手机号", value: auth.telephone)
                        if let name = auth.displayName, !name.isEmpty {
                            LabeledContent("姓名", value: name)
                        }
                        LabeledContent("学校 ID", value: auth.projectId.isEmpty ? "—" : auth.projectId)
                    }
                }

                Section("未接入") {
                    Label("开阀 / 关阀 / 结算（M3–M4）", systemImage: "drop.fill")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        showingSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("淋浴")
            .sheet(isPresented: $showingScanner) {
                ScannerFlowView()
                    .environmentObject(session)
            }
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
