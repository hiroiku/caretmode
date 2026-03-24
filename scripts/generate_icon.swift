#!/usr/bin/env swift

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Configuration

let outputDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("CaretMode/Resources/Assets.xcassets/AppIcon.appiconset")

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16@1x",    16),
    ("icon_16x16@2x",    32),
    ("icon_32x32@1x",    32),
    ("icon_32x32@2x",    64),
    ("icon_128x128@1x", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256@1x", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512@1x", 512),
    ("icon_512x512@2x", 1024),
]

// MARK: - Drawing

func drawIcon(size: CGFloat, in ctx: CGContext) {
    let s = size

    // --- Background: macOS squircle with Tahoe glass effect ---

    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect.insetBy(dx: s * 0.02, dy: s * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01),
                  blur: s * 0.04,
                  color: CGColor(gray: 0, alpha: 0.25))
    ctx.setFillColor(CGColor(gray: 0.85, alpha: 1.0))
    ctx.addPath(bgPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Base gradient (light blue-gray, Tahoe feel)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let baseColors: [CGFloat] = [
        0.82, 0.85, 0.90, 1.0,  // top: cool blue-gray
        0.90, 0.92, 0.95, 1.0,  // bottom: lighter
    ]
    if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: baseColors,
                                  locations: [0.0, 1.0], count: 2) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: s / 2, y: s),
                               end: CGPoint(x: s / 2, y: 0),
                               options: [])
    }

    // Glass highlight (top portion, white -> transparent)
    let glassColors: [CGFloat] = [
        1.0, 1.0, 1.0, 0.50,  // top: semi-white
        1.0, 1.0, 1.0, 0.05,  // mid: nearly transparent
        1.0, 1.0, 1.0, 0.0,   // bottom: fully transparent
    ]
    if let glass = CGGradient(colorSpace: colorSpace, colorComponents: glassColors,
                               locations: [0.0, 0.45, 0.55], count: 3) {
        ctx.drawLinearGradient(glass,
                               start: CGPoint(x: s / 2, y: s),
                               end: CGPoint(x: s / 2, y: 0),
                               options: [])
    }

    // Subtle inner border for glass edge
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.setLineWidth(s * 0.008)
    ctx.addPath(bgPath)
    ctx.strokePath()

    ctx.restoreGState()

    // --- I-beam caret (compound path, no overlap) ---

    let caretColor = CGColor(red: 0.25, green: 0.27, blue: 0.30, alpha: 1.0)

    // Dimensions relative to icon size
    let stemWidth = s * 0.055
    let serifWidth = s * 0.22
    let serifHeight = s * 0.045
    let caretHeight = s * 0.55
    let centerX = s * 0.38
    let topY = s * 0.72  // top of caret (flipped coords: higher Y = higher on screen in CG)
    let bottomY = topY - caretHeight

    // Build compound path for the I-beam
    let caret = CGMutablePath()

    // Top serif (horizontal bar at the top)
    let topSerifLeft = centerX - serifWidth / 2
    let topSerifRight = centerX + serifWidth / 2
    let topSerifBottom = topY - serifHeight
    let topSerifRadius = serifHeight * 0.35

    // Bottom serif
    let bottomSerifLeft = centerX - serifWidth / 2
    let bottomSerifRight = centerX + serifWidth / 2
    let bottomSerifTop = bottomY + serifHeight
    let bottomSerifRadius = serifHeight * 0.35

    // Stem
    let stemLeft = centerX - stemWidth / 2
    let stemRight = centerX + stemWidth / 2

    // Draw as a single unified shape (clockwise from top-left of top serif)
    caret.move(to: CGPoint(x: topSerifLeft + topSerifRadius, y: topY))

    // Top serif - top edge
    caret.addLine(to: CGPoint(x: topSerifRight - topSerifRadius, y: topY))
    caret.addQuadCurve(to: CGPoint(x: topSerifRight, y: topY - topSerifRadius),
                       control: CGPoint(x: topSerifRight, y: topY))

    // Right side of top serif down to stem
    caret.addLine(to: CGPoint(x: topSerifRight, y: topSerifBottom + topSerifRadius))
    caret.addQuadCurve(to: CGPoint(x: topSerifRight - topSerifRadius, y: topSerifBottom),
                       control: CGPoint(x: topSerifRight, y: topSerifBottom))
    caret.addLine(to: CGPoint(x: stemRight, y: topSerifBottom))

    // Stem right side going down
    caret.addLine(to: CGPoint(x: stemRight, y: bottomSerifTop))

    // Bottom serif right side
    caret.addLine(to: CGPoint(x: bottomSerifRight - bottomSerifRadius, y: bottomSerifTop))
    caret.addQuadCurve(to: CGPoint(x: bottomSerifRight, y: bottomSerifTop - bottomSerifRadius),
                       control: CGPoint(x: bottomSerifRight, y: bottomSerifTop))
    caret.addLine(to: CGPoint(x: bottomSerifRight, y: bottomY + bottomSerifRadius))
    caret.addQuadCurve(to: CGPoint(x: bottomSerifRight - bottomSerifRadius, y: bottomY),
                       control: CGPoint(x: bottomSerifRight, y: bottomY))

    // Bottom edge
    caret.addLine(to: CGPoint(x: bottomSerifLeft + bottomSerifRadius, y: bottomY))
    caret.addQuadCurve(to: CGPoint(x: bottomSerifLeft, y: bottomY + bottomSerifRadius),
                       control: CGPoint(x: bottomSerifLeft, y: bottomY))
    caret.addLine(to: CGPoint(x: bottomSerifLeft, y: bottomSerifTop - bottomSerifRadius))
    caret.addQuadCurve(to: CGPoint(x: bottomSerifLeft + bottomSerifRadius, y: bottomSerifTop),
                       control: CGPoint(x: bottomSerifLeft, y: bottomSerifTop))

    // Bottom serif left side up to stem
    caret.addLine(to: CGPoint(x: stemLeft, y: bottomSerifTop))

    // Stem left side going up
    caret.addLine(to: CGPoint(x: stemLeft, y: topSerifBottom))

    // Top serif left side
    caret.addLine(to: CGPoint(x: topSerifLeft + topSerifRadius, y: topSerifBottom))
    caret.addQuadCurve(to: CGPoint(x: topSerifLeft, y: topSerifBottom + topSerifRadius),
                       control: CGPoint(x: topSerifLeft, y: topSerifBottom))
    caret.addLine(to: CGPoint(x: topSerifLeft, y: topY - topSerifRadius))
    caret.addQuadCurve(to: CGPoint(x: topSerifLeft + topSerifRadius, y: topY),
                       control: CGPoint(x: topSerifLeft, y: topY))

    caret.closeSubpath()

    // Draw caret with subtle shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.005),
                  blur: s * 0.015,
                  color: CGColor(gray: 0, alpha: 0.2))
    ctx.setFillColor(caretColor)
    ctx.addPath(caret)
    ctx.fillPath()
    ctx.restoreGState()

    // --- "A" badge (bottom-right) ---

    let badgeSize = s * 0.35
    let badgePadding = s * 0.10
    let badgeX = s - badgeSize - badgePadding
    let badgeY = badgePadding
    let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)
    let badgeRadius = badgeSize * 0.22

    let badgePath = CGPath(roundedRect: badgeRect,
                           cornerWidth: badgeRadius, cornerHeight: badgeRadius,
                           transform: nil)

    // Badge shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008),
                  blur: s * 0.02,
                  color: CGColor(gray: 0, alpha: 0.15))

    // Badge background with glass
    ctx.addPath(badgePath)
    ctx.clip()

    let badgeColors: [CGFloat] = [
        1.0, 1.0, 1.0, 0.92,  // top
        0.96, 0.97, 0.98, 0.88, // bottom
    ]
    if let badgeGrad = CGGradient(colorSpace: colorSpace, colorComponents: badgeColors,
                                   locations: [0.0, 1.0], count: 2) {
        ctx.drawLinearGradient(badgeGrad,
                               start: CGPoint(x: badgeX, y: badgeY + badgeSize),
                               end: CGPoint(x: badgeX, y: badgeY),
                               options: [])
    }

    // Badge border
    ctx.setStrokeColor(CGColor(red: 0.75, green: 0.77, blue: 0.80, alpha: 0.5))
    ctx.setLineWidth(s * 0.005)
    ctx.addPath(badgePath)
    ctx.strokePath()

    ctx.restoreGState()

    // "A" text
    ctx.saveGState()
    let fontSize = badgeSize * 0.55
    let nsFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let font = CTFontCreateWithFontDescriptor(nsFont.fontDescriptor as CTFontDescriptor, fontSize, nil)

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.25, green: 0.27, blue: 0.30, alpha: 1.0),
    ]
    let attrStr = NSAttributedString(string: "A", attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrStr)
    let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    let textX = badgeX + (badgeSize - textBounds.width) / 2 - textBounds.origin.x
    let textY = badgeY + (badgeSize - textBounds.height) / 2 - textBounds.origin.y

    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - PNG Export

func generateIcon(name: String, pixels: Int) {
    let size = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context for \(name)")
        return
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    drawIcon(size: size, in: ctx)

    guard let image = ctx.makeImage() else {
        print("Failed to create image for \(name)")
        return
    }

    let url = outputDir.appendingPathComponent("\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create destination for \(name)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Generated: \(name).png (\(pixels)x\(pixels))")
}

// MARK: - Main

print("Output directory: \(outputDir.path)")

for entry in sizes {
    generateIcon(name: entry.name, pixels: entry.pixels)
}

print("Done!")
