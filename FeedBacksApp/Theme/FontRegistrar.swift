import CoreText
import Foundation

enum FontRegistrar {
    static func registerAppFonts() {
        let candidateURLs: [URL?] = [
            Bundle.main.url(forResource: "Lobster-Regular", withExtension: "ttf", subdirectory: "Fonts"),
            Bundle.main.url(forResource: "Lobster-Regular", withExtension: "ttf"),
            Bundle.main.resourceURL?.appendingPathComponent("Fonts/Lobster-Regular.ttf"),
            Bundle.main.resourceURL?.appendingPathComponent("Lobster-Regular.ttf"),
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
