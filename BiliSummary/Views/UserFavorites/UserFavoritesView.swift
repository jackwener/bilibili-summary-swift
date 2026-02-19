import SwiftUI

struct UserFavoritesView: View {
    @ObservedObject private var viewModel = UserFavoritesViewModel.shared
    @EnvironmentObject var auth: BilibiliAuth
    let homeVM: HomeViewModel
    @StateObject private var userVM: UserSummaryViewModel

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
        _userVM = StateObject(wrappedValue: UserSummaryViewModel(homeVM: homeVM))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if viewModel.favorites.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "还没有收藏 UP 主",
                        subtitle: "去收藏夹或视频页面收藏一些 UP 主吧！"
                    )
                } else {
                    favoritesList
                }
            }
            .navigationTitle("UP 主")
            .refreshable {
                viewModel.loadFavorites()
            }
            .onAppear {
                viewModel.loadFavorites()
            }
        }
    }

    // MARK: - Favorites List

    private var favoritesList: some View {
        List {
            ForEach(viewModel.favorites) { favorite in
                NavigationLink {
                    UserSummaryView(viewModel: userVM)
                        .onAppear {
                            userVM.userInput = "\(favorite.uid)"
                            Task {
                                await userVM.resolveUser(credential: auth.credential)
                            }
                        }
                } label: {
                    HStack(spacing: 12) {
                        if let avatarURL = favorite.avatarURL, let url = URL(string: avatarURL) {
                            CachedAsyncImage(url: url, cornerRadius: 24)
                                .frame(width: 48, height: 48)
                                .clipped()
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.gray)
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(favorite.name)
                                .font(.headline)

                            HStack {
                                Text("UID: \(favorite.uid)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(favorite.addedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeFavorite(uid: favorite.uid)
                    } label: {
                        Label("取消收藏", systemImage: "star.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
