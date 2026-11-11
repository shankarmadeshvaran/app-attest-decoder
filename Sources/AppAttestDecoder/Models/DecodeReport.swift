import Foundation

struct ReportSection: Identifiable, Sendable {
    let title: String
    let body: String
    var id: String { title }
    private var checkDefinitions: [(prefix: String, label: String)] {
        switch title {
        case "authData": return [
            ("key id = SHA256(public key):", "Key ID"),
            ("app id matches rpIdHash:", "App ID"),
            ("counter increased:", "Counter")
        ]
        case "Signature verification": return [("keyId check:", "Key ID"), ("signature verifies:", "Signature")]
        case "Nonce": return [("nonce matches challenge:", "Challenge")]
        default: return []
        }
    }

    var checks: [ReportCheck] {
        let lines = body.components(separatedBy: "\n")
        let definitions = checkDefinitions.filter { definition in
            definition.prefix != "key id = SHA256(public key):" || body.contains(definition.prefix)
        }
        var checks = definitions.map { definition in
            let value = lines.first(where: { $0.hasPrefix(definition.prefix) })?
                .dropFirst(definition.prefix.count).trimmingCharacters(in: .whitespaces)
            let outcome: ReportCheck.Outcome
            switch value {
            case "OK": outcome = .matches
            case "MISMATCH": outcome = .mismatch
            default: outcome = .notChecked
            }
            return ReportCheck(label: definition.label, outcome: outcome)
        }
        if title == "Signature verification" {
            if body.components(separatedBy: "\n").contains("result: VALID") {
                checks.append(ReportCheck(label: "Result", outcome: .valid))
            } else if body.components(separatedBy: "\n").contains("result: INVALID") {
                checks.append(ReportCheck(label: "Result", outcome: .invalid))
            }
        }
        if title == "Signature verification", body.contains("verification unavailable:") {
            checks = [ReportCheck(label: "Signature", outcome: .unavailable), ReportCheck(label: "Result", outcome: .invalid)]
        }
        if title.hasPrefix("Certificate") {
            checks.append(ReportCheck(label: "Certificate", outcome: body.contains("could not read") ? .unavailable : .read))
            checks.append(ReportCheck(label: "Trust", outcome: .notChecked))
        } else if title == "Signature" {
            checks.append(ReportCheck(label: "Replay", outcome: .notChecked))
        } else if title == "Receipt" {
            checks.append(ReportCheck(label: "Receipt", outcome: body.contains("could not parse") ? .unavailable : .read))
        } else if title == "Overview" {
            checks.append(ReportCheck(label: "Object", outcome: .read))
        }
        return checks
    }

    var receiptFields: [ReceiptField] {
        guard title == "Receipt", !body.contains("could not parse") else { return [] }
        return body.components(separatedBy: "\n").compactMap { line in
            guard let separator = line.firstIndex(of: ":") else { return nil }
            let name = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            return ReceiptField(name: name, value: value)
        }
    }

    var displayBody: String {
        body.components(separatedBy: "\n").filter { line in
            !checkDefinitions.contains { definition in
                guard line.hasPrefix(definition.prefix) else { return false }
                let value = line.dropFirst(definition.prefix.count).trimmingCharacters(in: .whitespaces)
                return value == "OK" || value == "MISMATCH"
            }
        }.joined(separator: "\n")
    }

    var symbol: String {
        if title.hasPrefix("Certificate") { return "doc.richtext" }
        switch title {
        case "Overview": return "square.grid.2x2"
        case "authData": return "key.horizontal"
        case "Nonce": return "number"
        default: return "doc.text"
        }
    }
}

struct DecodeReport: Sendable {
    let text: String
    let sections: [ReportSection]

    init(text: String) {
        self.text = text
        var sections: [ReportSection] = []
        var title: String?
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("== ") {
                if let title { sections.append(ReportSection(title: title, body: lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))) }
                title = String(line.dropFirst(3).prefix(while: { $0 != "=" })).trimmingCharacters(in: .whitespaces)
                lines = []
            } else { lines.append(line) }
        }
        if let title { sections.append(ReportSection(title: title, body: lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))) }
        self.sections = sections
    }
}

struct ReportCheck: Identifiable, Sendable {
    enum Outcome: Sendable {
        case matches, mismatch, notChecked, read, unavailable, valid, invalid
    }
    let label: String
    let outcome: Outcome
    var id: String { label }
}

struct ReceiptField: Identifiable {
    let name: String
    let value: String
    var id: String { name }
}
