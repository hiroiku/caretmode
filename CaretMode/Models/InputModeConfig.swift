import SwiftUI

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

struct InputModeConfig: Codable, Equatable {
    var label: String
    var color: CodableColor

    init(label: String, color: Color) {
        self.label = label
        self.color = CodableColor(color: color)
    }

    init(label: String, color: CodableColor) {
        self.label = label
        self.color = color
    }

    /// Key used for keyboard layouts (modeID == nil)
    static let layoutKey = "_layout"

    static let builtinDefaults: [String: InputModeConfig] = [
        layoutKey:                                              InputModeConfig(label: "A",  color: .blue),
        "com.apple.inputmethod.Japanese":                       InputModeConfig(label: "あ", color: .red),
        "com.apple.inputmethod.Japanese.Katakana":              InputModeConfig(label: "ア", color: .purple),
        "com.apple.inputmethod.Japanese.HalfWidthKatakana":     InputModeConfig(label: "ｱ",  color: .purple),
        "com.apple.inputmethod.Japanese.FullWidthRoman":        InputModeConfig(label: "Ａ", color: .blue),
        "com.apple.inputmethod.Roman":                          InputModeConfig(label: "A",  color: .blue),
        "com.apple.inputmethod.SCIM":                           InputModeConfig(label: "简", color: .orange),
        "com.apple.inputmethod.TCIM":                           InputModeConfig(label: "繁", color: .orange),
        "com.apple.inputmethod.Korean":                         InputModeConfig(label: "한", color: .green),
    ]

    static func defaultConfig(for modeID: String?, localizedName: String) -> InputModeConfig {
        let key = modeID ?? layoutKey
        if let builtin = builtinDefaults[key] {
            return builtin
        }
        // Fallback: first character of localized name
        let label = String(localizedName.prefix(1).isEmpty ? "?" : localizedName.prefix(1))
        return InputModeConfig(label: label, color: .gray)
    }
}
