import Foundation
import Observation
import SwiftUI

@Observable
final class AppSettings {
    @ObservationIgnored var onChangeCallback: (() -> Void)?

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled"); onChangeCallback?() }
    }

    var indicatorSize: IndicatorSize {
        didSet { UserDefaults.standard.set(indicatorSize.rawValue, forKey: "indicatorSize"); onChangeCallback?() }
    }

    var opacity: Double {
        didSet { UserDefaults.standard.set(opacity, forKey: "opacity"); onChangeCallback?() }
    }

    var offsetX: CGFloat {
        didSet { UserDefaults.standard.set(Double(offsetX), forKey: "offsetX"); onChangeCallback?() }
    }

    var offsetY: CGFloat {
        didSet { UserDefaults.standard.set(Double(offsetY), forKey: "offsetY"); onChangeCallback?() }
    }

    var borderEnabled: Bool {
        didSet { UserDefaults.standard.set(borderEnabled, forKey: "borderEnabled"); onChangeCallback?() }
    }

    var borderUseSourceColor: Bool {
        didSet { UserDefaults.standard.set(borderUseSourceColor, forKey: "borderUseSourceColor"); onChangeCallback?() }
    }

    var borderCustomColor: Color {
        didSet { saveColor(borderCustomColor, forKey: "borderCustomColor"); onChangeCallback?() }
    }

    var borderWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(borderWidth), forKey: "borderWidth"); onChangeCallback?() }
    }

    var borderOpacity: Double {
        didSet { UserDefaults.standard.set(borderOpacity, forKey: "borderOpacity"); onChangeCallback?() }
    }

    var cornerRadius: CGFloat {
        didSet { UserDefaults.standard.set(Double(cornerRadius), forKey: "cornerRadius"); onChangeCallback?() }
    }

    var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon"); onChangeCallback?() }
    }

    var modeConfigs: [String: InputModeConfig] {
        didSet { saveModeConfigs(); onChangeCallback?() }
    }

    var excludedApps: [ExcludedApp] {
        didSet { saveExcludedApps(); onChangeCallback?() }
    }

    var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    enum IndicatorSize: String, CaseIterable {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 16
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 22
            case .large: return 28
            }
        }

        var displayName: String {
            switch self {
            case .small: return "小"
            case .medium: return "中"
            case .large: return "大"
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "isEnabled") == nil {
            defaults.set(true, forKey: "isEnabled")
        }
        if defaults.object(forKey: "opacity") == nil {
            defaults.set(0.85, forKey: "opacity")
        }
        if defaults.object(forKey: "offsetX") == nil {
            defaults.set(4.0, forKey: "offsetX")
        }
        if defaults.object(forKey: "offsetY") == nil {
            defaults.set(4.0, forKey: "offsetY")
        }

        if defaults.object(forKey: "borderEnabled") == nil {
            defaults.set(true, forKey: "borderEnabled")
        }
        if defaults.object(forKey: "borderUseSourceColor") == nil {
            defaults.set(true, forKey: "borderUseSourceColor")
        }
        if defaults.object(forKey: "borderWidth") == nil {
            defaults.set(0.5, forKey: "borderWidth")
        }
        if defaults.object(forKey: "borderOpacity") == nil {
            defaults.set(0.5, forKey: "borderOpacity")
        }
        if defaults.object(forKey: "cornerRadius") == nil {
            defaults.set(6.0, forKey: "cornerRadius")
        }

        self.isEnabled = defaults.bool(forKey: "isEnabled")
        self.indicatorSize = IndicatorSize(rawValue: defaults.string(forKey: "indicatorSize") ?? "") ?? .medium
        self.opacity = defaults.double(forKey: "opacity")
        self.offsetX = CGFloat(defaults.double(forKey: "offsetX"))
        self.offsetY = CGFloat(defaults.double(forKey: "offsetY"))
        if defaults.object(forKey: "showMenuBarIcon") == nil {
            defaults.set(true, forKey: "showMenuBarIcon")
        }
        self.showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        self.borderEnabled = defaults.bool(forKey: "borderEnabled")
        self.borderUseSourceColor = defaults.bool(forKey: "borderUseSourceColor")
        self.borderCustomColor = Self.loadColor(forKey: "borderCustomColor") ?? .white
        self.borderWidth = CGFloat(defaults.double(forKey: "borderWidth"))
        self.borderOpacity = defaults.double(forKey: "borderOpacity")
        self.cornerRadius = CGFloat(defaults.double(forKey: "cornerRadius"))
        self.modeConfigs = Self.loadModeConfigs()
        self.excludedApps = Self.loadExcludedApps()
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    /// Resolve the config for a given input source.
    func config(for source: InputSourceInfo) -> InputModeConfig {
        let key = source.configKey
        if let custom = modeConfigs[key] {
            return custom
        }
        return InputModeConfig.defaultConfig(for: source.modeID, localizedName: source.localizedName)
    }

    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedApps.contains { $0.bundleID == bundleID }
    }

    // MARK: - Persistence

    private func saveColor(_ color: Color, forKey key: String) {
        if let data = try? JSONEncoder().encode(CodableColor(color: color)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadColor(forKey key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let codable = try? JSONDecoder().decode(CodableColor.self, from: data) else { return nil }
        return codable.color
    }

    private func saveModeConfigs() {
        if let data = try? JSONEncoder().encode(modeConfigs) {
            UserDefaults.standard.set(data, forKey: "modeConfigs")
        }
    }

    private static func loadModeConfigs() -> [String: InputModeConfig] {
        guard let data = UserDefaults.standard.data(forKey: "modeConfigs"),
              let configs = try? JSONDecoder().decode([String: InputModeConfig].self, from: data) else { return [:] }
        return configs
    }

    private func saveExcludedApps() {
        if let data = try? JSONEncoder().encode(excludedApps) {
            UserDefaults.standard.set(data, forKey: "excludedApps")
        }
    }

    private static func loadExcludedApps() -> [ExcludedApp] {
        guard let data = UserDefaults.standard.data(forKey: "excludedApps"),
              let apps = try? JSONDecoder().decode([ExcludedApp].self, from: data) else { return [] }
        return apps
    }
}
