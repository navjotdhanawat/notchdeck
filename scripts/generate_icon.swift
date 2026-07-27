import AppKit
import Foundation
import CoreGraphics

func drawIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let image = NSImage(size: size)

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        print("Failed to get graphics context.")
        return
    }

    // --- 1. Background macOS Squircle Shape ---
    // A squircle is defined with standard rounded rect. For macOS icons:
    // Icon content should be inside a rounded rect of width/height ~ 824x824 placed at x=100, y=100
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: squircleRect, cornerWidth: 180, cornerHeight: 180, transform: nil)

    // Fill Squircle Base with Deep Charcoal (#0B0B0C)
    context.addPath(path)
    context.setFillColor(CGColor(red: 11/255, green: 11/255, blue: 12/255, alpha: 1.0))
    context.fillPath()

    // Subtle inner border (overlay shadow)
    context.addPath(path)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08))
    context.setLineWidth(6)
    context.strokePath()

    // --- 2. Drawing The MacBook Notch ---
    // Let's place it at the top of the squircle, horizontally centered.
    // Notch dimensions: width = 360, height = 90
    // Centered at x = 512 - 180 = 332. Top is at y = 924.
    let notchWidth: CGFloat = 380
    let notchHeight: CGFloat = 85
    let notchX: CGFloat = 512 - (notchWidth / 2)
    let notchY: CGFloat = 820 // Positioned near the top

    let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)

    // Let's create the classic MacBook notch path with corners (smooth curvature)
    // Left ear, left radius, notch bottom, right radius, right ear.
    let notchPath = CGMutablePath()

    let rCut: CGFloat = 16 // radius of the corner cutout

    notchPath.move(to: CGPoint(x: notchX - 40, y: notchY + notchHeight))
    // Curve into the notch
    notchPath.addQuadCurve(to: CGPoint(x: notchX, y: notchY + notchHeight - rCut),
                           control: CGPoint(x: notchX - 10, y: notchY + notchHeight))
    // Down side
    notchPath.addLine(to: CGPoint(x: notchX, y: notchY + rCut))
    // Curve to bottom line
    notchPath.addQuadCurve(to: CGPoint(x: notchX + rCut, y: notchY),
                           control: CGPoint(x: notchX, y: notchY))
    // Bottom line
    notchPath.addLine(to: CGPoint(x: notchX + notchWidth - rCut, y: notchY))
    // Curve up right
    notchPath.addQuadCurve(to: CGPoint(x: notchX + notchWidth, y: notchY + rCut),
                           control: CGPoint(x: notchX + notchWidth, y: notchY))
    // Up side
    notchPath.addLine(to: CGPoint(x: notchX + notchWidth, y: notchY + notchHeight - rCut))
    // Curve out right
    notchPath.addQuadCurve(to: CGPoint(x: notchX + notchWidth + 40, y: notchY + notchHeight),
                           control: CGPoint(x: notchX + notchWidth + 10, y: notchY + notchHeight))

    // Fill the notch cutout with Pitch Black (#000000)
    context.addPath(notchPath)
    context.setFillColor(CGColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1.0))
    context.fillPath()

    // Shadow under the notch to give depth
    context.addPath(notchPath)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.04))
    context.setLineWidth(3)
    context.strokePath()

    // --- 3. Draw colored status dots inside the notch ---
    // We want 4 status dots representing NotchDeck states:
    // Yellow (needs input), Orange (needs permission), Blue (working), Green (success)
    // Centered inside the black notch area.
    let dots: [(color: CGColor, glowColor: NSColor)] = [
        (color: CGColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0), glowColor: NSColor.systemBlue),   // working: blue
        (color: CGColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1.0),  glowColor: NSColor.systemOrange), // permission: orange
        (color: CGColor(red: 234/255, green: 179/255, blue: 8/255, alpha: 1.0),   glowColor: NSColor.systemYellow), // input: yellow
        (color: CGColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0),   glowColor: NSColor.systemGreen),  // success: green
    ]

    let dotRadius: CGFloat = 16
    let spacing: CGFloat = 45
    let totalWidth = CGFloat(dots.count - 1) * spacing
    let startX: CGFloat = 512 - (totalWidth / 2)
    let dotY: CGFloat = notchY + (notchHeight / 2) // middle of notch

    for (index, dot) in dots.enumerated() {
        let x = startX + CGFloat(index) * spacing
        let rect = CGRect(x: x - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)

        // Save state for glow shadow
        context.saveGState()

        // Set glow shadow
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 18, color: dot.glowColor.withAlphaComponent(0.85).cgColor)

        // Draw glow aura
        let glowPath = CGPath(ellipseIn: rect.insetBy(dx: -4, dy: -4), transform: nil)
        context.addPath(glowPath)
        context.setFillColor(dot.color.copy(alpha: 0.15)!)
        context.fillPath()

        // Draw solid core circle
        let dotPath = CGPath(ellipseIn: rect, transform: nil)
        context.addPath(dotPath)
        context.setFillColor(dot.color)
        context.fillPath()

        context.restoreGState()

        // Highlighting reflection on top of the dot
        let highlightRect = CGRect(x: x - dotRadius/2, y: dotY + dotRadius/4, width: dotRadius, height: dotRadius/2)
        let highlightPath = CGPath(ellipseIn: highlightRect, transform: nil)
        context.addPath(highlightPath)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
        context.fillPath()
    }

    // --- 4. Deck details below the notch ---
    // Draw subtle grid or deck-slot lines at the bottom half to reflect "deck"
    let deckY: CGFloat = 300
    let deckWidth: CGFloat = 520
    let deckHeight: CGFloat = 220
    let deckX: CGFloat = 512 - (deckWidth / 2)

    let deckRect = CGRect(x: deckX, y: deckY, width: deckWidth, height: deckHeight)
    let deckPath = CGPath(roundedRect: deckRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

    // Draw deck contour
    context.addPath(deckPath)
    context.setFillColor(CGColor(red: 22/255, green: 22/255, blue: 27/255, alpha: 1.0))
    context.fillPath()

    context.addPath(deckPath)
    context.setStrokeColor(CGColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.05))
    context.setLineWidth(4)
    context.strokePath()

    // Inner active slot (Green glowing stripe accent at top of the deck)
    let accentRect = CGRect(x: deckX + 40, y: deckY + deckHeight - 20, width: deckWidth - 80, height: 4)
    let accentPath = CGPath(roundedRect: accentRect, cornerWidth: 2, cornerHeight: 2, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 0), blur: 12, color: NSColor.systemGreen.cgColor)
    context.addPath(accentPath)
    context.setFillColor(CGColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0))
    context.fillPath()
    context.restoreGState()

    // Mock terminal rows/lines inside the deck
    let linesY = [deckY + 150, deckY + 105, deckY + 60]
    let lineWidths: [CGFloat] = [0.8, 0.65, 0.45]

    for (i, y) in linesY.enumerated() {
        let w = (deckWidth - 80) * lineWidths[i]
        let x = deckX + 40
        let r = CGRect(x: x, y: y, width: w, height: 8)
        let p = CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(p)
        context.setFillColor(CGColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.1))
        context.fillPath()
    }

    image.unlockFocus()

    // Save image to output file
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: "icon.png"))
    }
}

drawIcon()
print("icon.png generated successfully!")
