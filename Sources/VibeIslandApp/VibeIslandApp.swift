import AppKit
import SwiftUI

@MainActor
final class VibeIslandAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination(
            "Vibe Island should remain active while monitoring local agent sessions."
        )
        ProcessInfo.processInfo.disableSuddenTermination()
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async { [self] in
            model.startIfNeeded()
            model.showControlCenter()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.showControlCenter()
        return false
    }
}

@main
struct VibeIslandApp: App {
    @NSApplicationDelegateAdaptor(VibeIslandAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup("Vibe Island Debug") {
            ControlCenterView(model: appDelegate.model)
        }

        MenuBarExtra("Vibe Island", systemImage: "circle.hexagongrid.circle.fill") {
            MenuBarContentView(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
