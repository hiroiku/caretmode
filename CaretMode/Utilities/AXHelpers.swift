@preconcurrency import ApplicationServices
import Foundation

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
            "AXWebArea",
        ]
        if textRoles.contains(role) {
            return true
        }
        // Fallback: if the element has a selected text range, it's likely a text input
        if getAttribute(element, kAXSelectedTextRangeAttribute) != nil {
            return true
        }
        return false
    }

    static func getCaretRect(from element: AXUIElement) -> CGRect? {
        guard let rangeValue = getAttribute(element, kAXSelectedTextRangeAttribute) else { return nil }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }

        // Try length=0 first (insertion point)
        if let rect = boundsForRange(element: element, location: range.location, length: 0) {
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

        // Last resort: use element position with estimated caret height
        if let posValue = getAttribute(element, kAXPositionAttribute) {
            var position = CGPoint.zero
            if AXValueGetValue(posValue as! AXValue, .cgPoint, &position) {
                return CGRect(x: position.x, y: position.y, width: 0, height: 16)
            }
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
