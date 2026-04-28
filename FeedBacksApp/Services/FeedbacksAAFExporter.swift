import AppKit
import Foundation
import UniformTypeIdentifiers

enum FeedbacksAAFExporterError: LocalizedError {
    case missingPython3
    case missingHelperScript
    case missingBundledPythonHome
    case requestEncodingFailed
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPython3:
            return "Embedded Python runtime not found in app bundle."
        case .missingHelperScript:
            return "Embedded AAF export helper is missing from the app bundle."
        case .missingBundledPythonHome:
            return "Embedded Python home is missing from the app bundle."
        case .requestEncodingFailed:
            return "Unable to encode AAF export payload."
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
        guard let pythonURL = pythonExecutableURL() else {
            throw FeedbacksAAFExporterError.missingPython3
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
        process.executableURL = pythonURL
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

        guard process.terminationStatus == 0 else {
            let message = [stderrText, stdoutText]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? "AAF export failed."
            throw FeedbacksAAFExporterError.exportFailed(message)
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
        guard let bundled = bundledPythonHome() else {
            return nil
        }

        if let python = Bundle.main.url(forResource: "python3", withExtension: nil, subdirectory: "\(bundled.subdir)/bin"),
           FileManager.default.isExecutableFile(atPath: python.path) {
            return python
        }

        if let shim = Bundle.main.url(
            forResource: "Python",
            withExtension: nil,
            subdirectory: "\(bundled.subdir)/lib/Resources/Python.app/Contents/MacOS"
        ),
           FileManager.default.isExecutableFile(atPath: shim.path) {
            return shim
        }

        if let python310 = Bundle.main.url(forResource: "python3.10", withExtension: nil, subdirectory: "\(bundled.subdir)/bin"),
           FileManager.default.isExecutableFile(atPath: python310.path) {
            return python310
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
}
