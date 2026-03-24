import AppKit

extension NSScreen {
    /// The height of the main (primary) screen, used as the reference for AX coordinate conversion.
    /// AX coordinates use top-left of the main screen as origin.
    private static var mainScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Find the screen that contains the given point in AX coordinates (top-left origin).
    static func screenContaining(axPoint: CGPoint) -> NSScreen? {
        let appKitPoint = NSPoint(x: axPoint.x, y: mainScreenHeight - axPoint.y)

        // First try exact containment
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(appKitPoint) }) {
            return screen
        }

        // Fallback: find nearest screen (handles points on screen edges)
        return NSScreen.screens.min(by: { a, b in
            distanceToRect(point: appKitPoint, rect: a.frame) < distanceToRect(point: appKitPoint, rect: b.frame)
        })
    }

    /// Convert a rect from AX coordinates (top-left origin) to AppKit coordinates (bottom-left origin).
    static func convertFromAX(_ axRect: CGRect) -> NSRect {
        let height = mainScreenHeight
        guard height > 0 else { return NSRect(origin: .zero, size: axRect.size) }
        let appKitY = height - axRect.origin.y - axRect.height
        return NSRect(x: axRect.origin.x, y: appKitY, width: axRect.width, height: axRect.height)
    }

    /// Squared distance from a point to the nearest edge of a rect.
    private static func distanceToRect(point: NSPoint, rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
