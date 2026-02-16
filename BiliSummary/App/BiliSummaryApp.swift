import SwiftUI

@main
struct BiliSummaryApp: App {
    @StateObject private var auth = BilibiliAuth.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(auth)
        }
    }
}
