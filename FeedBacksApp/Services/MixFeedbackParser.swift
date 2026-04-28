import Foundation

enum MixFeedbackParserError: LocalizedError {
    case fileNotFound
    case invalidDefaultHour
    case unreadableFile(String)
    case noTimecodeFound
    case invalidTimecode(String)
    case invalidCanonicalTimecode

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Input file not found."
        case .invalidDefaultHour:
            return "defaultHour must be in 0...23."
        case .unreadableFile(let reason):
            return "Unable to read text file: \(reason)"
        case .noTimecodeFound:
            return "No timecode found in selected file."
        case .invalidTimecode(let reason):
            return reason
        case .invalidCanonicalTimecode:
            return "Timecode must use HH:MM:SS:FF format."
        }
    }
}

enum MixFeedbackParser {
    private static let tokenPattern = #"(?<!\d)(\d{1,2}(?:\s*[:;\-\.]\s*\d{1,2}){1,3}|\d{3,8})(?!\d)"#
    private static let canonicalPattern = #"^\d{2}:\d{2}:\d{2}:\d{2}$"#

    static func parseFile(
        at path: URL,
        defaultHour: Int,
        sixDigitMode: SixDigitMode
    ) throws -> [FeedbackRow] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw MixFeedbackParserError.fileNotFound
        }
        guard (0...23).contains(defaultHour) else {
            throw MixFeedbackParserError.invalidDefaultHour
        }

        let lines = try readLines(from: path)
        let regex = try NSRegularExpression(pattern: tokenPattern)
        var rows: [FeedbackRow] = []

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let nsrange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: nsrange),
                  let tokenRange = Range(match.range(at: 1), in: trimmed) else {
                continue
            }

            let token = String(trimmed[tokenRange])
            let left = String(trimmed[..<tokenRange.lowerBound])
            let right = String(trimmed[tokenRange.upperBound...])
            let comment = cleanupComment("\(left) \(right)")

            do {
                let normalized = try normalizeTimecodeToken(token, defaultHour: defaultHour, sixDigitMode: sixDigitMode)
                rows.append(
                    FeedbackRow(
                        lineNumber: index + 1,
                        sourceTimecode: token,
                        normalizedTimecode: normalized,
                        comment: comment,
                        issue: "",
                        include: true
                    )
                )
            } catch {
                rows.append(
                    FeedbackRow(
                        lineNumber: index + 1,
                        sourceTimecode: token,
                        normalizedTimecode: "",
                        comment: comment,
                        issue: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                        include: true
                    )
                )
            }
        }

        if rows.isEmpty {
            throw MixFeedbackParserError.noTimecodeFound
        }
        return rows
    }

    static func normalizeTimecodeToken(
        _ raw: String,
        defaultHour: Int,
        sixDigitMode: SixDigitMode
    ) throws -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MixFeedbackParserError.invalidTimecode("Empty timecode")
        }

        if token.range(of: canonicalPattern, options: .regularExpression) != nil {
            return try validateCanonicalTimecode(token)
        }

        if token.range(of: #"[:;\-\.]"#, options: .regularExpression) != nil {
            let compactToken = token.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            let parts = compactToken.split(whereSeparator: { ":;-.".contains($0) }).map(String.init)
            guard parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
                throw MixFeedbackParserError.invalidTimecode("Invalid timecode token '\(token)'")
            }

            switch parts.count {
            case 4:
                return try buildTimecode(hh: int(parts[0]), mm: int(parts[1]), ss: int(parts[2]), ff: int(parts[3]))
            case 3:
                if sixDigitMode == .hhmmss {
                    return try buildTimecode(hh: int(parts[0]), mm: int(parts[1]), ss: int(parts[2]), ff: 0)
                }
                return try buildTimecode(hh: defaultHour, mm: int(parts[0]), ss: int(parts[1]), ff: int(parts[2]))
            case 2:
                return try buildTimecode(hh: defaultHour, mm: int(parts[0]), ss: int(parts[1]), ff: 0)
            default:
                throw MixFeedbackParserError.invalidTimecode("Unsupported segmented timecode '\(token)'")
            }
        }

        let digits = token.filter(\.isNumber)
        switch digits.count {
        case 8:
            return try buildTimecode(
                hh: int(String(digits.prefix(2))),
                mm: int(String(digits.dropFirst(2).prefix(2))),
                ss: int(String(digits.dropFirst(4).prefix(2))),
                ff: int(String(digits.suffix(2)))
            )
        case 6:
            if sixDigitMode == .hhmmss {
                return try buildTimecode(
                    hh: int(String(digits.prefix(2))),
                    mm: int(String(digits.dropFirst(2).prefix(2))),
                    ss: int(String(digits.suffix(2))),
                    ff: 0
                )
            }
            return try buildTimecode(
                hh: defaultHour,
                mm: int(String(digits.prefix(2))),
                ss: int(String(digits.dropFirst(2).prefix(2))),
                ff: int(String(digits.suffix(2)))
            )
        case 4:
            return try buildTimecode(
                hh: defaultHour,
                mm: int(String(digits.prefix(2))),
                ss: int(String(digits.suffix(2))),
                ff: 0
            )
        case 3:
            return try buildTimecode(
                hh: defaultHour,
                mm: int(String(digits.prefix(1))),
                ss: int(String(digits.suffix(2))),
                ff: 0
            )
        default:
            throw MixFeedbackParserError.invalidTimecode("Unsupported timecode token '\(token)'")
        }
    }

    static func validateCanonicalTimecode(_ raw: String) throws -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.range(of: canonicalPattern, options: .regularExpression) != nil else {
            throw MixFeedbackParserError.invalidCanonicalTimecode
        }
        let parts = token.split(separator: ":").map { int(String($0)) }
        return try buildTimecode(hh: parts[0], mm: parts[1], ss: parts[2], ff: parts[3])
    }

    private static func buildTimecode(hh: Int, mm: Int, ss: Int, ff: Int) throws -> String {
        guard (0...23).contains(hh) else {
            throw MixFeedbackParserError.invalidTimecode("Invalid HH value: \(hh)")
        }
        guard (0...59).contains(mm) else {
            throw MixFeedbackParserError.invalidTimecode("Invalid MM value: \(mm)")
        }
        guard (0...59).contains(ss) else {
            throw MixFeedbackParserError.invalidTimecode("Invalid SS value: \(ss)")
        }
        guard (0...99).contains(ff) else {
            throw MixFeedbackParserError.invalidTimecode("Invalid FF value: \(ff)")
        }
        return String(format: "%02d:%02d:%02d:%02d", hh, mm, ss, ff)
    }

    private static func cleanupComment(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.replacingOccurrences(
            of: #"^[\s\-\–\—\:\;\|,\.]+"#,
            with: "",
            options: .regularExpression
        )
        return stripped.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readLines(from url: URL) throws -> [String] {
        try FeedbackDocumentReader.readLines(from: url)
    }

    private static func int(_ string: String) -> Int {
        Int(string) ?? 0
    }
}
