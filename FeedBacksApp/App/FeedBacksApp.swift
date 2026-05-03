import SwiftUI

@main
struct FeedBacksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistrar.registerAppFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(appDelegate)
                .preferredColorScheme(.dark)
                .background(WindowAccessor { window in
                    appDelegate.configureMainWindow(window)
                })
        }
        .defaultSize(width: 1100, height: 560)
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FeedBacks!") {
                    appDelegate.showAboutPanel()
                }
            }

            CommandGroup(after: .toolbar) {
                Divider()
                Button("Colors") {
                    appDelegate.showColorsWindow()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
