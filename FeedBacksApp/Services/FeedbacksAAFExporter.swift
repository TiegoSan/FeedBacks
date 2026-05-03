import AppKit
import Foundation
import UniformTypeIdentifiers

enum FeedbacksAAFExporterError: LocalizedError {
    case missingPythonHelper
    case missingHelperScript
    case missingBundledPythonHome
    case requestEncodingFailed
    case responseMissing
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPythonHelper:
            return "Embedded Python helper not found in app bundle."
        case .missingHelperScript:
            return "Embedded AAF export helper is missing from the app bundle."
        case .missingBundledPythonHome:
            return "Embedded Python home is missing from the app bundle."
        case .requestEncodingFailed:
            return "Unable to encode AAF export payload."
        case .responseMissing:
            return "AAF export helper returned no output."
        case .exportFailed(let message):
            return message
        }
    }
}

enum FeedbacksAAFExporter {
    static func chooseOutputURL() -> URL? {
        let panel = NSSavePanel()
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [UTType(filenameExtension: "aaf") ?? .data]
        panel.nameFieldStringValue = "FeedBacksMarkers.aaf"
        panel.prompt = "Export"
        panel.title = "Export AAF"
        panel.message = "Choose where to save the AAF file."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        let normalizedURL = selectedURL.standardizedFileURL
        if normalizedURL.pathExtension.lowercased() == "aaf" {
            return normalizedURL
        }
        return normalizedURL.appendingPathExtension("aaf")
    }

    static func exportAAF(_ request: FeedbackAAFRequest, to outputURL: URL) throws {
        guard let helperURL = pythonExecutableURL() else {
            throw FeedbacksAAFExporterError.missingPythonHelper
        }

        let scriptURL = Bundle.main.url(forResource: "feedbacks_export_aaf", withExtension: "py", subdirectory: "Python")
            ?? Bundle.main.url(forResource: "feedbacks_export_aaf", withExtension: "py")
        guard let scriptURL,
              let pythonRoot = Bundle.main.resourceURL else {
            throw FeedbacksAAFExporterError.missingHelperScript
        }
        guard let pythonHome = pythonHomeURL() else {
            throw FeedbacksAAFExporterError.missingBundledPythonHome
        }

        let requestData = try JSONEncoder().encode(request)
        let requestFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("feedbacks-aaf-\(UUID().uuidString).json")
        try requestData.write(to: requestFile, options: .atomic)
        defer { try? FileManager.default.removeItem(at: requestFile) }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [scriptURL.path, outputURL.path, requestFile.path]
        process.environment = pythonEnvironment(pythonHome: pythonHome, pythonRoot: pythonRoot)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let accessGranted = outputURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                outputURL.stopAccessingSecurityScopedResource()
            }
        }

        try process.run()
        process.waitUntilExit()

        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stdoutClean = stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderrClean = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw FeedbacksAAFExporterError.exportFailed(
                processFailureMessage(
                    defaultMessage: "AAF export failed.",
                    process: process,
                    stdoutText: stdoutText,
                    stderrText: stderrText
                )
            )
        }

        guard !stdoutClean.isEmpty || !stderrClean.isEmpty else {
            throw FeedbacksAAFExporterError.exportFailed(
                processFailureMessage(
                    defaultMessage: FeedbacksAAFExporterError.responseMissing.errorDescription ?? "AAF export helper returned no output.",
                    process: process,
                    stdoutText: stdoutText,
                    stderrText: stderrText
                )
            )
        }
    }

    private static func bundledPythonHome() -> (subdir: String, url: URL)? {
        guard let resourceRoot = Bundle.main.resourceURL else {
            return nil
        }

        let candidates = ["python-minimal"]
        for subdir in candidates {
            let candidate = resourceRoot.appendingPathComponent(subdir, isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return (subdir, candidate)
            }
        }

        return nil
    }

    private static func pythonHomeURL() -> URL? {
        bundledPythonHome()?.url
    }

    private static func pythonExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent("FeedBacksPythonHelper"),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/MacOS/FeedBacksPythonHelper")
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private static func pythonEnvironment(pythonHome: URL, pythonRoot: URL) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let sitePackages = pythonHome.appendingPathComponent("lib/python3.10/site-packages", isDirectory: true).path
        let extraPaths = [pythonRoot.path, sitePackages]
        let existingPythonPath = env["PYTHONPATH"] ?? ""
        let basePythonPath = extraPaths.joined(separator: ":")
        env["PYTHONPATH"] = existingPythonPath.isEmpty ? basePythonPath : "\(basePythonPath):\(existingPythonPath)"
        env["PYTHONHOME"] = pythonHome.path
        env["PATH"] = "\(pythonHome.appendingPathComponent("bin", isDirectory: true).path):" + (env["PATH"] ?? "")
        env["PYTHONNOUSERSITE"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        return env
    }

    private static func processFailureMessage(
        defaultMessage: String,
        process: Process,
        stdoutText: String,
        stderrText: String
    ) -> String {
        let stderrClean = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdoutClean = stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderrClean.isEmpty {
            return stderrClean
        }
        if !stdoutClean.isEmpty {
            return stdoutClean
        }

        let reason: String
        switch process.terminationReason {
        case .exit:
            reason = "exit"
        case .uncaughtSignal:
            reason = "signal"
        @unknown default:
            reason = "unknown"
        }

        return "\(defaultMessage) Process terminated with \(reason) status \(process.terminationStatus)."
    }
}
