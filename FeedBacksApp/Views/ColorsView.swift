import SwiftUI

private struct ColorSection: Identifiable {
    let id: String
    let title: String
    let keys: [FeedbacksColorKey]
}

private struct StrokeSection: Identifiable {
    let id: String
    let title: String
    let colorKey: FeedbacksStrokeColorKey
    let widthKey: FeedbacksStrokeValueKey
    let radiusKey: FeedbacksStrokeValueKey
}

struct ColorsView: View {
    @ObservedObject private var colorTheme = FeedbacksColorTheme.shared
    @ObservedObject private var strokeTheme = FeedbacksStrokeTheme.shared
    @State private var expandedSections: Set<String> = ["window", "buttons", "button-glass", "borders"]

    private let colorSections: [ColorSection] = [
        ColorSection(
            id: "window",
            title: "Colors",
            keys: [
                .backgroundTop, .backgroundBottom,
                .card, .cardElevated,
                .accent, .accentSoft, .accentWarm,
                .textPrimary, .textSecondary,
                .success, .warning
            ]
        ),
        ColorSection(
            id: "buttons",
            title: "Buttons",
            keys: [
                .buttonImport, .buttonExport, .buttonChooseFile, .buttonClipboard, .buttonParse
            ]
        )
    ]

    private let strokeSections: [StrokeSection] = [
        StrokeSection(id: "cards", title: "Cards", colorKey: .cardBorder, widthKey: .cardWidth, radiusKey: .cardCornerRadius),
        StrokeSection(id: "buttons", title: "Buttons", colorKey: .buttonBorder, widthKey: .buttonWidth, radiusKey: .buttonCornerRadius),
        StrokeSection(id: "rows", title: "Rows", colorKey: .rowBorder, widthKey: .rowWidth, radiusKey: .rowCornerRadius)
    ]

