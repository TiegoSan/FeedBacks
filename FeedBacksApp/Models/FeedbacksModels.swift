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

enum AAFFrameRatePreset: String, CaseIterable, Identifiable {
    case fps23976 = "23.976"
    case fps24 = "24"
    case fps25 = "25"
    case fps2997 = "29.97"
    case fps30 = "30"

    var id: String { rawValue }

    var title: String { rawValue }

    var numericValue: Double {
        switch self {
        case .fps23976: return 23.976
        case .fps24: return 24.0
        case .fps25: return 25.0
        case .fps2997: return 29.97
        case .fps30: return 30.0
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

struct FeedbackAAFRequest: Codable {
    let title: String
    let markerName: String
    let frameRate: Double
    let rows: [FeedbackAAFRow]
}

struct FeedbackAAFRow: Codable {
    let timecode: String
    let comment: String
}
