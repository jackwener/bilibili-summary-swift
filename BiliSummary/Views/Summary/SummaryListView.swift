import SwiftUI

struct SummaryListView: View {
    @StateObject var viewModel: SummaryListViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("加载总结...")
                } else if viewModel.categories.isEmpty {
                    emptyState
                } else {
                    summaryList
                }
            }
            .navigationTitle("浏览")
            .onAppear {
                viewModel.loadSummaries()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("还没有总结")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("先去总结一些视频吧！")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Summary List

    private var summaryList: some View {
        List {
            ForEach(viewModel.categories) { category in
                Section {
                    if let groups = category.groups {
                        ForEach(groups) { group in
                            DisclosureGroup {
                                ForEach(group.items) { item in
                                    summaryRow(item)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.fill")
                                    Text(group.displayName)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        ForEach(category.items) { item in
                            summaryRow(item)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: category.icon)
                        Text(category.name)
                        Spacer()
                        Text("\(category.items.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Summary Row

    private func summaryRow(_ item: StorageService.SummaryItem) -> some View {
        NavigationLink {
            SummaryDetailView(item: item, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                if !item.cover.isEmpty, let url = URL(string: item.cover) {
                    CachedAsyncImage(url: url, cornerRadius: 8)
                        .frame(width: 80, height: 45)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if !item.authorName.isEmpty {
                            Text(item.authorName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let date = item.date {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !item.hasSubtitle {
                            Label("ASR", systemImage: "waveform")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteSummary(path: item.relativePath)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Summary Detail View

struct SummaryDetailView: View {
    let item: StorageService.SummaryItem
    @ObservedObject var viewModel: SummaryListViewModel
    @State private var summaryContent: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("加载中...")
            } else if let content = summaryContent {
                // Info bar with copyable metadata
                infoBar
                Divider()
                MarkdownWebView(markdown: content)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("无法加载总结")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSummary()
        }
    }

    // MARK: - Info Bar

    private var infoBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if !item.bvid.isEmpty {
                    copyableChip(
                        label: "BV",
                        value: item.bvid,
                        icon: "number.circle.fill"
                    )
                }

                if !item.authorName.isEmpty {
                    copyableChip(
                        label: "UP",
                        value: item.authorName,
                        icon: "person.fill"
                    )
                }

                if item.authorUID > 0 {
                    copyableChip(
                        label: "UID",
                        value: "\(item.authorUID)",
                        icon: "person.badge.key.fill"
                    )
                }

                if let date = item.date {
                    chip(
                        label: "时间",
                        value: date.formatted(date: .abbreviated, time: .shortened),
                        icon: "clock.fill"
                    )
                }

                if !item.hasSubtitle {
                    chip(
                        label: "来源",
                        value: "ASR",
                        icon: "waveform"
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Copyable Chip

    private func copyableChip(label: String, value: String, icon: String) -> some View {
        Button {
            UIPasteboard.general.string = value
        } label: {
            chipContent(label: label, value: value, icon: icon)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("复制 \(label)", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Regular Chip

    private func chip(label: String, value: String, icon: String) -> some View {
        chipContent(label: label, value: value, icon: icon)
    }

    // MARK: - Chip Content

    private func chipContent(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private func loadSummary() async {
        isLoading = true
        summaryContent = viewModel.readSummary(path: item.relativePath)
        isLoading = false
    }
}
