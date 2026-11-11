import SwiftUI

struct ReceiptFieldView: View {
    let field: ReceiptField
    let stale: Bool
    @State private var expanded = false
    @State private var copied = false

    private var isLong: Bool { field.value.count > 120 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(field.name).font(.callout.weight(.semibold))
                Spacer()
                if isLong {
                    Button(expanded ? "Show less" : "Show full") { expanded.toggle() }
                        .buttonStyle(.borderless)
                }
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(field.value, forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(stale)
                .help("Copy the complete \(field.name) value")
                .accessibilityLabel("Copy full \(field.name)")
            }
            Text(field.value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(isLong && !expanded ? 2 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isLong && !expanded {
                Text("Preview · Copy retrieves the complete value")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Divider()
        }
        .onChange(of: field.value) { expanded = false; copied = false }
    }
}
