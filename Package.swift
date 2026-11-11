// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppAttestDecoder",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AppAttestDecoder", targets: ["AppAttestDecoder"])],
    targets: [.executableTarget(name: "AppAttestDecoder", resources: [.copy("Resources/appattest_decode.py"), .copy("Resources/assertion-example.json"), .copy("Resources/AppIcon.icns")])]
)
