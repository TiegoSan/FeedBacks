import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @ObservedObject private var colorTheme = FeedbacksColorTheme.shared
    @ObservedObject private var strokeTheme = FeedbacksStrokeTheme.shared
    @StateObject private var vm = FeedBacksViewModel()
    @State private var isSetupExpanded = true
    @State private var isMarkerExpanded = true

    var body: some View {
        let _ = colorTheme.refreshToken
        let _ = strokeTheme.refreshToken

        GeometryReader { geometry in
            let maxHeight = geometry.size.height
            ZStack {
                LinearGradient(
                    colors: [FeedbacksTheme.backgroundTop, FeedbacksTheme.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    controls
                    reviewPanel
                    footer
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .top)
                .opacity(appDelegate.isLaunchSplashCompleted ? 1 : 0.001)
                .animation(.easeOut(duration: 0.35), value: appDelegate.isLaunchSplashCompleted)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("FeedBacks")
                    .font(.custom(BrandTypography.lobsterFontName, size: 40))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                Text("Standalone mix feedback marker importer for Pro Tools")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
            }

            Spacer()

            Button {
                Task { await vm.importMarkers() }
            } label: {
                VStack(spacing: 7) {
                    if vm.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .frame(height: 18)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(height: 18)
                    }
                    Text(vm.isBusy ? "Importing…" : "Import\nPro Tools")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                }
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.buttonImport, emphasis: .primary))
            .disabled(vm.isBusy || vm.rows.filter(\.include).isEmpty)

            Button {
                Task { await vm.exportAAF() }
            } label: {
                actionButtonLabel(symbol: "square.and.arrow.up.fill", title: "Export\nAAF")
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.buttonExport))
            .disabled(vm.isBusy || vm.rows.filter(\.include).isEmpty)

            Button {
                vm.chooseFile()
            } label: {
                actionButtonLabel(symbol: "folder.fill", title: "Choose\nFile")
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.buttonChooseFile))

            Button {
                vm.pasteFromClipboard()
            } label: {
                actionButtonLabel(symbol: "doc.on.clipboard.fill", title: "Paste\nClipboard")
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.buttonClipboard))

            Button {
                vm.parseSelectedFile()
            } label: {
                actionButtonLabel(symbol: "waveform.and.magnifyingglass", title: "Parse\nFile")
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.buttonParse))
        }
    }

    private var controls: some View {
        setupCard
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isSetupExpanded)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isMarkerExpanded)
        .onChange(of: vm.rows.isEmpty) { _, isEmpty in
            if !isEmpty {
                isSetupExpanded = false
                isMarkerExpanded = false
            }
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Text("Import Setup")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FeedbacksTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Marker Settings")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FeedbacksTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                Button {
                    isSetupExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(isSetupExpanded ? "Collapse" : "Expand")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: isSetupExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FeedbacksTheme.cardElevated.opacity(0.72))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(FeedbacksTheme.buttonBorder, lineWidth: FeedbacksTheme.buttonBorderWidth)
                    )
                }
                .buttonStyle(.plain)
            }

            if isSetupExpanded {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsSubcard("Parsing") {
                            VStack(alignment: .leading, spacing: 12) {
                                parsingInterpretationCard
                                parsingPreviewCard
                                parsingNoteCard
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 10) {
                        settingsSubcard("Destination") {
                            HStack(alignment: .top, spacing: 16) {
                                labeledField("Marker Name", text: $vm.markerName)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ruler Name")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(FeedbacksTheme.textSecondary)
                                    Picker("", selection: $vm.rulerName) {
                                        ForEach(["Markers 1", "Markers 2", "Markers 3", "Markers 4", "Markers 5"], id: \.self) { name in
                                            Text(name).tag(name)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .frame(maxWidth: 180, alignment: .leading)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AAF FPS")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(FeedbacksTheme.textSecondary)
                                    Picker("", selection: $vm.aafFrameRate) {
                                        ForEach(AAFFrameRatePreset.allCases) { preset in
                                            Text(preset.title).tag(preset)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .frame(maxWidth: 120, alignment: .leading)
                            }
                        }

                        settingsSubcard("Color & Selection") {
                            VStack(spacing: 8) {
                                Text("Color")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FeedbacksTheme.textSecondary)
                                let colors = FeedbacksTheme.markerColors
                                HStack(spacing: 16) {
                                    VStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            ForEach(0..<8, id: \.self) { i in
                                                ColorButton(color: colors[i], isSelected: vm.colorIndex == i + 1) {
                                                    vm.colorIndex = i + 1
                                                }
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            ForEach(8..<16, id: \.self) { i in
                                                ColorButton(color: colors[i], isSelected: vm.colorIndex == i + 1) {
                                                    vm.colorIndex = i + 1
                                                }
                                            }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Selection")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(FeedbacksTheme.textSecondary)
                                        Text("\(vm.rows.filter(\.include).count) row(s) selected")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(FeedbacksTheme.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private var reviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Review Before Import")
            ScrollView {
                LazyVStack(spacing: 10) {
                    reviewHeader
                    ForEach($vm.rows) { $row in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $row.include)
                                .labelsHidden()
                                .frame(width: 34)
                            Text("\(row.lineNumber)")
                                .frame(width: 42, alignment: .leading)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(FeedbacksTheme.textPrimary)
                            Text(row.sourceTimecode)
                                .frame(width: 92, alignment: .leading)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(FeedbacksTheme.textSecondary)
                            TextField("HH:MM:SS:FF", text: $row.normalizedTimecode)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 130)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            TextField("Comment", text: $row.comment)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.issue.isEmpty ? "OK" : row.issue)
                                .frame(width: 80, alignment: .leading)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(row.issue.isEmpty ? FeedbacksTheme.success : FeedbacksTheme.warning)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: FeedbacksTheme.rowCornerRadius, style: .continuous)
                                .fill(FeedbacksTheme.cardElevated.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: FeedbacksTheme.rowCornerRadius, style: .continuous)
                                .stroke(FeedbacksTheme.rowBorder, lineWidth: FeedbacksTheme.rowBorderWidth)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private var reviewHeader: some View {
        HStack(spacing: 10) {
            Text("Use").frame(width: 34)
            Text("Line").frame(width: 42, alignment: .leading)
            Text("Source").frame(width: 92, alignment: .leading)
            Text("Timecode").frame(width: 130, alignment: .leading)
            Text("Comment").frame(maxWidth: .infinity, alignment: .leading)
            Text("Issue").frame(width: 80, alignment: .leading)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(FeedbacksTheme.textSecondary)
        .padding(.horizontal, 10)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.statusText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textPrimary)
            if !vm.resultText.isEmpty {
                Text(vm.resultText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
            }
            if let result = vm.importResult, !result.failures.isEmpty {
                Text(result.failures.map(\.error).joined(separator: " | "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.warning)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(FeedbacksTheme.textPrimary)
    }

    private var compactSixDigitExample: String {
        (try? MixFeedbackParser.normalizeTimecodeToken("123456", defaultHour: vm.defaultHour, sixDigitMode: vm.sixDigitMode))
            ?? "invalid"
    }

    private func labeledValue(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textPrimary)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textSecondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func settingsSubcard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FeedbacksTheme.rowCornerRadius + 2, style: .continuous)
                .fill(FeedbacksTheme.cardElevated.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FeedbacksTheme.rowCornerRadius + 2, style: .continuous)
                .stroke(FeedbacksTheme.rowBorder, lineWidth: max(0.75, FeedbacksTheme.rowBorderWidth))
        )
    }

    private var sourceStateCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FeedbacksTheme.card.opacity(0.9))
                    .frame(width: 42, height: 42)
                Image(systemName: sourceStatusIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(sourceStatusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Source")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
                Text(vm.selectedSourceLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            Text(sourceBadgeText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(sourceStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(sourceStatusColor.opacity(0.14))
                )
        }
        .padding(12)
        .background(subpanelBackground)
        .overlay(subpanelStroke)
    }

    private var parsingInterpretationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timecode Interpretation")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textSecondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Hour")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(FeedbacksTheme.textPrimary)
                    Stepper(value: $vm.defaultHour, in: 0...23) {
                        Text(String(format: "%02d", vm.defaultHour))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(FeedbacksTheme.textPrimary)
                    }
                    .onChange(of: vm.defaultHour) { _, _ in
                        if vm.selectedFileURL != nil { vm.parseSelectedFile() }
                    }
                }
                .frame(width: 110, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("6-digit Tokens")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(FeedbacksTheme.textPrimary)
                    Picker("", selection: $vm.sixDigitMode) {
                        ForEach(SixDigitMode.allCases) { mode in
                            Text("\(mode.title) (\(mode.subtitle))").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.sixDigitMode) { _, _ in
                        if vm.selectedFileURL != nil { vm.parseSelectedFile() }
                    }
                }
            }
        }
        .padding(12)
        .background(subpanelBackground)
        .overlay(subpanelStroke)
    }

    private var parsingPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textSecondary)

            HStack(spacing: 10) {
                previewToken("123456", tint: FeedbacksTheme.accentSoft)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
                previewToken(compactSixDigitExample, tint: FeedbacksTheme.accent)
            }
        }
        .padding(12)
        .background(subpanelBackground)
        .overlay(subpanelStroke)
    }

    private var parsingNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FeedbacksTheme.textSecondary)
                .padding(.top, 1)

            Text("Only compact 6-digit tokens like `123456` are affected. Segmented values like `12:34:56` stay unchanged.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FeedbacksTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(subpanelBackground)
        .overlay(subpanelStroke)
    }

    private func previewToken(_ value: String, tint: Color) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(FeedbacksTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.36), lineWidth: 1)
            )
    }

    private var sourceStatusIcon: String {
        if vm.selectedFileURL != nil {
            return "doc.text.fill"
        }
        if vm.selectedSourceLabel == "Clipboard" {
            return "doc.on.clipboard.fill"
        }
        return "tray.fill"
    }

    private var sourceBadgeText: String {
        if vm.selectedFileURL != nil {
            return "File"
        }
        if vm.selectedSourceLabel == "Clipboard" {
            return "Clipboard"
        }
        return "Waiting"
    }

    private var sourceStatusColor: Color {
        if vm.selectedFileURL != nil || vm.selectedSourceLabel == "Clipboard" {
            return FeedbacksTheme.accent
        }
        return FeedbacksTheme.textSecondary
    }

    private var subpanelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(FeedbacksTheme.card.opacity(0.72))
    }

    private var subpanelStroke: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(FeedbacksTheme.rowBorder, lineWidth: max(0.75, FeedbacksTheme.rowBorderWidth))
    }

    private func cardHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            sectionTitle(title)
            Spacer()
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(isExpanded.wrappedValue ? "Collapse" : "Expand")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(FeedbacksTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(FeedbacksTheme.cardElevated.opacity(0.72))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(FeedbacksTheme.buttonBorder, lineWidth: FeedbacksTheme.buttonBorderWidth)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionButtonLabel(symbol: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(height: 18)

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(1)
        }
    }
}

