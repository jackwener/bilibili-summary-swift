import Foundation
import SwiftUI

// MARK: - Date Formatting

extension Date {
    var formattedForSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
}

// MARK: - String Helpers

extension String {
    /// Extract BV ID from a Bilibili URL
    func extractBVID() -> String? {
        let pattern = "BV[a-zA-Z0-9]+"
        guard let range = self.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(self[range])
    }

    /// Sanitize for use as filename
    var sanitizedFilename: String {
        Summary.sanitizeFilename(self)
    }

    /// Truncate to a maximum character count
    func truncated(to maxLength: Int) -> String {
        if self.count <= maxLength { return self }
        return String(self.prefix(maxLength))
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Color Theme

extension Color {
    static let biliPink = Color(red: 0.98, green: 0.44, blue: 0.55)
    static let biliBlue = Color(red: 0.0, green: 0.686, blue: 0.976)
    static let surfaceBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
}

// MARK: - AsyncImage with placeholder

struct CachedAsyncImage: View {
    let url: URL?
    let cornerRadius: CGFloat

    init(url: URL?, cornerRadius: CGFloat = 8) {
        self.url = url
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        ProgressView()
                    }
            @unknown default:
                EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
