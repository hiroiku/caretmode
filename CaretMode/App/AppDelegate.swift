import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let inputSourceMonitor = InputSourceMonitor()
    let accessibilityManager = AccessibilityManager()
    let caretPositionTracker = CaretPositionTracker()
    var indicatorController: IndicatorWindowController?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(named: "MenuBarIcon")

        let menu = NSMenu()
        toggleMenuItem = menu.addItem(
            withTitle: "インジケーターを表示",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "設定…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "CaretMode を終了",
            action: #selector(NSApplication.shared.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu

        let controller = IndicatorWindowController(
            source: inputSourceMonitor.currentSource,
            settings: settings
        )
        self.indicatorController = controller

        // Wire up event-driven callbacks
        inputSourceMonitor.onChange = { [weak self] in self?.updateIndicator() }
        caretPositionTracker.onChange = { [weak self] in self?.updateIndicator() }
        accessibilityManager.onChange = { [weak self] in
            self?.caretPositionTracker.startTracking()
            self?.updateIndicator()
        }

        if accessibilityManager.isGranted {
            caretPositionTracker.startTracking()
        }

        settings.onChangeCallback = { [weak self] in
            self?.updateIndicator()
            self?.updateMenuBarIcon()
        }

        updateIndicator()
        updateMenuBarIcon()

        // First launch: open settings panel to guide permission setup
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        caretPositionTracker.stopTracking()
    }

    // MARK: - Menu Bar Icon

    private func updateMenuBarIcon() {
        statusItem.isVisible = settings.showMenuBarIcon || settingsWindow != nil
        toggleMenuItem.state = settings.isEnabled ? .on : .off
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    // MARK: - Indicator

    private func updateIndicator() {
        guard let controller = indicatorController else { return }

        controller.updateInputSource(inputSourceMonitor.currentSource)
        controller.updateSettings(settings)

        let isExcluded = settings.isExcluded(
            bundleID: caretPositionTracker.focusedAppBundleID
        )

        let shouldShow = settings.isEnabled
            && accessibilityManager.isGranted
            && caretPositionTracker.isTextFieldFocused
            && !isExcluded

        if shouldShow {
            if let caretRect = caretPositionTracker.caretRect {
                controller.updatePosition(caretRect: caretRect)
            }
            if !controller.isVisible {
                controller.show()
            }
        } else if controller.isVisible {
            controller.hide()
        }
    }

    // MARK: - Settings Window

    func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: settings,
            accessibilityManager: accessibilityManager
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CaretMode 設定"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
        updateMenuBarIcon()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
            updateMenuBarIcon()
        }
    }
}
