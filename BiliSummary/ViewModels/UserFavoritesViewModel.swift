import Foundation

// MARK: - User Favorites ViewModel

@MainActor
final class UserFavoritesViewModel: ObservableObject {
    static let shared = UserFavoritesViewModel()

    @Published var favorites: [UserFavorite] = []
    @Published var isLoading = false

    private let storage = StorageService.shared

    private init() {
        loadFavorites()
    }

    // MARK: - Load

    func loadFavorites() {
        isLoading = true
        favorites = storage.loadUserFavorites()
        isLoading = false
    }

    // MARK: - Check

    func isFavorited(uid: Int) -> Bool {
        favorites.contains { $0.uid == uid }
    }

    // MARK: - Add

    func addFavorite(uid: Int, name: String, avatarURL: String? = nil) {
        storage.addUserFavorite(uid: uid, name: name, avatarURL: avatarURL)
        loadFavorites()
    }

    // MARK: - Remove

    func removeFavorite(uid: Int) {
        storage.removeUserFavorite(uid: uid)
        loadFavorites()
    }
}
