import AppKit
@preconcurrency import ApplicationServices

enum AXHelpers {
    private nonisolated(unsafe) static let systemWide = AXUIElementCreateSystemWide()

    static func getFocusedElement() -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    static func getFocusedApplicationElement() -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &value)
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    static func getAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    static func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        getAttribute(element, attribute) as? String
    }

    static func getParameterizedAttribute(_ element: AXUIElement, _ attribute: String, param: AnyObject) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, param, &value)
        guard result == .success else { return nil }
        return value
    }

    static func isTextInputElement(_ element: AXUIElement) -> Bool {
        guard let role = getStringAttribute(element, kAXRoleAttribute) else { return false }
        let textRoles: Set<String> = [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole,
            "AXSearchField",
        ]
        if textRoles.contains(role) {
            return true
        }
        // AXWebArea is only considered text input if it's editable (e.g. contentEditable)
        if role == "AXWebArea" {
            return isEditable(element)
        }
        // Fallback: selected text range + editable = likely a text input
        if getAttribute(element, kAXSelectedTextRangeAttribute) != nil {
            return isEditable(element)
        }
        // Fallback: string value + editable = likely a text input (custom widgets)
        if getAttribute(element, kAXValueAttribute) is String, isEditable(element) {
            return true
        }
        return false
    }

    private static func isEditable(_ element: AXUIElement) -> Bool {
        if let editable = getAttribute(element, "AXEditable") as? Bool {
            return editable
        }
        return false
    }

    static func ensureAccessibilityEnabled(for app: AXUIElement) {
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, true as CFTypeRef)
    }

    static func getCaretRect(from element: AXUIElement) -> CGRect? {
        let windowRect = getContainingWindowRect(of: element)

        if let rect = getCaretRectViaTextMarker(from: element),
           validateCaretRect(rect), isWithinBounds(rect, window: windowRect) {
            return rect
        }
        if let rect = getCaretRectViaTextRange(from: element),
           validateCaretRect(rect), isWithinBounds(rect, window: windowRect) {
            return rect
        }
        // Last resort: use element rect with vertically centered caret
        if let elementRect = getElementRect(element) {
            let height = estimateCaretHeight(from: element)
            let y = elementRect.origin.y + (elementRect.height - height) / 2
            return CGRect(x: elementRect.origin.x, y: y, width: 0, height: height)
        }
        return nil
    }

    // MARK: - Validation

    private static func validateCaretRect(_ rect: CGRect) -> Bool {
        guard rect.height >= 4, rect.height <= 500 else { return false }
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitY = mainScreenHeight - rect.origin.y
        let appKitPoint = NSPoint(x: rect.origin.x, y: appKitY)
        let screenUnion = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let expandedBounds = screenUnion.insetBy(dx: -100, dy: -100)
        return expandedBounds.contains(appKitPoint)
    }

    private static func isWithinBounds(_ rect: CGRect, window: CGRect?) -> Bool {
        guard let window else { return true }
        let expandedWindow = window.insetBy(dx: -20, dy: -20)
        return expandedWindow.contains(rect.origin)
    }

    private static func getContainingWindowRect(of element: AXUIElement) -> CGRect? {
        // Walk up the AX hierarchy to find the containing window
        var current: AXUIElement? = element
        while let el = current {
            if let role = getStringAttribute(el, kAXRoleAttribute),
               role == kAXWindowRole || role == "AXSheet" || role == "AXDialog" {
                return getElementRect(el)
            }
            var parent: AnyObject?
            let result = AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent)
            current = (result == .success) ? (parent as! AXUIElement?) : nil
        }
        return nil
    }

    private static func getCaretRectViaTextMarker(from element: AXUIElement) -> CGRect? {
        guard let markerRange = getAttribute(element, "AXSelectedTextMarkerRange") else { return nil }
        guard let boundsValue = getParameterizedAttribute(
            element, "AXBoundsForTextMarkerRange", param: markerRange
        ) else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.height > 0 else { return nil }
        return CGRect(x: rect.origin.x, y: rect.origin.y, width: 0, height: rect.height)
    }

    private static func getCaretRectViaTextRange(from element: AXUIElement) -> CGRect? {
        guard let rangeValue = getAttribute(element, kAXSelectedTextRangeAttribute) else { return nil }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }

        // Try length=0 first (insertion point)
        if let rect = boundsForRange(element: element, location: range.location, length: 0) {
            // At line start, some apps return the previous line's end position for length=0.
            // Cross-validate with length=1 to detect and correct this.
            if isAtLineStart(element: element, location: range.location),
               let nextRect = boundsForRange(element: element, location: range.location, length: 1),
               !sameLine(rect, nextRect) {
                return CGRect(x: nextRect.origin.x, y: nextRect.origin.y, width: 0, height: nextRect.height)
            }
            return rect
        }

        // Fallback: try length=1 (next character bounds — works on empty lines in some apps)
        if let rect = boundsForRange(element: element, location: range.location, length: 1) {
            // Use only the left edge as the caret position
            return CGRect(x: rect.origin.x, y: rect.origin.y, width: 0, height: rect.height)
        }

        // Fallback: try the character before the caret
        if range.location > 0, let rect = boundsForRange(element: element, location: range.location - 1, length: 1) {
            // Use the right edge as the caret position
            return CGRect(x: rect.maxX, y: rect.origin.y, width: 0, height: rect.height)
        }

        return nil
    }

    private static func boundsForRange(element: AXUIElement, location: Int, length: Int) -> CGRect? {
        var range = CFRange(location: location, length: length)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }

        guard let boundsValue = getParameterizedAttribute(
            element,
            kAXBoundsForRangeParameterizedAttribute,
            param: rangeValue
        ) else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else { return nil }

        // Reject zero-height rects (invalid)
        guard rect.height > 0 else { return nil }

        return rect
    }

    private static func isAtLineStart(element: AXUIElement, location: Int) -> Bool {
        if location == 0 { return true }
        var prevRange = CFRange(location: location - 1, length: 1)
        guard let prevRangeValue = AXValueCreate(.cfRange, &prevRange) else { return false }
        guard let charValue = getParameterizedAttribute(
            element, kAXStringForRangeParameterizedAttribute, param: prevRangeValue
        ) as? String else { return false }
        return charValue == "\n" || charValue == "\r" || charValue == "\r\n"
    }

    private static func sameLine(_ a: CGRect, _ b: CGRect) -> Bool {
        let threshold = max(a.height, b.height) * 0.5
        return abs(a.midY - b.midY) < threshold
    }

    private static func estimateCaretHeight(from element: AXUIElement) -> CGFloat {
        if let fontDict = getAttribute(element, "AXFont") as? [String: Any],
           let fontSize = fontDict["AXFontSize"] as? CGFloat, fontSize > 0 {
            return fontSize * 1.2
        }
        if let rangeValue = getAttribute(element, kAXSelectedTextRangeAttribute) {
            var range = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) {
                let loc = max(0, range.location - 1)
                if let rect = boundsForRange(element: element, location: loc, length: 1),
                   rect.height > 0 {
                    return rect.height
                }
            }
        }
        return 16
    }

    static func getElementRect(_ element: AXUIElement) -> CGRect? {
        guard let posValue = getAttribute(element, kAXPositionAttribute),
              let sizeValue = getAttribute(element, kAXSizeAttribute) else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }

        return CGRect(origin: position, size: size)
    }

    static func getPid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return nil }
        return pid
    }
}
