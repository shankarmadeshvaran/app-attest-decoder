import Foundation

extension Bundle {
    /// Bundled resources: the SwiftPM resource bundle when built with `swift build` or
    /// `Package.swift`, and the app bundle when built from `AppAttestDecoder.xcodeproj`.
    static var appResources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
