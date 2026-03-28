import AppKit
import Carbon
import Observation

@Observable
@MainActor
final class InputSourceMonitor {
    private(set) var currentSource: InputSourceInfo

    @ObservationIgnored
    private var previousSource: InputSourceInfo?
    @ObservationIgnored
    private var predictedSource: InputSourceInfo?
    @ObservationIgnored
    private var eventTapPort: CFMachPort?
    @ObservationIgnored
    private var eventTapSource: CFRunLoopSource?
    @ObservationIgnored
    var onChange: (() -> Void)?
    @ObservationIgnored
    private var previousShortcut: (keyCode: Int64, modifiers: CGEventFlags)?
    @ObservationIgnored
    private var nextShortcut: (keyCode: Int64, modifiers: CGEventFlags)?

    init() {
        self.currentSource = InputSourceInfo.fromCurrentInputSource()
        loadSwitchShortcuts()
        observeInputSourceChanges()
        setupEventTap()
    }

    // MARK: - Shortcut Detection

    private func loadSwitchShortcuts() {
        guard let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys"),
              let hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys") else {
            return
        }
        previousShortcut = parseShortcut(hotkeys, key: "60")
        nextShortcut = parseShortcut(hotkeys, key: "61")
    }

    private func parseShortcut(
        _ hotkeys: [String: Any], key: String
    ) -> (keyCode: Int64, modifiers: CGEventFlags)? {
        guard let entry = hotkeys[key] as? [String: Any],
              let enabled = entry["enabled"] as? Bool, enabled,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int], params.count >= 3 else {
            return nil
        }
        let modifierMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        return (
            keyCode: Int64(params[1]),
            modifiers: CGEventFlags(rawValue: UInt64(params[2])).intersection(modifierMask)
        )
    }

    // MARK: - Notification Observer

    private func observeInputSourceChanges() {
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateInputSource()
            }
        }
    }

    @ObservationIgnored
    private var notificationObserver: NSObjectProtocol?

    // MARK: - Event Tap

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else { return }

        self.eventTapPort = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Event Handling

    fileprivate nonisolated func handleEventTap(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        MainActor.assumeIsolated {
            handleEvent(type: type, keyCode: keyCode, flags: flags)
        }
    }

    private func handleEvent(type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        let modifierMask: CGEventFlags = [
            .maskShift, .maskControl, .maskAlternate, .maskCommand,
        ]

        if type == .keyDown {
            let modifiers = flags.intersection(modifierMask)

            if let shortcut = previousShortcut,
               keyCode == shortcut.keyCode, modifiers == shortcut.modifiers {
                predictPreviousSource()
                return
            }
            if let shortcut = nextShortcut,
               keyCode == shortcut.keyCode, modifiers == shortcut.modifiers {
                predictNextSource()
                return
            }
        }

        if type == .flagsChanged {
            if flags.intersection(modifierMask).isEmpty {
                predictedSource = nil
            }
        }

        updateInputSource()
    }

    // MARK: - Prediction

    private func predictSwitch(to target: InputSourceInfo) {
        guard target != currentSource else { return }
        predictedSource = target
        previousSource = currentSource
        currentSource = target
        onChange?()
    }

    private func predictPreviousSource() {
        if let previous = previousSource, previous != currentSource {
            predictSwitch(to: previous)
            return
        }
        let installed = InputSourceInfo.allInstalled()
        if let other = installed.first(where: { $0 != currentSource }) {
            predictSwitch(to: other)
        }
    }

    private func predictNextSource() {
        let installed = InputSourceInfo.allInstalled()
        if installed.count > 1,
           let currentIndex = installed.firstIndex(of: currentSource) {
            predictSwitch(to: installed[(currentIndex + 1) % installed.count])
            return
        }
        if let previous = previousSource, previous != currentSource {
            predictSwitch(to: previous)
            return
        }
        if let other = installed.first(where: { $0 != currentSource }) {
            predictSwitch(to: other)
        }
    }

    // MARK: - Input Source Update

    private func updateInputSource() {
        let newSource = InputSourceInfo.fromCurrentInputSource()

        if let predicted = predictedSource {
            if newSource == predicted {
                predictedSource = nil
            } else if newSource != previousSource {
                predictedSource = nil
                if newSource != currentSource {
                    previousSource = currentSource
                    currentSource = newSource
                    onChange?()
                }
            }
            return
        }

        if newSource != currentSource {
            previousSource = currentSource
            currentSource = newSource
            onChange?()
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<InputSourceMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleEventTap(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
