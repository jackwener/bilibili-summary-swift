import SwiftUI

struct URLSummaryView: View {
    @EnvironmentObject var auth: BilibiliAuth
    @ObservedObject var viewModel: URLSummaryViewModel

    var body: some View {
        VStack(spacing: 16) {
            // URL Input
            VStack(alignment: .leading, spacing: 8) {
                Label("视频链接", systemImage: "link")
                    .font(.headline)

                TextEditor(text: $viewModel.urlText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )
                    .onChange(of: viewModel.urlText) { _, _ in
                        viewModel.parseURLs()
                    }

                if !viewModel.validationMessage.isEmpty {
                    Text(viewModel.validationMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.parsedBVIDs.isEmpty ? .red : .green)
                }

                Text("每行一个 Bilibili 视频链接")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Start Button
            Button {
                Task {
                    await viewModel.startSummarize(credential: auth.credential)
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开始总结 (\(viewModel.parsedBVIDs.count))")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.parsedBVIDs.isEmpty || viewModel.homeVM.isProcessing
                        ? Color.gray.opacity(0.3)
                        : Color.biliPink
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .font(.headline)
            }
            .disabled(viewModel.parsedBVIDs.isEmpty || viewModel.homeVM.isProcessing)
        }
        .padding(.horizontal)
    }
}
