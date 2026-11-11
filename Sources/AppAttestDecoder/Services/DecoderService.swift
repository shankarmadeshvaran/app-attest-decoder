import Foundation

enum DecoderFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

enum DecoderService {
    static func decode(input: String, appID: String, challenge: String, assertion: Bool = false, publicKey: String = "", verification: AssertionVerificationInputs = .init()) throws -> DecodeReport {
        guard input.utf8.count <= 4_000_000 else {
            throw DecoderFailure.message("The input exceeds the 4 MB limit. Import a smaller attestation object.")
        }
        if assertion {
            return DecodeReport(text: try AssertionSignatureVerifier.report(assertion: input, publicKey: publicKey, options: verification, appID: appID))
        }
        guard let script = Bundle.appResources.url(forResource: "appattest_decode", withExtension: "py") else {
            throw DecoderFailure.message("The bundled decoder is missing. Rebuild the app.")
        }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else {
            throw DecoderFailure.message("Python 3 is required. Install Apple's Command Line Tools with xcode-select --install, then reopen the app.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("input.txt")
        let output = directory.appendingPathComponent("report.txt")
        let errors = directory.appendingPathComponent("error.txt")
        try input.write(to: source, atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        FileManager.default.createFile(atPath: errors.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: output)
        let stderr = try FileHandle(forWritingTo: errors)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        var arguments = [script.path, "--file", source.path]
        if !appID.isEmpty { arguments += ["--app-id", appID] }
        if !challenge.isEmpty { arguments += ["--challenge", challenge] }
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PYTHONIOENCODING": "utf-8"]
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: errors, encoding: .utf8)) ?? "The decoder could not read this object."
            throw DecoderFailure.message(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let report = try String(contentsOf: output, encoding: .utf8)

        return DecodeReport(text: report)
    }
}
