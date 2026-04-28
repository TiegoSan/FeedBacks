import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class FeedBacksViewModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var selectedSourceLabel: String = "No file selected"
    @Published var defaultHour: Int = 1
    @Published var sixDigitMode: SixDigitMode = .hhmmss
    @Published var aafFrameRate: AAFFrameRatePreset = .fps25
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
            selectedSourceLabel = url.lastPathComponent
            parseSelectedFile()
        }
    }

    func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            statusText = "Clipboard does not contain any text."
            return
        }

        selectedFileURL = nil
        selectedSourceLabel = "Clipboard"
        parseText(text)
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

    private func parseText(_ text: String) {
        do {
            rows = try MixFeedbackParser.parseText(
                text,
                defaultHour: defaultHour,
                sixDigitMode: sixDigitMode
            )
            importResult = nil
            resultText = ""
            let issueCount = rows.filter { !$0.issue.isEmpty }.count
            statusText = "Parsed \(rows.count) row(s) from clipboard. \(issueCount) with issue(s)."
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

    func exportAAF() async {
        let included = rows.filter(\.include)
        guard !included.isEmpty else {
            statusText = "No marker row selected."
            return
        }

        guard let outputURL = FeedbacksAAFExporter.chooseOutputURL() else {
            return
        }

        do {
            let payloadRows = try included.map { row in
                FeedbackAAFRow(
                    timecode: try MixFeedbackParser.validateCanonicalTimecode(row.normalizedTimecode),
                    comment: row.comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            isBusy = true
            statusText = "Exporting \(payloadRows.count) marker(s) to AAF..."
            let resolvedMarkerName = markerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Mix Feedback"
                : markerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let request = FeedbackAAFRequest(
                title: resolvedMarkerName,
                markerName: resolvedMarkerName,
                frameRate: aafFrameRate.numericValue,
                rows: payloadRows
            )

            try await Task.detached(priority: .userInitiated) {
                try FeedbacksAAFExporter.exportAAF(request, to: outputURL)
            }.value

            isBusy = false
            importResult = nil
            resultText = "AAF exported to \(outputURL.lastPathComponent)"
            statusText = "Created AAF with \(payloadRows.count) marker(s)."
        } catch {
            isBusy = false
            statusText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
