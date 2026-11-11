import SwiftUI
import CryptoKit
import SwiftData
import UniformTypeIdentifiers

struct TextReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ContentView: View {
    var active = true
    var assertion = false
    @Environment(\.modelContext) private var modelContext
    @State private var restored = false
    @State private var storageError: String?
    private var draftKind: String { assertion ? "assertion" : "attestation" }
    @State private var input = ""
    @Binding var appID: String
    @State private var verification = AssertionVerificationInputs()
    @State private var publicKey = ""
    @State private var challenge = ""
    @State private var busy = false
    @State private var report: DecodeReport?
    @State private var decodedInputs: [String] = []
    @State private var error: String?
    @State private var showingExample = false
    @State private var importing = false
    @State private var exporting = false

    private var verificationJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(verification) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
    private var stale: Bool { decodedInputs != [input, appID, challenge, publicKey, verificationJSON] }

    var body: some View {
        VStack(spacing: 0) {
            if let storageError {
                HStack {
                    Label(storageError, systemImage: "externaldrive.badge.exclamationmark")
                    Spacer()
                    Button("Retry") {
                        if restored { saveDraft() } else { restoreDraft() }
                    }
                }.font(.callout).foregroundStyle(.orange).padding()
                Divider()
            }
            if let error {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss", systemImage: "xmark") { self.error = nil }.labelStyle(.iconOnly)
                }.padding().background(.orange.opacity(0.08))
                Divider()
            }
            HSplitView {
                InputView(input: $input, appID: $appID, challenge: $challenge, publicKey: $publicKey, verification: $verification, busy: busy,
                          active: active, assertion: assertion, decode: decode, importFile: { importing = true })
                ReportView(report: report, stale: stale, assertion: assertion).frame(minWidth: 420)
            }
        }
        .frame(minWidth: 850, minHeight: 620)
        .disabled(!active)
        .sheet(isPresented: $showingExample) { AssertionExampleView() }
        .task { restoreDraft() }
        .onChange(of: [input, appID, challenge, publicKey, verificationJSON]) { saveDraft() }
        .toolbar {
            if active {
            ToolbarItemGroup {
                Button("Try example", systemImage: "play.rectangle") { showingExample = true }
                    .help("Explore a known-valid assertion without changing your saved inputs")
                if assertion {
                    Button("Use attestation key", systemImage: "key.horizontal") { importAttestationKey() }
                        .disabled(busy)
                        .help("Use the public key from the last attestation decoded in this app")
                }
                Button("Open input", systemImage: "folder") { importing = true }
                    .keyboardShortcut("o").disabled(busy)
                Button("Copy report", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report?.text ?? "", forType: .string)
                }.disabled(report == nil || stale)
                Button("Export report", systemImage: "square.and.arrow.up") { exporting = true }
                    .keyboardShortcut("s").disabled(report == nil || stale)
                Button("Clear", systemImage: "trash") {
                    input = ""; challenge = ""; publicKey = ""; verification = .init(); report = nil; error = nil
                }.disabled(busy)
            }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .data]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 4_000_000 else { throw DecoderFailure.message("The file exceeds the 4 MB limit.") }
                input = try String(contentsOf: url, encoding: .utf8)
                error = nil
            } catch { self.error = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: TextReportDocument(text: report?.text ?? ""),
                      contentType: .plainText, defaultFilename: assertion ? "Assertion Report" : "App Attest Report") { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
    }

    private func restoreDraft() {
        guard !restored else { return }
        do {
            if let draft = try DecoderDraftStore.load(kind: draftKind, context: modelContext) {
                input = draft.input
                publicKey = draft.publicKey
                if !draft.verificationOptionsJSON.isEmpty {
                    verification = try JSONDecoder().decode(AssertionVerificationInputs.self, from: Data(draft.verificationOptionsJSON.utf8))
                }
                challenge = draft.challenge
            }
            restored = true
            storageError = nil
        } catch {
            storageError = "Could not restore saved details: \(error.localizedDescription)"
        }
    }

    private func saveDraft() {
        guard restored else { return }
        do {
            try DecoderDraftStore.save(kind: draftKind, input: input, appID: appID,
                                       challenge: challenge, publicKey: publicKey, verificationOptionsJSON: verificationJSON, context: modelContext)
            storageError = nil
        } catch {
            storageError = "Details could not be saved: \(error.localizedDescription)"
        }
    }

    private func importAttestationKey() {
        do {
            guard let draft = try DecoderDraftStore.load(kind: "attested-public-key", context: modelContext), !draft.publicKey.isEmpty else {
                throw DecoderFailure.message("Decode the full attestation object in Attestation Decoder first, then use its key here.")
            }
            publicKey = draft.publicKey
            verification.keyID = draft.input
            verification.useCoordinates = false
            verification.publicKeyX = String(draft.publicKey.dropFirst(2).prefix(64))
            verification.publicKeyY = String(draft.publicKey.dropFirst(66))
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func rememberAttestationKey(_ result: DecodeReport) throws {
        func value(_ prefix: String) -> String? {
            result.text.components(separatedBy: "\n").first { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
        }
        guard let x = value("public key x:"), let y = value("public key y:") else { return }
        let point = "04" + x + y
        let bytes = try AssertionSignatureVerifier.hexBytes(point, input: "Attestation public key")
        _ = try P256.Signing.PublicKey(x963Representation: bytes)
        let keyID = Data(SHA256.hash(data: bytes)).base64EncodedString()
        try DecoderDraftStore.save(kind: "attested-public-key", input: keyID, appID: "", challenge: "", publicKey: point, context: modelContext)
    }

    private func decode() {
        let decodedSnapshot = [input, appID, challenge, publicKey, verificationJSON]
        let verificationSnapshot = verification
        let assertionMode = assertion
        let snapshot = [input, appID.trimmingCharacters(in: .whitespacesAndNewlines), challenge, publicKey]
        busy = true
        error = nil
        report = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try DecoderService.decode(input: snapshot[0], appID: snapshot[1], challenge: snapshot[2], assertion: assertionMode, publicKey: snapshot[3], verification: verificationSnapshot)
                }.value
                report = result
                if !assertionMode {
                    do { try rememberAttestationKey(result) }
                    catch { storageError = "Could not save extracted attestation key: \(error.localizedDescription)" }
                }
                decodedInputs = decodedSnapshot
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
