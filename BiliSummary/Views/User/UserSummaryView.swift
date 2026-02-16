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

                HStack {
                    TextField("输入 UID 或 用户名", text: $viewModel.userInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await viewModel.resolveUser(credential: auth.credential) }
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