private enum ActionButtonEmphasis {
    case primary
    case secondary
}

private struct GlassActionButtonStyle: ButtonStyle {
    let fill: Color
    var emphasis: ActionButtonEmphasis = .secondary
    private let buttonSize: CGFloat = 68

    func makeBody(configuration: Configuration) -> some View {
        let isPrimary = emphasis == .primary
        let baseFillTop = fill.opacity(configuration.isPressed ? (isPrimary ? 0.72 : 0.42) : (isPrimary ? 0.92 : 0.58))
        let baseFillBottom = fill.opacity(configuration.isPressed ? (isPrimary ? 0.58 : 0.30) : (isPrimary ? 0.76 : 0.42))
        let plateFill = Color.black.opacity(configuration.isPressed ? 0.16 : (isPrimary ? 0.08 : 0.18))

        configuration.label
            .frame(width: buttonSize, height: buttonSize)
            .padding(6)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.84 : 0.97))
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                        .fill(plateFill)

                    RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    baseFillTop,
                                    baseFillBottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    fill.opacity(configuration.isPressed ? 0.08 : (isPrimary ? 0.18 : 0.10)),
                                    Color.clear
                                ],
                                center: .top,
                                startRadius: 2,
                                endRadius: buttonSize * 0.72
                            )
                        )

                    RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    FeedbacksTheme.buttonGlassHighlight.opacity(configuration.isPressed ? 0.04 : (isPrimary ? 0.12 : 0.06)),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                    .stroke(FeedbacksTheme.buttonGlassHighlight.opacity(configuration.isPressed ? 0.10 : (isPrimary ? 0.22 : 0.12)), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(0, FeedbacksTheme.buttonCornerRadius - 1), style: .continuous)
                    .stroke(fill.opacity(configuration.isPressed ? 0.34 : (isPrimary ? 0.72 : 0.48)), lineWidth: max(0.9, FeedbacksTheme.buttonBorderWidth))
                    .padding(1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: max(0, FeedbacksTheme.buttonCornerRadius - 2), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.03 : (isPrimary ? 0.12 : 0.07)),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: buttonSize * 0.24)
                    .padding(3)
                    .blendMode(.screen)
            }
            .shadow(color: fill.opacity(configuration.isPressed ? 0.08 : (isPrimary ? 0.18 : 0.08)), radius: isPrimary ? 14 : 10, x: 0, y: isPrimary ? 7 : 4)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.10 : 0.16), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: FeedbacksTheme.cardCornerRadius, style: .continuous)
                    .fill(FeedbacksTheme.card.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FeedbacksTheme.cardCornerRadius, style: .continuous)
                    .stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth)
            )
    }
}
