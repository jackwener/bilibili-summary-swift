import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @ObservedObject var homeVM: HomeViewModel
    @State private var selectedMode = 0  // 0=URL, 1=UP主

    @StateObject private var urlVM: URLSummaryViewModel
    @StateObject private var userVM: UserSummaryViewModel

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
        _urlVM = StateObject(wrappedValue: URLSummaryViewModel(homeVM: homeVM))
        _userVM = StateObject(wrappedValue: UserSummaryViewModel(homeVM: homeVM))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Picker
                    Picker("模式", selection: $selectedMode) {
                        Text("视频链接").tag(0)
                        Text("UP 主").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Content
                    switch selectedMode {
                    case 0:
                        URLSummaryView(viewModel: urlVM)
                    case 1:
                        UserSummaryView(viewModel: userVM)
                    default:
                        EmptyView()
                    }

                    // Progress
                    if homeVM.isProcessing {
                        ProgressSection(homeVM: homeVM)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("BiliSummary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    loginButton
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    @State private var showLogin = false

    private var loginButton: some View {
        Button {
            if auth.isLoggedIn {
                // Show logout option
                showLogoutAlert = true
            } else {
                showLogin = true
            }
        } label: {
            if auth.isLoggedIn {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(Color.biliPink)
                    Text(auth.userName.isEmpty ? "已登录" : auth.userName)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            } else {
                Label("登录", systemImage: "person.circle")
            }
        }
        .alert("确认注销", isPresented: $showLogoutAlert) {
            Button("注销", role: .destructive) {
                auth.logout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("注销后将无法获取字幕和收藏夹")
        }
    }

    @State private var showLogoutAlert = false
}

// MARK: - Progress Section

struct ProgressSection: View {
    @ObservedObject var homeVM: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("处理进度")
                    .font(.headline)
                Spacer()
                Text("\(homeVM.completedCount)/\(homeVM.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(homeVM.completedCount), total: Double(max(homeVM.totalCount, 1)))
                .tint(Color.biliPink)

            // Items list
            ForEach(homeVM.progressItems) { item in
                HStack(spacing: 8) {
                    statusIcon(item.status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        if !item.message.isEmpty {
                            Text(item.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }

    @ViewBuilder
    private func statusIcon(_ status: HomeViewModel.ProgressItem.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.gray)
        case .processing:
            ProgressView()
                .scaleEffect(0.7)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .noSubtitle:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}
