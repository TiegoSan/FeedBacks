import Foundation

enum FeedbacksImporterError: LocalizedError {
    case missingPython3
    case missingHelperScript
    case missingBundledPythonHome
    case requestEncodingFailed
    case responseMissing
    case responseDecodingFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPython3:
            return "Embedded Python runtime not found in app bundle."
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
        guard let pythonURL = pythonExecutableURL() else {
            throw FeedbacksImporterError.missingPython3
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
        process.executableURL = pythonURL
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
            if !stderrText.isEmpty {
                throw FeedbacksImporterError.importFailed(stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            throw FeedbacksImporterError.responseMissing
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
