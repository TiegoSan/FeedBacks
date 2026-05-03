import Foundation

enum FeedbacksImporterError: LocalizedError {
    case missingPythonHelper
    case missingHelperScript
    case missingBundledPythonHome
    case requestEncodingFailed
    case responseMissing
    case responseDecodingFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPythonHelper:
            return "Embedded Python helper not found in app bundle."
        case .missingHelperScript:
            return "Embedded import helper is missing from the app bundle."
        case .missingBundledPythonHome:
            return "Embedded Python home is missing from the app bundle."
        case .requestEncodingFailed:
            return "Unable to encode import payload."
        case .responseMissing:
            return "Import helper returned no JSON payload."
        case .responseDecodingFailed(let reason):
            return "Unable to decode import response: \(reason)"
        case .importFailed(let message):
            return message
        }
    }
}

enum FeedbacksImporter {
    static func runImport(_ request: FeedbackImportRequest) throws -> FeedbackImportResponse {
        guard let helperURL = pythonExecutableURL() else {
            throw FeedbacksImporterError.missingPythonHelper
        }

        let scriptURL = Bundle.main.url(forResource: "feedbacks_import", withExtension: "py", subdirectory: "Python")
            ?? Bundle.main.url(forResource: "feedbacks_import", withExtension: "py")
        guard let scriptURL,
              let pythonRoot = Bundle.main.resourceURL else {
            throw FeedbacksImporterError.missingHelperScript
        }
        guard let pythonHome = pythonHomeURL() else {
            throw FeedbacksImporterError.missingBundledPythonHome
        }

        let requestData = try JSONEncoder().encode(request)
        let requestFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("feedbacks-import-\(UUID().uuidString).json")
        try requestData.write(to: requestFile, options: .atomic)
        defer { try? FileManager.default.removeItem(at: requestFile) }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [scriptURL.path, requestFile.path]
        process.environment = pythonEnvironment(pythonHome: pythonHome, pythonRoot: pythonRoot)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = stdoutText.split(separator: "\n").map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let jsonLine = lines.last else {
            throw FeedbacksImporterError.importFailed(
                processFailureMessage(
                    defaultMessage: FeedbacksImporterError.responseMissing.errorDescription ?? "Import helper returned no JSON payload.",
                    process: process,
                    stdoutText: stdoutText,
                    stderrText: stderrText
                )
            )
        }

        do {
            let response = try JSONDecoder().decode(FeedbackImportResponse.self, from: Data(jsonLine.utf8))
            if !response.ok, let error = response.error, !error.isEmpty {
                throw FeedbacksImporterError.importFailed(error)
            }
            return response
        } catch let error as FeedbacksImporterError {
            throw error
        } catch {
            throw FeedbacksImporterError.responseDecodingFailed(error.localizedDescription)
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
