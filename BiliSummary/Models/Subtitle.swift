import Foundation

// MARK: - Raw Subtitle JSON Body

struct SubtitleBody: Codable {
    let body: [SubtitleItem]?
}

struct SubtitleItem: Codable {
    let from: Double
    let to: Double
    let content: String
}

// MARK: - ASS Time Formatting

extension SubtitleItem {
    /// Format seconds to ASS time: H:MM:SS.CC
    static func assTime(_ seconds: Double) -> String {
        let h = Int(seconds / 3600)
        let m = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%02d:%05.2f", h, m, s)
    }
}

// MARK: - Generate ASS Content

func generateASSContent(title: String, subtitles: [SubtitleItem]) -> String {
    var lines: [String] = []

    let header = """
    [Script Info]
    Title: \(title)
    ScriptType: v4.00+
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,10,10,10,1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    """

    lines.append(header)

    for item in subtitles {
        let start = SubtitleItem.assTime(item.from)
        let end = SubtitleItem.assTime(item.to)
        let content = item.content.replacingOccurrences(of: "\n", with: "\\N")
        lines.append("Dialogue: 0,\(start),\(end),Default,,0,0,0,,\(content)")
    }

    return lines.joined(separator: "\n")
}
