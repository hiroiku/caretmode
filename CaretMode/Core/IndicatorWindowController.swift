import AppKit
import SwiftUI

@MainActor
final class IndicatorWindowController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<IndicatorView>
    private var currentSource: InputSourceInfo
    private var settings: AppSettings

    init(source: InputSourceInfo, settings: AppSettings) {
        self.currentSource = source
        self.settings = settings

        let size = settings.indicatorSize.frameSize
        let indicatorView = IndicatorView(source: source, settings: settings)
        let hosting = NSHostingView(rootView: indicatorView)
        hosting.frame = NSRect(x: 0, y: 0, width: size, height: size)
        self.hostingView = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false

        self.panel = panel

        positionAtDefaultLocation()
    }

    func updateInputSource(_ source: InputSourceInfo) {
        guard source != currentSource else { return }
        currentSource = source
        refreshView()
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        let size = settings.indicatorSize.frameSize
        panel.setContentSize(NSSize(width: size, height: size))
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        refreshView()
    }

    func updatePosition(caretRect: CGRect) {
        let panelSize = panel.frame.size
        let offsetX = settings.offsetX
        let offsetY = settings.offsetY

        let appKitCaretRect = NSScreen.convertFromAX(caretRect)

        var origin = NSPoint(
            x: appKitCaretRect.maxX + offsetX,
            y: appKitCaretRect.minY - panelSize.height - offsetY
        )

        let screen = NSScreen.screenContaining(axPoint: caretRect.origin) ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            if origin.x + panelSize.width > visibleFrame.maxX {
                origin.x = appKitCaretRect.minX - panelSize.width - offsetX
            }
            if origin.x < visibleFrame.minX {
                origin.x = visibleFrame.minX
            }
            if origin.y < visibleFrame.minY {
                origin.y = appKitCaretRect.maxY + offsetY
            }
            if origin.y + panelSize.height > visibleFrame.maxY {
                origin.y = visibleFrame.maxY - panelSize.height
            }
        }

        panel.setFrameOrigin(origin)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    private func refreshView() {
        hostingView.rootView = IndicatorView(source: currentSource, settings: settings)
    }

    private func positionAtDefaultLocation() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = settings.indicatorSize.frameSize
        let x = screenFrame.maxX - size - 16
        let y = screenFrame.minY + 16
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
