import Foundation
import SwiftUI

enum FeedbacksStrokeColorKey: String, CaseIterable, Identifiable {
    case cardBorder
    case buttonBorder
    case rowBorder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cardBorder: return "Card Border"
        case .buttonBorder: return "Button Border"
        case .rowBorder: return "Row Border"
        }
    }

    var defaultHex: String {
        switch self {
        case .cardBorder, .buttonBorder, .rowBorder:
            return "#A99AB3"
        }
    }
}

enum FeedbacksStrokeValueKey: String, CaseIterable, Identifiable {
    case cardWidth
    case cardCornerRadius
    case buttonWidth
    case buttonCornerRadius
    case rowWidth
    case rowCornerRadius

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cardWidth: return "Card Width"
        case .cardCornerRadius: return "Card Radius"
        case .buttonWidth: return "Button Width"
        case .buttonCornerRadius: return "Button Radius"
        case .rowWidth: return "Row Width"
        case .rowCornerRadius: return "Row Radius"
        }
    }

    var defaultValue: Double {
        switch self {
        case .cardWidth: return 1.0
        case .cardCornerRadius: return 28.0
        case .buttonWidth: return 1.0
        case .buttonCornerRadius: return 16.0
        case .rowWidth: return 1.0
        case .rowCornerRadius: return 14.0
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .cardWidth, .buttonWidth, .rowWidth:
            return 0.0...4.0
        case .cardCornerRadius:
            return 6.0...40.0
        case .buttonCornerRadius:
            return 4.0...30.0
        case .rowCornerRadius:
            return 4.0...24.0
        }
    }

    var step: Double {
        switch self {
        case .cardWidth, .buttonWidth, .rowWidth:
            return 0.1
        case .cardCornerRadius, .buttonCornerRadius, .rowCornerRadius:
            return 1.0
        }
    }
}

final class FeedbacksStrokeTheme: ObservableObject {
    static let shared = FeedbacksStrokeTheme()

    @Published private(set) var refreshToken = UUID()

    private let colorDefaultsKey = "gogolabs.feedbacks.strokeColors.v1"
    private let valueDefaultsKey = "gogolabs.feedbacks.strokeValues.v1"
    private let userDefaults: UserDefaults
    private var colorValues: [String: String]
    private var numericValues: [String: Double]

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.colorValues = userDefaults.dictionary(forKey: colorDefaultsKey) as? [String: String] ?? [:]
        self.numericValues = userDefaults.dictionary(forKey: valueDefaultsKey) as? [String: Double] ?? [:]
    }

    func color(for key: FeedbacksStrokeColorKey) -> Color {
        Color(hex: colorHex(for: key)).opacity(0.34)
    }

    func baseColor(for key: FeedbacksStrokeColorKey) -> Color {
        Color(hex: colorHex(for: key))
    }

    func colorHex(for key: FeedbacksStrokeColorKey) -> String {
        colorValues[key.rawValue] ?? key.defaultHex
    }

    func setColor(_ color: Color, for key: FeedbacksStrokeColorKey) {
        guard let hex = NSColor(color).hexString else { return }
        colorValues[key.rawValue] = hex
        persistAndNotify()
    }

    func setHexColor(_ hex: String, for key: FeedbacksStrokeColorKey) {
        colorValues[key.rawValue] = hex
        persistAndNotify()
    }

    func colorBinding(for key: FeedbacksStrokeColorKey) -> Binding<Color> {
        Binding(
            get: { self.baseColor(for: key) },
            set: { self.setColor($0, for: key) }
        )
    }

    func value(for key: FeedbacksStrokeValueKey) -> Double {
        numericValues[key.rawValue] ?? key.defaultValue
    }

    func setValue(_ value: Double, for key: FeedbacksStrokeValueKey) {
        numericValues[key.rawValue] = value
        persistAndNotify()
    }

    func valueBinding(for key: FeedbacksStrokeValueKey) -> Binding<Double> {
        Binding(
            get: { self.value(for: key) },
            set: { self.setValue($0, for: key) }
        )
    }

    func resetColor(for key: FeedbacksStrokeColorKey) {
        colorValues.removeValue(forKey: key.rawValue)
        persistAndNotify()
    }

    func resetValue(for key: FeedbacksStrokeValueKey) {
        numericValues.removeValue(forKey: key.rawValue)
        persistAndNotify()
    }

    func resetDefaults() {
        colorValues.removeAll()
        numericValues.removeAll()
        persistAndNotify()
    }

    private func persistAndNotify() {
        userDefaults.set(colorValues, forKey: colorDefaultsKey)
        userDefaults.set(numericValues, forKey: valueDefaultsKey)
        refreshToken = UUID()
    }
}
