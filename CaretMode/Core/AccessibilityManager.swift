import AppKit
@preconcurrency import ApplicationServices
import Observation

@Observable
@MainActor
final class AccessibilityManager {
    private(set) var isGranted: Bool

    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        self.isGranted = AXIsProcessTrusted()
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

    private func checkPermission() {
        let granted = AXIsProcessTrusted()
        if granted != isGranted {
            isGranted = granted
            onChange?()
        }
    }
}
