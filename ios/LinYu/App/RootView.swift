import SwiftUI

/// 顶层路由：只有"已登录 / 未登录"两种状态，不引入导航库。
struct RootView: View {

    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.auth == nil {
                LoginView()
            } else {
                HomeView()
            }
        }
        .animation(.default, value: session.auth)
    }
}

#Preview {
    RootView()
        .environmentObject(AppSession())
}
