import AppKit
import SwiftUI
import SwiftData

/// Makes the app a regular foreground app with a Dock icon and keyboard focus,
/// including when it is run from Xcode or `swift run` without an app bundle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }
}

@main
struct AppAttestDecoderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let storage: Result<ModelContainer, Error> = Result { try DecoderDraftStore.makeContainer() }

    var body: some Scene {
        WindowGroup("App Attest Decoder") {
            switch storage {
            case .success(let container):
                WorkspaceView().modelContainer(container)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Saved details unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("The local database could not be opened. Your saved data has not been reset.\n\(error.localizedDescription)")
                }
                .frame(minWidth: 600, minHeight: 400)
            }
        }
        .defaultSize(width: 1280, height: 840)
        .windowResizability(.contentMinSize)
    }
}
