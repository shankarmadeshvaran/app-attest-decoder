import SwiftUI

struct AssertionExampleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: Result<DecodeReport, Error> = Result { try Self.exampleReport() }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A known-valid assertion").font(.title2.weight(.semibold))
                    Text("This bundled example leaves your saved inputs unchanged.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(22)
            Divider()
            switch result {
            case .success(let report): ReportView(report: report, stale: false, assertion: true)
            case .failure(let error):
                ContentUnavailableView("Example unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text(error.localizedDescription))
            }
        }.frame(width: 850, height: 680)
    }

    private static func exampleReport() throws -> DecodeReport {
        guard let url = Bundle.appResources.url(forResource: "assertion-example", withExtension: "json") else {
            throw DecoderFailure.message("Bundled example is missing.")
        }
        let example = try JSONDecoder().decode(Example.self, from: Data(contentsOf: url))
        var options = AssertionVerificationInputs()
        options.keyID = example.keyID
        options.publicKeyX = example.publicKeyX
        options.publicKeyY = example.publicKeyY
        options.clientData = example.clientData
        let input = "\n== Example inputs ============================================\npublic key x: \(example.publicKeyX)\npublic key y: \(example.publicKeyY)\nkeyId: \(example.keyID)\nclientData:\n\(example.clientData)\n"
        return DecodeReport(text: input + (try AssertionSignatureVerifier.report(assertion: example.assertion, publicKey: "", options: options, appID: "")))
    }

    private struct Example: Decodable {
        let publicKeyX: String
        let publicKeyY: String
        let keyID: String
        let assertion: String
        let clientData: String
    }
}
