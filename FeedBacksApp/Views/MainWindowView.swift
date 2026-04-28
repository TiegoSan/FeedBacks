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

        ZStack {
            LinearGradient(
                colors: [FeedbacksTheme.backgroundTop, FeedbacksTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                header
                controls
                reviewPanel
                footer
            }
            .padding(28)
            .opacity(appDelegate.isLaunchSplashCompleted ? 1 : 0.001)
            .animation(.easeOut(duration: 0.35), value: appDelegate.isLaunchSplashCompleted)
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .overlay(Circle().stroke(FeedbacksTheme.cardBorder, lineWidth: FeedbacksTheme.cardBorderWidth))

            VStack(alignment: .leading, spacing: 4) {
                Text("FeedBacks")
                    .font(.custom(BrandTypography.lobsterFontName, size: 46))
                    .foregroundStyle(FeedbacksTheme.textPrimary)
                Text("Standalone mix feedback marker importer for Pro Tools")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(FeedbacksTheme.textSecondary)
            }

            Spacer()

            Button {
                Task { await vm.importMarkers() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(vm.isBusy ? "Importing..." : "Import Markers into Pro Tools")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.accentWarm))
            .disabled(vm.isBusy || vm.rows.filter(\.include).isEmpty)

            Button {
                vm.chooseFile()
            } label: {
                Text("Choose File")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.accent))

            Button {
                vm.parseSelectedFile()
            } label: {
                Text("Parse Feedback File")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(GlassActionButtonStyle(fill: FeedbacksTheme.accentSoft))
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
        VStack(alignment: .leading, spacing: 16) {
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
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        labeledValue("File", value: vm.selectedFileURL?.lastPathComponent ?? "No file selected")

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Default Hour")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FeedbacksTheme.textSecondary)
                                Stepper(value: $vm.defaultHour, in: 0...23) {
                                    Text(String(format: "%02d", vm.defaultHour))
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundStyle(FeedbacksTheme.textPrimary)
                                }
                                .onChange(of: vm.defaultHour) { _, _ in
                                    if vm.selectedFileURL != nil { vm.parseSelectedFile() }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Compact 6-digit mode")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FeedbacksTheme.textSecondary)
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

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Example: `123456` -> \(compactSixDigitExample)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(FeedbacksTheme.textPrimary)
                            Text("This only affects compact 6-digit tokens like `123456`, not segmented values like `12:34:56`.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(FeedbacksTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 8) {
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
                        }

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
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private var reviewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}

private struct GlassActionButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.85 : 0.98))
            .background(
                RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.72 : 0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FeedbacksTheme.buttonCornerRadius, style: .continuous)
                    .stroke(FeedbacksTheme.buttonBorder, lineWidth: FeedbacksTheme.buttonBorderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .padding(22)
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
