import Foundation

enum SixDigitMode: String, CaseIterable, Identifiable {
    case hhmmss
    case mmssff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hhmmss:
            return "HHMMSS"
        case .mmssff:
            return "MMSSFF"
        }
    }

    var subtitle: String {
        switch self {
        case .hhmmss:
            return "FF=00"
        case .mmssff:
            return "use Default Hour"
        }
    }
}

struct FeedbackRow: Identifiable, Hashable {
    let id = UUID()
    let lineNumber: Int
    let sourceTimecode: String
    var normalizedTimecode: String
    var comment: String
    var issue: String
    var include: Bool = true
}

struct FeedbackImportRequest: Codable {
    let markerName: String
    let colorIndex: Int
    let rulerName: String
    let rows: [FeedbackImportRow]
}

struct FeedbackImportRow: Codable {
    let timecode: String
    let comment: String
}

struct FeedbackImportResponse: Codable {
    let ok: Bool
    let hostReady: Bool
    let fps: Int?
    let rateToken: String?
    let created: Int
    let attempted: Int
    let failures: [FeedbackImportFailure]
    let error: String?
}

struct FeedbackImportFailure: Codable, Identifiable {
    let id = UUID()
    let name: String?
    let timecode: String?
    let error: String
    let ruler: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case timecode
        case error
        case ruler
    }
}
