import Foundation

struct AssertionVerificationInputs: Codable, Equatable, Sendable {
    var keyID = ""
    var useCoordinates = false
    var publicKeyX = ""
    var publicKeyY = ""
    var useHash = false
    var clientData = ""
    var clientDataHash = ""
    var previousCounter = ""
}
