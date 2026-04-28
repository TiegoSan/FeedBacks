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
                .task {
                    guard !appDelegate.isLaunchSplashCompleted else { return }
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await MainActor.run {
                        appDelegate.completeStartupSplash()
                    }
                }
        }
        .defaultSize(width: 1160, height: 760)
        .windowResizability(.contentSize)
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
