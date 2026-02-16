import Foundation

// MARK: - Summary List ViewModel

@MainActor
final class SummaryListViewModel: ObservableObject {
    @Published var categories: [StorageService.SummaryCategory] = []
    @Published var isLoading = false
    @Published var selectedContent: String?
    @Published var selectedTitle: String?

    private let storage = StorageService.shared

    // MARK: - Load Summaries

    func loadSummaries() {
        isLoading = true
        categories = storage.listAllSummaries()
        isLoading = false
    }

    // MARK: - Read Summary

    func readSummary(path: String) -> String? {
        storage.readSummary(relativePath: path)
    }

    // MARK: - Delete Summary

    func deleteSummary(path: String) {
        try? storage.deleteSummary(relativePath: path)
        loadSummaries()
    }

    // MARK: - Total Count

    var totalCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}
