import SwiftUI

struct UserSummaryView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @ObservedObject var viewModel: UserSummaryViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search Bar
                searchSection

                // Search Suggestions
                if viewModel.showSuggestions && !viewModel.searchSuggestions.isEmpty {
                    suggestionsSection
                }

                // Resolved User Card
                if let uid = viewModel.resolvedUID {
                    resolvedUserCard(uid: uid)
                }

                // Error
                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Video Count + Start Button (only when user resolved)
                if viewModel.resolvedUID != nil {
                    actionSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("输入 UID 或用户名搜索", text: $viewModel.userInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.userInput) { _, _ in
                        viewModel.updateSearchSuggestions(credential: auth.credential)
                    }
                    .onSubmit {
                        Task { await viewModel.resolveUser(credential: auth.credential) }
                    }

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                if !viewModel.userInput.isEmpty {
                    Button {
                        viewModel.userInput = ""
                        viewModel.searchSuggestions = []
                        viewModel.showSuggestions = false
                        viewModel.resolvedUID = nil
                        viewModel.resolvedName = ""
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await viewModel.resolveUser(credential: auth.credential) }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.userInput.isEmpty ? .gray : Color.biliPink)
            }
            .disabled(viewModel.userInput.isEmpty || viewModel.isResolving)
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("搜索结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.searchSuggestions.count) 个 UP 主")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchSuggestions) { user in
                    Button {
                        Task {
                            await viewModel.selectSuggestion(user, credential: auth.credential)
                        }
                    } label: {
                        suggestionRow(user)
                    }
                    .buttonStyle(.plain)

                    if user.id != viewModel.searchSuggestions.last?.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Suggestion Row

    private func suggestionRow(_ user: SearchUserItem) -> some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = user.avatarURL {
                CachedAsyncImage(url: avatarURL, cornerRadius: 22)
                    .frame(width: 44, height: 44)
                    .clipped()
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(user.uname)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 10) {
                    if let fans = user.fans {
                        Label(formatCount(fans), systemImage: "person.2")
                    }
                    if let videos = user.videos {
                        Label("\(videos) 视频", systemImage: "film")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let usign = user.usign, !usign.isEmpty {
                    Text(usign)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Resolved User Card

    private func resolvedUserCard(uid: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.resolvedName)
                    .font(.headline)
                Text("UID: \(String(uid))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Favorite button
            Button {
                let favVM = UserFavoritesViewModel.shared
                if favVM.isFavorited(uid: uid) {
                    favVM.removeFavorite(uid: uid)
                } else {
                    favVM.addFavorite(uid: uid, name: viewModel.resolvedName)
                }
            } label: {
                let isFav = UserFavoritesViewModel.shared.isFavorited(uid: uid)
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .foregroundStyle(isFav ? .red : .secondary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Label("视频数量", systemImage: "film.stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        if viewModel.videoCount > 1 { viewModel.videoCount -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }

                    Text("\(viewModel.videoCount)")
                        .font(.headline)
                        .monospacedDigit()
                        .frame(minWidth: 30)

                    Button {
                        viewModel.videoCount += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.biliPink)
                    }
                }
                .font(.title3)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task {
                    await viewModel.startSummarize(credential: auth.credential)
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.homeVM.isProcessing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.homeVM.isProcessing ? "处理中..." : "开始总结")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    viewModel.homeVM.isProcessing
                        ? Color.gray.opacity(0.4)
                        : Color.biliPink
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.resolvedUID == nil || viewModel.homeVM.isProcessing)
        }
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f 万", Double(count) / 10000)
        }
        return "\(count) 粉丝"
    }
}
