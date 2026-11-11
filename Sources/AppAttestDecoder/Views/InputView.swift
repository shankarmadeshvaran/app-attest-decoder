import SwiftUI

struct InputView: View {
    @Binding var input: String
    @Binding var appID: String
    @Binding var challenge: String
    @Binding var publicKey: String
    @Binding var verification: AssertionVerificationInputs
    let busy: Bool
    var active = true
    var assertion = false
    let decode: () -> Void
    let importFile: () -> Void

    var body: some View {
        ScrollView { inputForm }
            .frame(minWidth: 330, idealWidth: 390, maxWidth: 500)
    }

    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label(assertion ? "Assertion object" : "Attestation object", systemImage: "curlybraces")
                    .font(.title3.weight(.semibold))
                Text("Paste the object as hex or Base64.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
                .accessibilityLabel(assertion ? "Assertion input" : "Attestation input")
                .frame(height: assertion ? 140 : 250)
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    if let text = strings.first { input = text }
                }
                Button("Import…", systemImage: "doc.badge.plus", action: importFile)
                Spacer()
                Text("\(input.utf8.count.formatted()) bytes")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Verification inputs").font(.headline)
                Text("App ID").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                TextField("TEAMID.bundle.id", text: $appID)
                    .accessibilityLabel("App ID")
                if assertion {
                    AssertionVerificationInputsView(publicKey: $publicKey, options: $verification)
                } else {
                    Text("Challenge").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    TextField("Exact UTF-8 challenge", text: $challenge)
                        .accessibilityLabel("Challenge")
                    Text("Use the original challenge string passed to attestKey. Whitespace is significant.")
                        .font(.caption).foregroundStyle(.secondary)
                }

            }
            .textFieldStyle(.roundedBorder)
            Button(action: decode) {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "Decoding…" : "Decode object")
                    Spacer()
                    Image(systemName: "arrow.right")
                }.padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(active ? KeyboardShortcut(.return, modifiers: .command) : nil)
            .disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Label("Processed locally on your Mac", systemImage: "lock")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(minWidth: 330, idealWidth: 390, maxWidth: 500)
        .disabled(busy)
    }
}
