import SwiftUI

@main
struct CardImporterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ImportSessionStore()

    var body: some Scene {
        WindowGroup("Card Importer") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandMenu("Import") {
                Button("Refresh Volumes") {
                    Task { await store.refreshVolumes() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Scan Source") {
                    Task { await store.scanSource() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.sourceURL == nil)

                Button("Import Selected") {
                    Task { await store.importSelected() }
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(!store.canImportSelection)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
