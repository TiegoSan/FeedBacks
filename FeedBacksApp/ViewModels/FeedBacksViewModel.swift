import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class FeedBacksViewModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var defaultHour: Int = 1
    @Published var sixDigitMode: SixDigitMode = .hhmmss
    @Published var markerName: String = "Mix Feedback"
    @Published var colorIndex: Int = 12
    @Published var rulerName: String = "Markers 5"
    @Published var rows: [FeedbackRow] = []
    @Published var statusText: String = "Select a feedback file to begin."
    @Published var resultText: String = ""
    @Published var isBusy = false
    @Published var importResult: FeedbackImportResponse?

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Mix Feedback File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedContentTypes
        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            parseSelectedFile()
        }
    }

    func parseSelectedFile() {
        guard let selectedFileURL else {
            statusText = "Choose a file first."
            return
        }
        do {
            rows = try MixFeedbackParser.parseFile(
                at: selectedFileURL,
                defaultHour: defaultHour,
                sixDigitMode: sixDigitMode
            )
            importResult = nil
            resultText = ""
            let issueCount = rows.filter { !$0.issue.isEmpty }.count
            statusText = "Parsed \(rows.count) row(s). \(issueCount) with issue(s)."
        } catch {
            rows = []
            statusText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func importMarkers() async {
        let trimmedName = markerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = "Marker name is required."
            return
        }

        let included = rows.filter(\.include)
        guard !included.isEmpty else {
            statusText = "No marker row selected."
            return
        }

        do {
            let payloadRows = try included.map { row in
                FeedbackImportRow(
                    timecode: try MixFeedbackParser.validateCanonicalTimecode(row.normalizedTimecode),
                    comment: row.comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            isBusy = true
            statusText = "Importing \(payloadRows.count) marker(s) into Pro Tools..."
            let request = FeedbackImportRequest(
                markerName: trimmedName,
                colorIndex: colorIndex,
                rulerName: rulerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Markers 5" : rulerName.trimmingCharacters(in: .whitespacesAndNewlines),
                rows: payloadRows
            )

            let response = try await Task.detached(priority: .userInitiated) {
                try FeedbacksImporter.runImport(request)
            }.value

            importResult = response
            statusText = "Created \(response.created)/\(response.attempted) marker(s)."
            resultText = buildResultSummary(response)
            isBusy = false
        } catch {
            isBusy = false
            importResult = nil
            statusText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            resultText = ""
        }
    }

    private func buildResultSummary(_ response: FeedbackImportResponse) -> String {
        var fragments: [String] = []
        fragments.append("Created \(response.created) of \(response.attempted)")
        if let fps = response.fps {
            fragments.append("Session fps \(fps)")
        }
        if !response.failures.isEmpty {
            fragments.append("\(response.failures.count) failure(s)")
        }
        return fragments.joined(separator: " • ")
    }

    private var supportedContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .commaSeparatedText, .utf8PlainText, .tabSeparatedText]
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        return types
    }
}
