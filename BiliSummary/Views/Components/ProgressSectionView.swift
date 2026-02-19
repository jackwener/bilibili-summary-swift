import SwiftUI

// MARK: - Progress Section View

struct ProgressSectionView: View {
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

            ProgressView(value: Double(homeVM.completedCount),
                         total: Double(max(homeVM.totalCount, 1)))
                .tint(Color.biliPink)

            // All items list
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
