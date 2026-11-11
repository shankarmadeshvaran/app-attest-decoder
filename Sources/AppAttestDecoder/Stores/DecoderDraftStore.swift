import Foundation
import SwiftData

@MainActor
enum DecoderDraftStore {
    static func load(kind: String, context: ModelContext) throws -> DecoderDraft? {
        var descriptor = FetchDescriptor<DecoderDraft>(predicate: #Predicate { $0.kind == kind })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static func save(kind: String, input: String, appID: String, challenge: String, publicKey: String = "", clientDataHash: String = "", verificationOptionsJSON: String = "", context: ModelContext) throws {
        let draft: DecoderDraft
        if let existing = try load(kind: kind, context: context) {
            draft = existing
        } else {
            draft = DecoderDraft(kind: kind)
            context.insert(draft)
        }
        draft.input = input
        draft.appID = appID
        draft.challenge = challenge
        draft.verificationOptionsJSON = verificationOptionsJSON
        draft.publicKey = publicKey
        draft.clientDataHash = clientDataHash
        try context.save()
    }

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DecoderSchemaV1.self)
        let configuration = ModelConfiguration("DecoderDrafts", schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: DecoderMigrationPlan.self, configurations: [configuration])
    }
}
