import Carbon

struct InputSourceInfo: Equatable, Identifiable {
    let id: String
    let localizedName: String
    let modeID: String?

    /// Key for looking up config: modeID or "_layout" for keyboard layouts
    var configKey: String {
        modeID ?? InputModeConfig.layoutKey
    }

    static func fromCurrentInputSource() -> InputSourceInfo {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return InputSourceInfo(id: "unknown", localizedName: "Unknown", modeID: nil)
        }
        return from(tisSource: source)
    }

    static func from(tisSource: TISInputSource) -> InputSourceInfo {
        let idPtr = TISGetInputSourceProperty(tisSource, kTISPropertyInputSourceID)
        let id = unsafeBitCast(idPtr, to: CFString?.self).map { $0 as String } ?? "unknown"

        let namePtr = TISGetInputSourceProperty(tisSource, kTISPropertyLocalizedName)
        let localizedName = unsafeBitCast(namePtr, to: CFString?.self).map { $0 as String } ?? "Unknown"

        let modePtr = TISGetInputSourceProperty(tisSource, kTISPropertyInputModeID)
        let modeID = modePtr != nil ? unsafeBitCast(modePtr, to: CFString?.self).map { $0 as String } : nil

        return InputSourceInfo(id: id, localizedName: localizedName, modeID: modeID)
    }

    /// List all selectable keyboard input sources installed on the system.
    static func allInstalled() -> [InputSourceInfo] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return sourceList.compactMap { source in
            let catPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory)
            let cat = unsafeBitCast(catPtr, to: CFString?.self).map { $0 as String } ?? ""
            guard cat == (kTISCategoryKeyboardInputSource as String) else { return nil }

            let selectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
            let selectable = unsafeBitCast(selectablePtr, to: CFBoolean?.self).map { CFBooleanGetValue($0) } ?? false
            guard selectable else { return nil }

            return from(tisSource: source)
        }
    }
}
