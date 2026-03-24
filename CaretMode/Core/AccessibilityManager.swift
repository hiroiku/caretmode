import AppKit
@preconcurrency import ApplicationServices
import Observation

@Observable
@MainActor
final class AccessibilityManager {
    private(set) var isGranted: Bool

    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollingSource: DispatchSourceTimer?
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        self.isGranted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
        startMonitoring()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startMonitoring()
    }

    private func startMonitoring() {
        guard notificationObservers.isEmpty else { return }

        let distCenter = DistributedNotificationCenter.default()
        notificationObservers.append(
            distCenter.addObserver(
                forName: NSNotification.Name("com.apple.accessibility.api"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.checkPermission()
                }
            }
        )

        let wsCenter = NSWorkspace.shared.notificationCenter
        notificationObservers.append(
            wsCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == Bundle.main.bundleIdentifier else { return }
                MainActor.assumeIsolated {
                    self?.checkPermission()
                }
            }
        )
    }

    func startPolling() {
        guard pollingSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: 1.0)
        source.setEventHandler { [weak self] in
            self?.checkPermission()
        }
        source.resume()
        pollingSource = source
    }

    func stopPolling() {
        pollingSource?.cancel()
        pollingSource = nil
    }

    private func checkPermission() {
        // AXIsProcessTrusted/WithOptions はキャッシュが壊れることがあるため、
        // CGEvent.tapCreate(.defaultTap) で実際に権限を判定する
        // (.defaultTap はアクセシビリティ権限, .listenOnly は入力監視権限)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        let granted = tap != nil
        if let tap { CFMachPortInvalidate(tap) }
        if granted != isGranted {
            isGranted = granted
            onChange?()
        }
    }
}
