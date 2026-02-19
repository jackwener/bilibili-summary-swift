import SwiftUI

/// Pure SwiftUI Markdown renderer that handles headings, lists, bold, etc.
/// No WKWebView — works reliably in ScrollView.
struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        let blocks = parseBlocks(markdown)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case heading(level: Int, text: String)
        case listItem(text: String)
        case paragraph(text: String)
        case divider
    }

    // MARK: - Parse Markdown into Blocks

    private func parseBlocks(_ md: String) -> [Block] {
        var blocks: [Block] = []
        let lines = md.components(separatedBy: "\n")
        var paragraphBuffer = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### ") {
                flushParagraph(&paragraphBuffer, &blocks)
                blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                flushParagraph(&paragraphBuffer, &blocks)
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                flushParagraph(&paragraphBuffer, &blocks)
                blocks.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph(&paragraphBuffer, &blocks)
                blocks.append(.listItem(text: String(trimmed.dropFirst(2))))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph(&paragraphBuffer, &blocks)
                blocks.append(.divider)
            } else if trimmed.isEmpty {
                flushParagraph(&paragraphBuffer, &blocks)
            } else {
                // Continuation of paragraph
                if paragraphBuffer.isEmpty {
                    paragraphBuffer = trimmed
                } else {
                    paragraphBuffer += " " + trimmed
                }
            }
        }
        flushParagraph(&paragraphBuffer, &blocks)
        return blocks
    }

    private func flushParagraph(_ buffer: inout String, _ blocks: inout [Block]) {
        if !buffer.isEmpty {
            blocks.append(.paragraph(text: buffer))
            buffer = ""
        }
    }

    // MARK: - Render Block

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineMarkdown(text)
                .font(level == 1 ? .title2 : level == 2 ? .title3 : .headline)
                .fontWeight(.bold)
                .foregroundStyle(level == 2 ? .primary : .primary)
                .padding(.top, level <= 2 ? 12 : 6)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                inlineMarkdown(text)
                    .font(.body)
            }

        case .paragraph(let text):
            inlineMarkdown(text)
                .font(.body)

        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: - Inline Markdown (bold, italic, code)

    private func inlineMarkdown(_ text: String) -> Text {
        // Use SwiftUI's built-in markdown support for inline formatting
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(text)
    }
}

// MARK: - Alias for backward compatibility
typealias MarkdownWebView = MarkdownContentView
