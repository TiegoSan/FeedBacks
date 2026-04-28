import Foundation

enum FeedbackDocumentReaderError: LocalizedError {
    case missingWordDocument
    case unreadableArchive(String)

    var errorDescription: String? {
        switch self {
        case .missingWordDocument:
            return "The .docx file does not contain word/document.xml."
        case .unreadableArchive(let reason):
            return "Unable to read .docx file: \(reason)"
        }
    }
}

enum FeedbackDocumentReader {
    static func readLines(from url: URL) throws -> [String] {
        if url.pathExtension.lowercased() == "docx" {
            return try readDocxLines(from: url)
        }
        return try readTextLines(from: url)
    }

    static func readTextLines(from url: URL) throws -> [String] {
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .windowsCP1252]
        var lastError: Error?

        for encoding in encodings {
            do {
                let content = try String(contentsOf: url, encoding: encoding)
                return content.components(separatedBy: .newlines)
            } catch {
                lastError = error
            }
        }

        throw MixFeedbackParserError.unreadableFile(lastError?.localizedDescription ?? "unknown error")
    }

    private static func readDocxLines(from url: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, "word/document.xml"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let xmlData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if stderrText.contains("word/document.xml") {
                throw FeedbackDocumentReaderError.missingWordDocument
            }
            throw FeedbackDocumentReaderError.unreadableArchive(
                stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return try DocxLineExtractor.lines(from: xmlData)
    }
}

private final class DocxLineExtractor: NSObject, XMLParserDelegate {
    private var lines: [String] = []
    private var currentLine = ""
    private var currentRun = ""
    private var inTextNode = false
    private var pendingTab = false

    static func lines(from data: Data) throws -> [String] {
        let extractor = DocxLineExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = extractor
        if parser.parse() {
            extractor.finishLine()
            return extractor.lines
        }

        let message = parser.parserError?.localizedDescription ?? "invalid XML"
        throw FeedbackDocumentReaderError.unreadableArchive(message)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "w:p":
            currentLine = ""
        case "w:t":
            inTextNode = true
            currentRun = ""
        case "w:tab":
            pendingTab = true
        case "w:br", "w:cr":
            currentLine.append(" ")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inTextNode else { return }
        currentRun.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "w:t":
            if pendingTab {
                currentLine.append(" ")
                pendingTab = false
            }
            currentLine.append(currentRun)
            currentRun = ""
            inTextNode = false
        case "w:p":
            finishLine()
        default:
            break
        }
    }

    private func finishLine() {
        let trimmed = currentLine
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            lines.append(trimmed)
        }
        currentLine = ""
        currentRun = ""
        pendingTab = false
        inTextNode = false
    }
}
