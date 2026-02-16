import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @StateObject private var homeVM = HomeViewModel()
    @StateObject private var summaryListVM = SummaryListViewModel()

    var body: some View {
        TabView {
            HomeView(homeVM: homeVM)
                .tabItem {
                    Label("总结", systemImage: "sparkles")
                }

            FavoritesView(homeVM: homeVM)
                .tabItem {
                    Label("收藏", systemImage: "star.fill")
                }

            SummaryListView(viewModel: summaryListVM)
                .tabItem {
                    Label("浏览", systemImage: "books.vertical.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.biliPink)
    }
}
