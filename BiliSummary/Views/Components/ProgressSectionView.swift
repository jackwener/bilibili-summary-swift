import SwiftUI

// MARK: - Progress Section View

struct ProgressSectionView: View {
    @ObservedObject var homeVM: HomeViewModel
    @State private var isExpanded = false

    /// Max visible height for the items list when expanded
    private let maxExpandedHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — always visible, tappable
            headerBar
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // Progress bar — always visible
            ProgressView(value: Double(homeVM.completedCount),
                         total: Double(max(homeVM.totalCount, 1)))
                .tint(Color.biliPink)

            // Collapsed: show only actively processing items (compact preview)
            // Expanded: show all items in a scrollable list
            if isExpanded {
                expandedItemsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                collapsedPreview
                    .transition(.opacity)
            }
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("处理进度")
                .font(.headline)

            // Status summary chips
            if homeVM.completedCount > 0 {
                statusChips
            }

            Spacer()

            Text("\(homeVM.completedCount)/\(homeVM.totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Expand/collapse chevron
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? -180 : 0))
        }
    }

    // MARK: - Status Chips

    private var statusChips: some View {
        let counts = statusCounts
        return HStack(spacing: 4) {
            if counts.success > 0 {
                miniChip(count: counts.success, color: .green, icon: "checkmark.circle.fill")
            }
            if counts.failed > 0 {
                miniChip(count: counts.failed, color: .red, icon: "xmark.circle.fill")
            }
            if counts.noSubtitle > 0 {
                miniChip(count: counts.noSubtitle, color: .orange, icon: "exclamationmark.circle.fill")
            }
            if counts.skipped > 0 {
                miniChip(count: counts.skipped, color: .blue, icon: "arrow.right.circle.fill")
            }
        }
    }

    private func miniChip(count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(count)")
        }
        .font(.caption2)
        .foregroundStyle(color)
    }

    // MARK: - Collapsed Preview (only processing items)

    private var collapsedPreview: some View {
        let processing = homeVM.progressItems.filter { $0.status == .processing }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(processing) { item in
                progressRow(item)
            }
        }
    }

    // MARK: - Expanded Items List (scrollable)

    private var expandedItemsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(homeVM.progressItems) { item in
                        progressRow(item)
                            .id(item.id)
                    }
                }
            }
            .frame(maxHeight: maxExpandedHeight)
            .onChange(of: homeVM.progressItems.count) { _, _ in
                // Auto-scroll to the latest processing item
                if let processing = homeVM.progressItems.last(where: { $0.status == .processing }) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(processing.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Progress Row

    private func progressRow(_ item: HomeViewModel.ProgressItem) -> some View {
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

    // MARK: - Status Icon

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

    // MARK: - Helpers

    private struct StatusCounts {
        var success = 0
        var failed = 0
        var noSubtitle = 0
        var skipped = 0
    }

    private var statusCounts: StatusCounts {
        var c = StatusCounts()
        for item in homeVM.progressItems {
            switch item.status {
            case .success: c.success += 1
            case .failed: c.failed += 1
            case .noSubtitle: c.noSubtitle += 1
            case .skipped: c.skipped += 1
            default: break
            }
        }
        return c
    }
}
