import SwiftUI
import SwiftData

struct WorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sharedAppID = ""
    @State private var loaded = false
    @State private var storageError: String?
    @State private var tool: DecoderTool? = .attestation

    var body: some View {
        NavigationSplitView {
            List(selection: $tool) {
                Section("Decoders") {
                    Label("Attestation Decoder", systemImage: "checkmark.shield").tag(DecoderTool.attestation)
                    Label("Assertion Decoder", systemImage: "signature").tag(DecoderTool.assertion)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 270)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("On-device decoding", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                    Text("Saved locally · No network requests")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
        } detail: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tool == .assertion ? "Assertion Decoder" : "Attestation Decoder")
                            .font(.system(size: 25, weight: .semibold))
                        Text(tool == .assertion ? "Inspect assertion signatures, app identity, and counters." : "Inspect attestation data and compare verification values.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(tool == .assertion ? "APPLE ASSERTION" : "APPLE ATTESTATION")
                        .font(.caption2.weight(.semibold)).tracking(1)
                        .foregroundStyle(.secondary).padding(.top, 7)
                }.padding(.horizontal, 24).padding(.vertical, 20)
                Divider()
                // Keep both workspaces mounted so switching tools preserves input and results.
                if loaded {
                ZStack {
                    ContentView(active: tool != .assertion, appID: $sharedAppID)
                        .opacity(tool == .assertion ? 0 : 1)
                        .allowsHitTesting(tool != .assertion)
                        .accessibilityHidden(tool == .assertion)
                    ContentView(active: tool == .assertion, assertion: true, appID: $sharedAppID)
                        .opacity(tool == .assertion ? 1 : 0)
                        .allowsHitTesting(tool == .assertion)
                        .accessibilityHidden(tool != .assertion)
                }
                } else {
                    ContentUnavailableView("Loading saved details", systemImage: "externaldrive")
                }
                if let storageError {
                    HStack {
                        Label(storageError, systemImage: "exclamationmark.triangle")
                        Button("Retry") { if loaded { saveAppID() } else { restoreAppID() } }
                    }.font(.callout).foregroundStyle(.orange).padding()
                }
            }
        }
        .task { restoreAppID() }
        .onChange(of: sharedAppID) { if loaded { saveAppID() } }
        .navigationTitle(tool == .assertion ? "Assertion Decoder" : "Attestation Decoder")
    }

    private func restoreAppID() {
        guard !loaded else { return }
        do {
            if let shared = try DecoderDraftStore.load(kind: "shared-app-id", context: modelContext) {
                sharedAppID = shared.appID
            } else {
                let attestation = try DecoderDraftStore.load(kind: "attestation", context: modelContext)
                let assertion = try DecoderDraftStore.load(kind: "assertion", context: modelContext)
                sharedAppID = [attestation?.appID, assertion?.appID].compactMap { $0 }.first { !$0.isEmpty } ?? ""
                try DecoderDraftStore.save(kind: "shared-app-id", input: "", appID: sharedAppID, challenge: "", context: modelContext)
            }
            loaded = true
            storageError = nil
        } catch { storageError = "Could not restore shared App ID: \(error.localizedDescription)" }
    }

    private func saveAppID() {
        do {
            try DecoderDraftStore.save(kind: "shared-app-id", input: "", appID: sharedAppID, challenge: "", context: modelContext)
            storageError = nil
        } catch { storageError = "Could not save shared App ID: \(error.localizedDescription)" }
    }

}

private enum DecoderTool: Hashable {
    case attestation, assertion
}
