import SwiftUI

struct AssertionVerificationInputsView: View {
    @Binding var publicKey: String
    @Binding var options: AssertionVerificationInputs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attested public key").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            TextField("x · 32 bytes as hex", text: $options.publicKeyX)
                .accessibilityLabel("Public key x")
            TextField("y · 32 bytes as hex", text: $options.publicKeyY)
                .accessibilityLabel("Public key y")
            Text("Enter x and y; the app automatically builds the 65-byte point as 04 || x || y.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Or enter the complete public key point") {
                editor("Public key point", text: $publicKey, height: 70)
                Text("Used when x and y are empty. Enter the 65-byte point as hex; the Key ID is not a public key.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("Key ID · Base64 SHA256(public key point)", text: $options.keyID)
                .accessibilityLabel("Key ID")
            Divider()
            Picker("Signed data", selection: $options.useHash) {
                Text("clientData").tag(false)
                Text("clientDataHash").tag(true)
            }.pickerStyle(.segmented)
            if options.useHash {
                TextField("clientDataHash · exactly 64 hex characters", text: $options.clientDataHash)
                    .accessibilityLabel("clientDataHash")
            } else {
                editor("Exact clientData", text: $options.clientData, height: 130)
                Text("Five lines: METHOD, path[?query], lowercase SHA256(body), timestamp, nonce. Join with LF; no trailing newline. Bytes are used exactly as entered.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("Previous counter · optional UInt32", text: $options.previousCounter)
                .accessibilityLabel("Previous assertion counter")
        }
    }

    private func editor(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.system(.caption, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            .frame(height: height)
            .accessibilityLabel(title)
    }
}
