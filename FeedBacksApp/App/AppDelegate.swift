import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isLaunchSplashCompleted = false

    private var startupSplashPanel: NSPanel?
    private var colorsWindow: NSWindow?
    private var splashCompletionTask: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showStartupSplashPanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.hideMainWindows()
        }
        let task = DispatchWorkItem { [weak self] in
            self?.completeStartupSplash()
        }
        splashCompletionTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }

    func completeStartupSplash() {
        guard !isLaunchSplashCompleted else { return }
        splashCompletionTask?.cancel()
        splashCompletionTask = nil
        isLaunchSplashCompleted = true
        startupSplashPanel?.contentView = nil
        startupSplashPanel?.orderOut(nil)
        startupSplashPanel?.close()
        startupSplashPanel = nil
        revealMainWindows()
    }

    func configureMainWindow(_ window: NSWindow) {
        window.contentMinSize = NSSize(width: 980, height: 640)
        window.contentMaxSize = NSSize(width: 1400, height: 900)
        fitMainWindowToVisibleFrame(window)
        if isLaunchSplashCompleted {
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
        } else {
            window.alphaValue = 0
            window.orderOut(nil)
        }
    }

    func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "FeedBacks!"
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

    private func hideMainWindows() {
        for window in mainAppWindows {
            window.alphaValue = 0
            window.orderOut(nil)
        }
    }

    private func revealMainWindows() {
        let windows = mainAppWindows
        for window in windows {
            fitMainWindowToVisibleFrame(window)
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private var mainAppWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window !== startupSplashPanel && window !== colorsWindow
        }
    }

    private func fitMainWindowToVisibleFrame(_ window: NSWindow) {
        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }

        let horizontalMargin: CGFloat = 80
        let verticalMargin: CGFloat = 60
        let targetWidth = min(1160, max(900, visibleFrame.width - horizontalMargin))
        let targetHeight = min(900, max(640, visibleFrame.height - verticalMargin))
        let frame = NSRect(
            x: visibleFrame.midX - (targetWidth / 2),
            y: visibleFrame.midY - (targetHeight / 2),
            width: targetWidth,
            height: targetHeight
        )
        window.setContentSize(NSSize(width: targetWidth, height: targetHeight))
        window.setFrame(frame, display: false)
    }
}
