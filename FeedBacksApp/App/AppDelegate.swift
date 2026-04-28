import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isLaunchSplashCompleted = false

    private var startupSplashPanel: NSPanel?
    private var colorsWindow: NSWindow?

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

    func showColorsWindow() {
        if colorsWindow == nil {
            let hostingController = NSHostingController(
                rootView: ColorsView()
                    .frame(minWidth: 460, minHeight: 620)
            )

            let window = NSWindow(contentViewController: hostingController)
            window.title = ""
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.tabbingMode = .disallowed
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            colorsWindow = window
        }

        if let visibleFrame = NSScreen.main?.visibleFrame {
            let width: CGFloat = 500
            let frame = NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: width,
                height: visibleFrame.height
            )
            colorsWindow?.setFrame(frame, display: false)
        }

        colorsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
