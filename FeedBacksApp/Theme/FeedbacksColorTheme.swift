import AppKit
import SwiftUI

enum FeedbacksColorKey: String, CaseIterable, Identifiable {
    case backgroundTop
    case backgroundBottom
    case card
    case cardElevated
    case accent
    case accentSoft
    case accentWarm
    case textPrimary
    case textSecondary
    case success
    case warning
    case buttonImport
    case buttonExport
    case buttonChooseFile
    case buttonClipboard
    case buttonParse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backgroundTop: return "Background Top"
        case .backgroundBottom: return "Background Bottom"
        case .card: return "Card"
        case .cardElevated: return "Card Elevated"
        case .accent: return "Accent"
        case .accentSoft: return "Accent Soft"
        case .accentWarm: return "Accent Warm"
        case .textPrimary: return "Text Primary"
        case .textSecondary: return "Text Secondary"
        case .success: return "Success"
        case .warning: return "Warning"
        case .buttonImport: return "Button Import"
        case .buttonExport: return "Button Export"
        case .buttonChooseFile: return "Button Choose File"
        case .buttonClipboard: return "Button Clipboard"
        case .buttonParse: return "Button Parse"
        }
    }

    var defaultHex: String {
        switch self {
        case .backgroundTop: return "#151028"
        case .backgroundBottom: return "#102A43"
        case .card: return "#0D1422"
        case .cardElevated: return "#162033"
        case .accent: return "#1482B5"
        case .accentSoft: return "#0F5C7D"
        case .accentWarm: return "#D93B5A"
        case .textPrimary: return "#FFFFFF"
        case .textSecondary: return "#D8CAD8"
        case .success: return "#41C98B"
        case .warning: return "#F8D44C"
        case .buttonImport: return "#D93A63"
        case .buttonExport: return "#2B8CD2"
        case .buttonChooseFile: return "#3F74E8"
        case .buttonClipboard: return "#1F9D8B"
        case .buttonParse: return "#6E57D8"
        }
    }

    var defaultOpacity: Double {
        switch self {
        case .textPrimary:
            return 0.96
        case .textSecondary:
            return 0.82
        default:
            return 1
        }
    }
}

final class FeedbacksColorTheme: ObservableObject {
    static let shared = FeedbacksColorTheme()

    @Published private(set) var refreshToken = UUID()

    private let userDefaultsKey = "gogolabs.feedbacks.colorTheme.v1"
    private let userDefaults: UserDefaults
    private var values: [String: String]

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.values = userDefaults.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }

    func color(for key: FeedbacksColorKey) -> Color {
        Color(hex: hexString(for: key)).opacity(key.defaultOpacity)
    }

    func baseColor(for key: FeedbacksColorKey) -> Color {
        Color(hex: hexString(for: key))
    }

    func binding(for key: FeedbacksColorKey) -> Binding<Color> {
        Binding(
            get: { self.baseColor(for: key) },
            set: { self.setColor($0, for: key) }
        )
    }

    func hexString(for key: FeedbacksColorKey) -> String {
        values[key.rawValue] ?? key.defaultHex
    }

    func setColor(_ color: Color, for key: FeedbacksColorKey) {
        guard let hex = NSColor(color).hexString else { return }
        values[key.rawValue] = hex
        persistAndNotify()
    }

    func setHexColor(_ hex: String, for key: FeedbacksColorKey) {
        values[key.rawValue] = hex
        persistAndNotify()
    }

    func resetColor(for key: FeedbacksColorKey) {
        values.removeValue(forKey: key.rawValue)
        persistAndNotify()
    }

    func resetDefaults() {
        values.removeAll()
        persistAndNotify()
    }

    private func persistAndNotify() {
        userDefaults.set(values, forKey: userDefaultsKey)
        refreshToken = UUID()
        NotificationCenter.default.post(name: .feedbacksColorsDidChange, object: nil)
    }
}

extension Notification.Name {
    static let feedbacksColorsDidChange = Notification.Name("feedbacksColorsDidChange")
}

extension NSColor {
    var hexString: String? {
        guard let rgb = usingColorSpace(.deviceRGB) else { return nil }
        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
