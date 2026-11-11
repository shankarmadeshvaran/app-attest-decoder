import SwiftUI

struct ReportView: View {
    let report: DecodeReport?
    let stale: Bool
    var assertion = false
    @State private var selection = "All sections"

    var body: some View {
        if let report {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Decoded report", systemImage: "doc.text.magnifyingglass")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Picker("Section", selection: $selection) {
                        Text("All sections").tag("All sections")
                        ForEach(report.sections) { section in Text(section.title).tag(section.title) }
                    }
                    .labelsHidden().frame(maxWidth: 190)
                }.padding(22)
                if stale {
                    Label("Input changed. Decode again to update this report.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout).foregroundStyle(.orange).padding(.horizontal, 22).padding(.bottom, 12)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(report.sections.filter { selection == "All sections" || $0.title == selection }) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(section.title, systemImage: section.symbol)
                                        .font(.headline).foregroundStyle(.tint)
                                    Spacer()
                                }
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 12) {
                                        ForEach(section.checks) { check in
                                            ReportStatusView(check: check, stale: stale)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(section.checks) { check in
                                            ReportStatusView(check: check, stale: stale)
                                        }
                                    }
                                }
                                if !section.receiptFields.isEmpty {
                                    ForEach(section.receiptFields) { field in
                                        ReceiptFieldView(field: field, stale: stale)
                                    }
                                } else {
                                    Text(section.displayBody)
                                        .font(.system(.callout, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(18)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(.horizontal, 22).padding(.bottom, 22)
                }
                Divider()
                Label("Decoded fields and checks do not establish certificate trust or replace server verification.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).padding(16)
            }
            .onChange(of: report.text) { selection = "All sections" }
        } else {
            ContentUnavailableView {
                Label(assertion ? "Inspect an assertion" : "Inspect an attestation", systemImage: "checkmark.shield")
            } description: {
                Text(assertion ? "Explore authenticator data, the counter, and the ECDSA signature." : "Explore authenticator data, certificates, the nonce, and the receipt in one place.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