    var body: some View {
        let _ = colorTheme.refreshToken
        let _ = strokeTheme.refreshToken

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Colors")
                    .font(.custom(BrandTypography.lobsterFontName, size: 42))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                Spacer()
                Button("Reset Defaults") {
                    colorTheme.resetDefaults()
                    strokeTheme.resetDefaults()
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(colorSections) { section in
                        colorSectionView(section)
                    }
                    buttonGlassSectionView
                    bordersSectionView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [FeedbacksTheme.backgroundTop, FeedbacksTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func colorSectionView(_ section: ColorSection) -> some View {
        collapsibleContainer(id: section.id, title: section.title) {
            VStack(spacing: 10) {
                ForEach(section.keys) { key in
                    FeedbacksColorEditorRow(key: key)
                }
            }
        }
    }

    private var bordersSectionView: some View {
        collapsibleContainer(id: "borders", title: "Borders") {
            VStack(spacing: 10) {
                ForEach(strokeSections) { section in
                    FeedbacksStrokeEditorRow(section: section)
                }
            }
        }
    }

    private var buttonGlassSectionView: some View {
        collapsibleContainer(id: "button-glass", title: "Button Glass") {
            FeedbacksButtonGlassEditorRow()
        }
    }

    private func collapsibleContainer<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        let isExpanded = expandedSections.contains(id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle(id)
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(FeedbacksTheme.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(FeedbacksTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(FeedbacksTheme.cardElevated.opacity(0.75))
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FeedbacksTheme.cardCornerRadius, style: .continuous)
                .fill(FeedbacksTheme.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FeedbacksTheme.cardCornerRadius, style: .continuous)
                .stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth)
        )
    }

    private func toggle(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
}

private struct FeedbacksButtonGlassEditorRow: View {
    @ObservedObject private var theme = FeedbacksStrokeTheme.shared

    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    @State private var hexText: String = ""
    @State private var isExpanded = true
    @State private var isUpdatingFromBinding = false

    private var colorSelection: Binding<Color> {
        theme.colorBinding(for: .buttonGlassHighlight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Liquid Glass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                    .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

                Button {
                    isExpanded.toggle()
                } label: {
                    ColorSwatchPicker(selection: colorSelection)
                }
                .buttonStyle(.plain)

                Button {
                    theme.resetColor(for: .buttonGlassHighlight)
                    theme.resetValue(for: .buttonGlassShine)
                    theme.resetValue(for: .buttonGlassFrost)
                    theme.resetValue(for: .buttonGlassShadow)
                    syncFromBinding()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FeedbacksTheme.textSecondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ColorsSliderRow(label: "Hue", value: $hue, range: 0...1)
                    ColorsSliderRow(label: "Saturation", value: $saturation, range: 0...1)
                    ColorsSliderRow(label: "Brightness", value: $brightness, range: 0...1)
                    StrokeValueRow(key: .buttonGlassShine)
                    StrokeValueRow(key: .buttonGlassFrost)
                    StrokeValueRow(key: .buttonGlassShadow)

                    HStack(spacing: 8) {
                        Text("HEX")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FeedbacksTheme.textSecondary)
                            .frame(width: 34, alignment: .leading)

                        TextField("RRGGBB", text: $hexText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .controlSize(.small)
                            .onSubmit(applyHexIfValid)
                            .onChange(of: hexText) { _, _ in
                                applyHexIfValid()
                            }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: hue) { _, _ in applyHSBIfNeeded() }
                .onChange(of: saturation) { _, _ in applyHSBIfNeeded() }
                .onChange(of: brightness) { _, _ in applyHSBIfNeeded() }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear(perform: syncFromBinding)
        .onChange(of: colorSelection.wrappedValue) { _, _ in
            syncFromBinding()
        }
    }

    private func syncFromBinding() {
        guard let components = colorSelection.wrappedValue.hsbComponents else { return }
        isUpdatingFromBinding = true
        hue = components.h
        saturation = components.s
        brightness = components.b
        hexText = colorSelection.wrappedValue.hexRGB ?? ""
        isUpdatingFromBinding = false
    }

    private func applyHSBIfNeeded() {
        guard !isUpdatingFromBinding else { return }
        colorSelection.wrappedValue = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func applyHexIfValid() {
        let cleaned = hexText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6 else { return }
        guard cleaned.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEF").contains($0) }) else { return }
        colorSelection.wrappedValue = Color(hex: cleaned)
    }
}

private struct FeedbacksColorEditorRow: View {
    let key: FeedbacksColorKey
    @ObservedObject private var theme = FeedbacksColorTheme.shared

    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    @State private var hexText: String = ""
    @State private var isExpanded = false
    @State private var isUpdatingFromBinding = false

    private var selection: Binding<Color> {
        theme.binding(for: key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(key.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                    .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

                Button {
                    isExpanded.toggle()
                } label: {
                    ColorSwatchPicker(selection: selection)
                }
                .buttonStyle(.plain)

                Button {
                    theme.resetColor(for: key)
                    syncFromBinding()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FeedbacksTheme.textSecondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ColorsSliderRow(label: "Hue", value: $hue, range: 0...1)
                    ColorsSliderRow(label: "Saturation", value: $saturation, range: 0...1)
                    ColorsSliderRow(label: "Brightness", value: $brightness, range: 0...1)

                    HStack(spacing: 8) {
                        Text("HEX")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FeedbacksTheme.textSecondary)
                            .frame(width: 34, alignment: .leading)

                        TextField("RRGGBB", text: $hexText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .controlSize(.small)
                            .onSubmit(applyHexIfValid)
                            .onChange(of: hexText) { _, _ in
                                applyHexIfValid()
                            }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: hue) { _, _ in applyHSBIfNeeded() }
                .onChange(of: saturation) { _, _ in applyHSBIfNeeded() }
                .onChange(of: brightness) { _, _ in applyHSBIfNeeded() }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear(perform: syncFromBinding)
        .onChange(of: selection.wrappedValue) { _, _ in
            syncFromBinding()
        }
    }

    private func syncFromBinding() {
        guard let components = selection.wrappedValue.hsbComponents else { return }
        isUpdatingFromBinding = true
        hue = components.h
        saturation = components.s
        brightness = components.b
        hexText = selection.wrappedValue.hexRGB ?? ""
        isUpdatingFromBinding = false
    }

    private func applyHSBIfNeeded() {
        guard !isUpdatingFromBinding else { return }
        selection.wrappedValue = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func applyHexIfValid() {
        let cleaned = hexText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6 else { return }
        guard cleaned.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEF").contains($0) }) else { return }
        selection.wrappedValue = Color(hex: cleaned)
    }
}

private struct FeedbacksStrokeEditorRow: View {
    let section: StrokeSection
    @ObservedObject private var theme = FeedbacksStrokeTheme.shared

    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    @State private var hexText: String = ""
    @State private var isExpanded = false
    @State private var isUpdatingFromBinding = false

    private var colorSelection: Binding<Color> {
        theme.colorBinding(for: section.colorKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                    .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

                Button {
                    isExpanded.toggle()
                } label: {
                    ColorSwatchPicker(selection: colorSelection)
                }
                .buttonStyle(.plain)

                Button {
                    theme.resetColor(for: section.colorKey)
                    theme.resetValue(for: section.widthKey)
                    theme.resetValue(for: section.radiusKey)
                    syncFromBinding()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FeedbacksTheme.textSecondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ColorsSliderRow(label: "Hue", value: $hue, range: 0...1)
                    ColorsSliderRow(label: "Saturation", value: $saturation, range: 0...1)
                    ColorsSliderRow(label: "Brightness", value: $brightness, range: 0...1)

                    HStack(spacing: 8) {
                        Text("HEX")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FeedbacksTheme.textSecondary)
                            .frame(width: 34, alignment: .leading)

                        TextField("RRGGBB", text: $hexText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .controlSize(.small)
                            .onSubmit(applyHexIfValid)
                            .onChange(of: hexText) { _, _ in
                                applyHexIfValid()
                            }
                    }

                    StrokeValueRow(key: section.widthKey)
                    StrokeValueRow(key: section.radiusKey)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: hue) { _, _ in applyHSBIfNeeded() }
                .onChange(of: saturation) { _, _ in applyHSBIfNeeded() }
                .onChange(of: brightness) { _, _ in applyHSBIfNeeded() }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear(perform: syncFromBinding)
        .onChange(of: colorSelection.wrappedValue) { _, _ in
            syncFromBinding()
        }
    }

    private func syncFromBinding() {
        guard let components = colorSelection.wrappedValue.hsbComponents else { return }
        isUpdatingFromBinding = true
        hue = components.h
        saturation = components.s
        brightness = components.b
        hexText = colorSelection.wrappedValue.hexRGB ?? ""
        isUpdatingFromBinding = false
    }

    private func applyHSBIfNeeded() {
        guard !isUpdatingFromBinding else { return }
        colorSelection.wrappedValue = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func applyHexIfValid() {
        let cleaned = hexText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6 else { return }
        guard cleaned.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEF").contains($0) }) else { return }
        colorSelection.wrappedValue = Color(hex: cleaned)
    }
}

private struct ColorSwatchPicker: View {
    @Binding var selection: Color
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(selection)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

            ColorPicker("", selection: $selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: size, height: size)
                .opacity(0.015)
        }
    }
}

private struct ColorsSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FeedbacksTheme.textSecondary)
            Slider(value: $value, in: range)
                .tint(FeedbacksTheme.accent)
        }
    }
}

private struct StrokeValueRow: View {
    let key: FeedbacksStrokeValueKey
    @ObservedObject private var theme = FeedbacksStrokeTheme.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
                Spacer()
                Text(String(format: key.step < 1 ? "%.1f" : "%.0f", theme.value(for: key)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
            }

            Slider(value: theme.valueBinding(for: key), in: key.range, step: key.step)
                .tint(FeedbacksTheme.accent)
        }
    }
}
