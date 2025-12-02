import SwiftUI
internal import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var userVM = UserViewModel()
    @StateObject var publishVM = PublishViewModel()
    
    var body: some View {
        NavigationSplitView {
            // MARK: - 左侧侧边栏 (用户区)
            SidebarView(userVM: userVM)
        } detail: {
            // MARK: - 右侧主视图 (项目操作区)
            if let user = userVM.currentUser {
                ProjectPanelView(publishVM: publishVM, user: user, token: userVM.token)
            } else {
                NoUserView()
            }
        }
        .frame(minWidth: 800, minHeight: 550)
    }
}


// 空状态占位
struct NoUserView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("请先在左侧登录 GitHub")
                .font(.title2)
                .padding(.top)
        }
    }
}
