import SwiftUI

enum FeedbacksTheme {
    private static let theme = FeedbacksColorTheme.shared
    private static let strokeTheme = FeedbacksStrokeTheme.shared

    static var backgroundTop: Color { theme.color(for: .backgroundTop) }
    static var backgroundBottom: Color { theme.color(for: .backgroundBottom) }
    static var card: Color { theme.color(for: .card) }
    static var cardElevated: Color { theme.color(for: .cardElevated) }
    static var accent: Color { theme.color(for: .accent) }
    static var accentSoft: Color { theme.color(for: .accentSoft) }
    static var accentWarm: Color { theme.color(for: .accentWarm) }
    static var textPrimary: Color { theme.color(for: .textPrimary) }
    static var textSecondary: Color { theme.color(for: .textSecondary) }
    static var success: Color { theme.color(for: .success) }
    static var warning: Color { theme.color(for: .warning) }
    static var buttonImport: Color { theme.baseColor(for: .buttonImport) }
    static var buttonExport: Color { theme.baseColor(for: .buttonExport) }
    static var buttonChooseFile: Color { theme.baseColor(for: .buttonChooseFile) }
    static var buttonClipboard: Color { theme.baseColor(for: .buttonClipboard) }
    static var buttonParse: Color { theme.baseColor(for: .buttonParse) }

    static var cardBorder: Color { strokeTheme.color(for: .cardBorder) }
    static var buttonBorder: Color { strokeTheme.color(for: .buttonBorder) }
    static var buttonGlassHighlight: Color { strokeTheme.baseColor(for: .buttonGlassHighlight) }
    static var rowBorder: Color { strokeTheme.color(for: .rowBorder) }
    static var cardBorderWidth: Double { strokeTheme.value(for: .cardWidth) }
    static var buttonBorderWidth: Double { strokeTheme.value(for: .buttonWidth) }
    static var buttonGlassShine: Double { strokeTheme.value(for: .buttonGlassShine) }
    static var buttonGlassFrost: Double { strokeTheme.value(for: .buttonGlassFrost) }
    static var buttonGlassShadow: Double { strokeTheme.value(for: .buttonGlassShadow) }
    static var rowBorderWidth: Double { strokeTheme.value(for: .rowWidth) }
    static var cardCornerRadius: Double { strokeTheme.value(for: .cardCornerRadius) }
    static var buttonCornerRadius: Double { strokeTheme.value(for: .buttonCornerRadius) }
    static var rowCornerRadius: Double { strokeTheme.value(for: .rowCornerRadius) }

    static var markerColors: [Color] {
        [
            Color(hex: "6F34EE"),
            Color(hex: "942FDB"),
            Color(hex: "E465C4"),
            Color(hex: "F83692"),
            Color(hex: "F71E10"),
            Color(hex: "FF6E27"),
            Color(hex: "F8AD18"),
            Color(hex: "EAE500"),
            Color(hex: "B6E64B"),
            Color(hex: "4DFF4D"),
            Color(hex: "4DFFE1"),
            Color(hex: "4DB8FF"),
            Color(hex: "4D6AFF"),
            Color.white,
            Color(hex: "B6B6B6"),
            Color(hex: "222222")
        ]
    }
}
