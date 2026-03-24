import AppKit
import Carbon
import Observation

@Observable
@MainActor
final class InputSourceMonitor {
    private(set) var currentSource: InputSourceInfo

    @ObservationIgnored
    private var notificationObserver: NSObjectProtocol?
    @ObservationIgnored
    private var eventTapPort: CFMachPort?
    @ObservationIgnored
    private var eventTapSource: CFRunLoopSource?
    @ObservationIgnored
    var onChange: (() -> Void)?

    init() {
        self.currentSource = InputSourceInfo.fromCurrentInputSource()
        observeInputSourceChanges()
        setupEventTap()
    }

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

    fileprivate nonisolated func handleEventTap() {
        MainActor.assumeIsolated {
            updateInputSource()
        }
    }

    private func updateInputSource() {
        let newSource = InputSourceInfo.fromCurrentInputSource()
        if newSource != currentSource {
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
    monitor.handleEventTap()
    return Unmanaged.passUnretained(event)
}
