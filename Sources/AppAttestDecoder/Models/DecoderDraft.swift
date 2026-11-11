import SwiftData

enum DecoderSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [DecoderDraft.self] }

    @Model
    final class DecoderDraft {
        @Attribute(.unique) var kind: String
        var input: String
        var appID: String
        var clientDataHash: String = ""
        var verificationOptionsJSON: String = ""
        var publicKey: String = ""
        var challenge: String

        init(kind: String, input: String = "", appID: String = "", challenge: String = "") {
            self.kind = kind
            self.input = input
            self.appID = appID
            self.challenge = challenge
        }
    }
}

typealias DecoderDraft = DecoderSchemaV1.DecoderDraft

enum DecoderMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [DecoderSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
