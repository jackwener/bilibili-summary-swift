import SwiftUI

struct UserSummaryView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @ObservedObject var viewModel: UserSummaryViewModel

    var body: some View {
        VStack(spacing: 16) {
            // User Input
            VStack(alignment: .leading, spacing: 8) {
                Label("UP 主", systemImage: "person.fill")
                    .font(.headline)

                VStack(spacing: 0) {
                    HStack {
                        TextField("输入 UID 或 用户名", text: $viewModel.userInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.userInput) { _, _ in
                                viewModel.updateSearchSuggestions(credential: auth.credential)
                            }
                            .onSubmit {
                                Task { await viewModel.resolveUser(credential: auth.credential) }
                            }

                        if viewModel.isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button {
                            Task { await viewModel.resolveUser(credential: auth.credential) }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .padding(10)
                                .background(Color.biliPink)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(viewModel.userInput.isEmpty || viewModel.isResolving)
                    }

                    // Search Suggestions
                    if viewModel.showSuggestions && !viewModel.searchSuggestions.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.searchSuggestions) { user in
                                Button {
                                    Task {
                                        await viewModel.selectSuggestion(user, credential: auth.credential)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        if let avatarURL = user.avatarURL {
                                            CachedAsyncImage(url: avatarURL, cornerRadius: 20)
                                                .frame(width: 40, height: 40)
                                                .clipped()
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                                .overlay {
                                                    Image(systemName: "person.fill")
                                                        .foregroundStyle(.gray)
                                                }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.uname)
                                                .font(.subheadline)

                                            HStack(spacing: 8) {
                                                if let fans = user.fans {
                                                    Label("\(fans) 粉丝", systemImage: "person.2")
                                                }
                                                if let videos = user.videos {
                                                    Label("\(videos) 视频", systemImage: "film")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                            if let usign = user.usign, !usign.isEmpty {
                                                Text(usign)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if user.id != viewModel.searchSuggestions.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if viewModel.isResolving {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("搜索中...")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if let uid = viewModel.resolvedUID {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(viewModel.resolvedName) (UID: \(String(uid)))")
                            .font(.subheadline)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Video Count
            VStack(alignment: .leading, spacing: 8) {
                Label("视频数量", systemImage: "film.stack")
                    .font(.headline)

                HStack {
                    TextField("数量", value: $viewModel.videoCount, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Text("个视频")
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            // Start Button
            Button {
                Task {
                    await viewModel.startSummarize(credential: auth.credential)
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开始总结")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.resolvedUID == nil || viewModel.homeVM.isProcessing
                        ? Color.gray.opacity(0.3)
                        : Color.biliPink
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .font(.headline)
            }
            .disabled(viewModel.resolvedUID == nil || viewModel.homeVM.isProcessing)
        }
        .padding(.horizontal)
    }
}
