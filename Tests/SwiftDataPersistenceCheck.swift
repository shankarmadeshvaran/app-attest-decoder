import Foundation
import SwiftData

@main
struct DraftCheck {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let schema = Schema(versionedSchema: DecoderSchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: DecoderMigrationPlan.self, configurations: [config])
        let context = ModelContext(container)
        if CommandLine.arguments[1] == "write" {
            try DecoderDraftStore.save(kind: "attestation", input: "aabb", appID: "TEAM.app", challenge: " whitespace \n", context: context)
            try DecoderDraftStore.save(kind: "assertion", input: "ccdd", appID: "TEAM.other", challenge: "", context: context)
            try DecoderDraftStore.save(kind: "assertion", input: "eeff", appID: "TEAM.other", challenge: "", publicKey: "manual-public-key", verificationOptionsJSON: "saved-verification-inputs", context: context)
        } else if CommandLine.arguments[1] == "clear" {
            try DecoderDraftStore.save(kind: "attestation", input: "", appID: "", challenge: "", context: context)
        } else {
            let attestation = try DecoderDraftStore.load(kind: "attestation", context: context)
            let assertion = try DecoderDraftStore.load(kind: "assertion", context: context)
            let cleared = CommandLine.arguments[1] == "read-cleared"
            assert(attestation?.input == (cleared ? "" : "aabb"))
            assert(attestation?.challenge == (cleared ? "" : " whitespace \n"))
            assert(assertion?.input == "eeff")
            assert(assertion?.publicKey == "manual-public-key")
            assert(assertion?.verificationOptionsJSON == "saved-verification-inputs")
            let count = try context.fetchCount(FetchDescriptor<DecoderDraft>())
            assert(count == 2)
            print("Persistence, separation, upsert, and clear checks passed")
        }
    }
}
