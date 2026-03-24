import AppKit
@preconcurrency import ApplicationServices
import Observation

@Observable
@MainActor
final class CaretPositionTracker {
    private(set) var caretRect: CGRect?
    private(set) var focusedAppBundleID: String?
    private(set) var isTextFieldFocused: Bool = false

    @ObservationIgnored private var observer: AXObserver?
    @ObservationIgnored private var observedPid: pid_t = 0
    @ObservationIgnored private var observedElement: AXUIElement?
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored var onChange: (() -> Void)?

    func startTracking() {
        guard !isRunning else { return }
        isRunning = true

        updateFocusedApp()
        updateCaretPosition()
        setupObserverForFrontmostApp()

        let nc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleAppActivated()
                }
            }
        )
        workspaceObservers.append(
            nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateFocusedApp()
                    self?.updateCaretPosition()
                    self?.onChange?()
                }
            }
        )
    }

    func stopTracking() {
        isRunning = false
        removeObserver()
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    // MARK: - Event Handlers

    private func handleAppActivated() {
        updateFocusedApp()
        setupObserverForFrontmostApp()
        updateCaretPosition()
        onChange?()

        // AX focus may not be settled yet — recheck shortly after activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateCaretPosition()
            self?.onChange?()
        }
    }

    fileprivate nonisolated func handleAXNotification(_ notification: CFString, element: AXUIElement) {
        let name = notification as String
        let isFocusOrWindowChange = name == (kAXFocusedUIElementChangedNotification as String)
            || name == (kAXFocusedWindowChangedNotification as String)
            || name == (kAXMainWindowChangedNotification as String)
        MainActor.assumeIsolated {
            if isFocusOrWindowChange {
                // Re-observe the newly focused element
                if let focusedElement = AXHelpers.getFocusedElement(),
                   let pid = AXHelpers.getPid(of: focusedElement), pid == observedPid, let obs = observer {
                    if let oldElement = observedElement {
                        removeNotifications(observer: obs, element: oldElement)
                    }
                    observedElement = focusedElement
                    addNotifications(observer: obs, element: focusedElement)
                }
            }
            updateCaretPosition()
            onChange?()
        }
    }

    // MARK: - State Updates

    private func updateFocusedApp() {
        focusedAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func updateCaretPosition() {
        guard let element = AXHelpers.getFocusedElement() else {
            isTextFieldFocused = false
            caretRect = nil
            return
        }

        let isText = AXHelpers.isTextInputElement(element)
        isTextFieldFocused = isText

        guard isText else {
            caretRect = nil
            return
        }

        if let rect = AXHelpers.getCaretRect(from: element) {
            caretRect = rect
        } else if let rect = AXHelpers.getElementRect(element) {
            caretRect = rect
        } else {
            caretRect = nil
        }
    }

    // MARK: - AXObserver Management

    private func setupObserverForFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            removeObserver()
            return
        }

        let pid = app.processIdentifier
        guard pid != observedPid else { return }

        removeObserver()
        observedPid = pid

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var obs: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &obs)
        guard result == .success, let obs else { return }

        self.observer = obs

        // Observe app-level events: focus changes, window changes
        let appElement = AXUIElementCreateApplication(pid)
        let appNotifications: [CFString] = [
            kAXFocusedUIElementChangedNotification as CFString,
            kAXFocusedWindowChangedNotification as CFString,
            kAXMainWindowChangedNotification as CFString,
        ]
        for n in appNotifications {
            AXObserverAddNotification(obs, appElement, n, refcon)
        }

        // If there's already a focused element, observe it for text changes
        if let element = AXHelpers.getFocusedElement(),
           AXHelpers.getPid(of: element) == pid {
            observedElement = element
            addNotifications(observer: obs, element: element)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )
    }

    private func addNotifications(observer: AXObserver, element: AXUIElement) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications: [CFString] = [
            kAXSelectedTextChangedNotification as CFString,
            kAXValueChangedNotification as CFString,
            kAXMovedNotification as CFString,
        ]
        for n in notifications {
            AXObserverAddNotification(observer, element, n, refcon)
        }
    }

    private func removeNotifications(observer: AXObserver, element: AXUIElement) {
        let notifications: [CFString] = [
            kAXSelectedTextChangedNotification as CFString,
            kAXValueChangedNotification as CFString,
            kAXMovedNotification as CFString,
        ]
        for n in notifications {
            AXObserverRemoveNotification(observer, element, n)
        }
    }

    private func removeObserver() {
        if let obs = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(obs),
                .defaultMode
            )
        }
        observer = nil
        observedElement = nil
        observedPid = 0
    }
}

// MARK: - AXObserver C callback

private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let tracker = Unmanaged<CaretPositionTracker>.fromOpaque(refcon).takeUnretainedValue()
    tracker.handleAXNotification(notification, element: element)
}
