import Foundation

// MARK: - Storage Service

/// Manages local file storage for summaries and subtitles
final class StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default

    /// Root directory for app data (Documents)
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Summary root directory
    var summaryRoot: URL {
        documentsDirectory.appendingPathComponent("summary")
    }

    /// ASS subtitles root directory
    var assRoot: URL {
        documentsDirectory.appendingPathComponent("ass")
    }

    private init() {}

    // MARK: - Save Summary

    func saveSummary(
        title: String,
        bvid: String,
        url: String,
        duration: Int,
        summary: String,
        outputSubdir: String,
        authorName: String = "",
        authorUID: Int = 0,
        coverURL: String = "",
        hasSubtitle: Bool = true
    ) throws {
        let safeTitle = Summary.sanitizeFilename(title)
        let finalSubdir = hasSubtitle ? outputSubdir : "\(outputSubdir)/no_subtitle"
        let summaryDir = summaryRoot.appendingPathComponent(finalSubdir)

        // Create directory
        try fileManager.createDirectory(at: summaryDir, withIntermediateDirectories: true)

        // Generate markdown
        let generatedAt = Date().formattedForSummary
        let normalizedCover = coverURL.hasPrefix("//") ? "https:\(coverURL)" : coverURL

        var authorLine = ""
        if !authorName.isEmpty && authorUID > 0 {
            authorLine = "**作者**: [\(authorName)](https://space.bilibili.com/\(authorUID))\n"
        } else if !authorName.isEmpty {
            authorLine = "**作者**: \(authorName)\n"
        }

        let minutes = duration / 60
        let seconds = duration % 60
        let durationStr = String(format: "%02d:%02d", minutes, seconds)

        let content = """
        # \(title)

        **BV号**: \(bvid)
        **视频链接**: https://www.bilibili.com/video/\(bvid)
        \(authorLine)**时长**: \(durationStr)
        **生成时间**: \(generatedAt)

        ---

        ## 📝 摘要

        \(summary)
        """

        // Save markdown
        let mdPath = summaryDir.appendingPathComponent("\(safeTitle).md")
        try content.write(to: mdPath, atomically: true, encoding: .utf8)

        // Save meta JSON (compatible with Python version)
        let meta = SummaryMeta(
            title: title,
            bvid: bvid,
            url: url,
            duration: duration,
            authorName: authorName,
            authorUID: authorUID,
            coverURL: normalizedCover,
            generatedAt: generatedAt
        )
        let metaPath = summaryDir.appendingPathComponent("\(safeTitle).meta.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let metaData = try encoder.encode(meta)
        try metaData.write(to: metaPath, options: .atomic)
    }

    // MARK: - Save ASS Subtitle

    func saveASS(title: String, subtitles: [SubtitleItem], outputSubdir: String) throws {
        guard !subtitles.isEmpty else { return }

        let safeTitle = Summary.sanitizeFilename(title)
        let assDir = assRoot.appendingPathComponent(outputSubdir)
        try fileManager.createDirectory(at: assDir, withIntermediateDirectories: true)

        let content = generateASSContent(title: title, subtitles: subtitles)
        let path = assDir.appendingPathComponent("\(safeTitle).ass")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Check if Summary Exists

    func summaryExists(title: String, outputSubdir: String) -> Bool {
        findSummaryRelativePath(title: title, outputSubdir: outputSubdir) != nil
    }

    /// Find the relative path to a summary file (for NavigationLink)
    func findSummaryRelativePath(title: String, outputSubdir: String) -> String? {
        let safeTitle = Summary.sanitizeFilename(title)
        let normalRel = "\(outputSubdir)/\(safeTitle).md"
        let nosubRel = "\(outputSubdir)/no_subtitle/\(safeTitle).md"

        let normalPath = summaryRoot.appendingPathComponent(normalRel)
        if fileManager.fileExists(atPath: normalPath.path) { return normalRel }

        let nosubPath = summaryRoot.appendingPathComponent(nosubRel)
        if fileManager.fileExists(atPath: nosubPath.path) { return nosubRel }

        return nil
    }

    // MARK: - Read Summary Content

    func readSummary(relativePath: String) -> String? {
        let path = summaryRoot.appendingPathComponent(relativePath)
        return try? String(contentsOf: path, encoding: .utf8)
    }

    // MARK: - Delete Summary

    func deleteSummary(relativePath: String) throws {
        let mdPath = summaryRoot.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: mdPath.path) {
            try fileManager.removeItem(at: mdPath)
        }

        // Also delete meta JSON
        let metaPath = mdPath.deletingPathExtension().appendingPathExtension("meta.json")
        if fileManager.fileExists(atPath: metaPath.path) {
            try fileManager.removeItem(at: metaPath)
        }
    }

    // MARK: - List All Summaries

    struct SummaryCategory: Identifiable {
        let id: String         // "standalone", "favorites", "users"
        let name: String
        let icon: String
        let items: [SummaryItem]
        let groups: [UserGroup]?
    }

    struct SummaryItem: Identifiable {
        let id: String          // relativePath as unique key
        let title: String
        let relativePath: String
        let bvid: String
        let cover: String
        let duration: Int
        let authorName: String
        let hasSubtitle: Bool
        let date: Date?
    }

    struct UserGroup: Identifiable {
        let id: String          // uid
        let uid: String
        let displayName: String
        let items: [SummaryItem]
    }

    func listAllSummaries() -> [SummaryCategory] {
        var categories: [SummaryCategory] = []

        // Standalone
        let standaloneDir = summaryRoot.appendingPathComponent("standalone")
        if let items = scanSummaryDirectory(standaloneDir) {
            categories.append(SummaryCategory(
                id: "standalone", name: "独立视频", icon: "link",
                items: items, groups: nil
            ))
        }

        // Favorites
        let favDir = summaryRoot.appendingPathComponent("favorites")
        if let items = scanSummaryDirectory(favDir) {
            categories.append(SummaryCategory(
                id: "favorites", name: "收藏", icon: "star",
                items: items, groups: nil
            ))
        }

        // Users
        let usersDir = summaryRoot.appendingPathComponent("users")
        if fileManager.fileExists(atPath: usersDir.path) {
            var groups: [UserGroup] = []
            if let contents = try? fileManager.contentsOfDirectory(at: usersDir, includingPropertiesForKeys: nil) {
                for folder in contents where folder.hasDirectoryPath {
                    let uid = folder.lastPathComponent
                    let displayName = readUserDisplayName(uidDir: folder) ?? uid
                    if let items = scanSummaryDirectory(folder) {
                        groups.append(UserGroup(id: uid, uid: uid, displayName: displayName, items: items))
                    }
                }
            }
            if !groups.isEmpty {
                let allItems = groups.flatMap(\.items)
                categories.append(SummaryCategory(
                    id: "users", name: "UP 主", icon: "person.2",
                    items: allItems, groups: groups
                ))
            }
        }

        return categories
    }

    // MARK: - Save User Meta

    func saveUserMeta(uid: Int, name: String) {
        let userDir = summaryRoot.appendingPathComponent("users/\(uid)")
        try? fileManager.createDirectory(at: userDir, withIntermediateDirectories: true)
        let metaPath = userDir.appendingPathComponent(".meta.json")
        let meta = ["name": name, "uid": uid] as [String: Any]
        if let data = try? JSONSerialization.data(withJSONObject: meta) {
            try? data.write(to: metaPath)
        }
    }

    // MARK: - Private Helpers

    private func scanSummaryDirectory(_ dir: URL) -> [SummaryItem]? {
        guard fileManager.fileExists(atPath: dir.path) else { return nil }

        var items: [SummaryItem] = []

        if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension == "md" else { continue }

                let isNoSub = fileURL.path.contains("no_subtitle")
                let meta = readMetaJSON(for: fileURL)

                let relPath = fileURL.path.replacingOccurrences(of: summaryRoot.path + "/", with: "")

                // Get file modification date
                let fileDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

                items.append(SummaryItem(
                    id: relPath,
                    title: meta?.title ?? fileURL.deletingPathExtension().lastPathComponent,
                    relativePath: relPath,
                    bvid: meta?.bvid ?? "",
                    cover: meta?.coverURL ?? "",
                    duration: meta?.duration ?? 0,
                    authorName: meta?.authorName ?? "",
                    hasSubtitle: !isNoSub,
                    date: fileDate
                ))
            }
        }

        return items.isEmpty ? nil : items
    }

    private func readMetaJSON(for mdFile: URL) -> SummaryMeta? {
        let metaPath = mdFile.deletingPathExtension().appendingPathExtension("meta.json")
        guard let data = try? Data(contentsOf: metaPath) else { return nil }
        return try? JSONDecoder().decode(SummaryMeta.self, from: data)
    }

    private func readUserDisplayName(uidDir: URL) -> String? {
        let metaPath = uidDir.appendingPathComponent(".meta.json")
        guard let data = try? Data(contentsOf: metaPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["name"] as? String
    }
}
