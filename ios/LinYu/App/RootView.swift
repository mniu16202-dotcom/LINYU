import SwiftUI

/// 顶层路由：未登录 → 登录；使用中 → 使用页；否则 → 主页。
///
/// 不用 sheet 做"使用中"，因为它是主界面而不是浮层——这也和安卓的交互一致。
struct RootView: View {

    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.auth == nil {
                LoginView()
            } else if session.active != nil {
                ShowerView()
            } else {
                HomeView()
            }
        }
        .animation(.default, value: session.auth)
        .animation(.default, value: session.active == nil)
    }
}

#Preview {
    RootView()
        .environmentObject(AppSession())
}
