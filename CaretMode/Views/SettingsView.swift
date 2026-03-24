import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let accessibilityManager: AccessibilityManager
    let inputMonitoringManager: InputMonitoringManager

    var body: some View {
        TabView {
            GeneralTab(settings: settings, accessibilityManager: accessibilityManager, inputMonitoringManager: inputMonitoringManager)
                .tabItem { Label("一般", systemImage: "gear") }

            AppearanceTab(settings: settings)
                .tabItem { Label("外観", systemImage: "paintbrush") }

            InputSourcesTab(settings: settings)
                .tabItem { Label("入力ソース", systemImage: "globe") }

            ExcludedAppsTab(settings: settings)
                .tabItem { Label("除外アプリ", systemImage: "xmark.app") }
        }
        .frame(width: 540, height: 480)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var settings: AppSettings
    let accessibilityManager: AccessibilityManager
    let inputMonitoringManager: InputMonitoringManager

    var body: some View {
        Form {
            Toggle("メニューバーにアイコンを表示", isOn: $settings.showMenuBarIcon)

            Toggle("ログイン時に自動起動", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    updateLoginItem(enabled: newValue)
                }
            ))

            LabeledContent("アクセシビリティ権限") {
                HStack {
                    Image(systemName: accessibilityManager.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(accessibilityManager.isGranted ? .green : .red)
                    Text(accessibilityManager.isGranted ? "許可済み" : "未許可")
                    if !accessibilityManager.isGranted {
                        Button("設定を開く") {
                            accessibilityManager.requestPermission()
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            LabeledContent("入力監視権限") {
                HStack {
                    Image(systemName: inputMonitoringManager.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(inputMonitoringManager.isGranted ? .green : .red)
                    Text(inputMonitoringManager.isGranted ? "許可済み" : "未許可")
                    if !inputMonitoringManager.isGranted {
                        Button("設定を開く") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settings.launchAtLogin = !enabled
        }
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("背景") {
                Picker("サイズ", selection: $settings.indicatorSize) {
                    ForEach(AppSettings.IndicatorSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("不透明度") {
                    HStack {
                        Slider(value: $settings.opacity, in: 0.2...1.0, step: 0.05)
                        Text("\(Int(settings.opacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                LabeledContent("オフセット X") {
                    Stepper(value: $settings.offsetX, in: -20...20, step: 1) {
                        Text("\(Int(settings.offsetX)) pt")
                            .monospacedDigit()
                    }
                }

                LabeledContent("オフセット Y") {
                    Stepper(value: $settings.offsetY, in: -20...20, step: 1) {
                        Text("\(Int(settings.offsetY)) pt")
                            .monospacedDigit()
                    }
                }

                LabeledContent("角丸") {
                    Stepper(value: $settings.cornerRadius, in: 0...16, step: 1) {
                        Text("\(Int(settings.cornerRadius)) pt")
                            .monospacedDigit()
                    }
                }
            }

            Section("ボーダー") {
                Toggle("ボーダーを表示", isOn: $settings.borderEnabled)

                if settings.borderEnabled {
                    Toggle("入力ソースの色を使う", isOn: $settings.borderUseSourceColor)

                    if !settings.borderUseSourceColor {
                        ColorPicker("色", selection: $settings.borderCustomColor, supportsOpacity: false)
                    }

                    LabeledContent("不透明度") {
                        HStack {
                            Slider(value: $settings.borderOpacity, in: 0.0...1.0, step: 0.05)
                            Text("\(Int(settings.borderOpacity * 100))%")
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    LabeledContent("太さ") {
                        Stepper(value: $settings.borderWidth, in: 0.5...4.0, step: 0.5) {
                            Text("\(String(format: "%.1f", settings.borderWidth)) pt")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Input Sources Tab

private struct InputSourcesTab: View {
    @Bindable var settings: AppSettings

    private var installedSources: [InputSourceInfo] {
        InputSourceInfo.allInstalled()
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(installedSources) { source in
                    InputSourceRow(source: source, settings: settings)
                }
            }

            Divider()

            HStack {
                Button("デフォルトに戻す") {
                    settings.modeConfigs = [:]
                }
                Spacer()
            }
            .padding(8)
        }
    }
}

private struct InputSourceRow: View {
    let source: InputSourceInfo
    @Bindable var settings: AppSettings

    private var config: InputModeConfig {
        settings.config(for: source)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Preview badge
            Text(config.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: settings.cornerRadius * 0.8, style: .continuous)
                        .fill(config.color.color)
                )
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.localizedName)
                    .font(.body)
                Text(source.configKey)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Label editor
            TextField("", text: Binding(
                get: { config.label },
                set: { newLabel in
                    let trimmed = String(newLabel.prefix(2))
                    guard !trimmed.isEmpty else { return }
                    var updated = config
                    updated.label = trimmed
                    settings.modeConfigs[source.configKey] = updated
                }
            ))
            .frame(width: 36)
            .textFieldStyle(.roundedBorder)

            // Color picker
            ColorPicker("", selection: Binding(
                get: { config.color.color },
                set: { newColor in
                    var updated = config
                    updated.color = CodableColor(color: newColor)
                    settings.modeConfigs[source.configKey] = updated
                }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Excluded Apps Tab

private struct ExcludedAppsTab: View {
    @Bindable var settings: AppSettings
    @State private var showAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(settings.excludedApps) { app in
                    HStack {
                        if let icon = iconForBundleID(app.bundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(app.displayName)
                        Spacer()
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    settings.excludedApps.remove(atOffsets: indexSet)
                }
            }
            .overlay {
                if settings.excludedApps.isEmpty {
                    ContentUnavailableView("除外アプリなし", systemImage: "app.dashed", description: Text("下のボタンからアプリを追加"))
                }
            }

            Divider()

            HStack {
                Button {
                    showAppPicker = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
                Spacer()
            }
            .padding(8)
        }
        .sheet(isPresented: $showAppPicker) {
            RunningAppPickerView(excludedApps: $settings.excludedApps)
        }
    }

    private func iconForBundleID(_ bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Running App Picker

private struct RunningAppPickerView: View {
    @Binding var excludedApps: [ExcludedApp]
    @Environment(\.dismiss) private var dismiss

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("実行中のアプリから選択")
                .font(.headline)
                .padding()

            List(runningApps, id: \.bundleIdentifier) { app in
                let bundleID = app.bundleIdentifier ?? ""
                let alreadyExcluded = excludedApps.contains { $0.bundleID == bundleID }

                Button {
                    if !alreadyExcluded {
                        excludedApps.append(ExcludedApp(
                            bundleID: bundleID,
                            displayName: app.localizedName ?? bundleID
                        ))
                    }
                    dismiss()
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.localizedName ?? bundleID)
                        Spacer()
                        if alreadyExcluded {
                            Text("追加済み")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(alreadyExcluded)
            }

            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 350, height: 400)
    }
}
