import SwiftUI

struct ReportStatusView: View {
    let check: ReportCheck
    let stale: Bool

    private var presentation: (text: String, symbol: String, color: Color) {
        if stale { return ("Decode again", "arrow.triangle.2.circlepath", .secondary) }
        switch check.outcome {
        case .valid: return ("VALID", "checkmark.seal.fill", .green)
        case .invalid: return ("INVALID", "xmark.seal.fill", .red)
        case .matches: return ("Matches", "checkmark.circle.fill", .green)
        case .mismatch: return ("Mismatch", "xmark.circle.fill", .red)
        case .notChecked: return ("Not checked", "minus.circle", .secondary)
        case .read: return ("Decoded", "doc.text.magnifyingglass", .secondary)
        case .unavailable: return ("Unavailable", "exclamationmark.triangle.fill", .orange)
        }
    }

    var body: some View {
        Label("\(check.label): \(presentation.text)", systemImage: presentation.symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(presentation.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(presentation.color.opacity(0.08), in: Capsule())
            .accessibilityLabel("\(check.label): \(presentation.text)")
    }
}
