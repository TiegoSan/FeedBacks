import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isLaunchSplashCompleted = false

    private var startupSplashPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showStartupSplashPanel()
    }

    func completeStartupSplash() {
        guard !isLaunchSplashCompleted else { return }
        isLaunchSplashCompleted = true
        startupSplashPanel?.orderOut(nil)
        startupSplashPanel = nil
    }

    func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "FeedBacks"
        alert.informativeText = "Standalone mix feedback marker importer for Pro Tools."
        alert.runModal()
    }

    private func showStartupSplashPanel() {
        let panelSize = NSSize(width: 360, height: 360)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hostingView = NSHostingView(rootView: SplashView())
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
        panel.center()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.75
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        startupSplashPanel = panel
    }
}
