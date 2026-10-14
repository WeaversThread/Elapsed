import AppKit

/// The menu bar time in its capsule, drawn straight into an image.
///
/// The menu bar re-snapshots a status item every time it changes; an image is far
/// cheaper to snapshot than a SwiftUI view that has to lay out first. Follows the
/// menu bar: white on a dark one, black on a light one. Also the Look settings preview.
struct StatusBarFace: Equatable {
    var text: String
    var style: StatusStyle
    var state: TimerState
    /// 0…1, rounded to whole pixels so an invisible change doesn't redraw.
    var progress: Double
    var accent: Accent
    /// While paused: 0 is the dim end of the breath, 1 the bright end.
    var glow: Double

    static let size = NSSize(width: 68, height: 18)

    init(text: String, style: StatusStyle, state: TimerState, progress: Double, accent: Accent, glow: Double = 0) {
        self.text = text
        self.style = style
        self.state = state
        let pixels = Double(Self.size.width * 2)
        self.progress = (min(max(progress, 0), 1) * pixels).rounded() / pixels
        self.accent = accent
        self.glow = (min(max(glow, 0), 1) * 32).rounded() / 32
    }

    /// Drawn on demand, so each menu bar gets the colors of its own appearance.
    func image() -> NSImage {
        let face = self
        let image = NSImage(size: Self.size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            face.draw(in: rect, context: context, isDark: isDark)
            return true
        }
        image.cacheMode = .never
        return image
    }

    // Plain Core Graphics and Core Text: no attribute dictionaries of AppKit objects,
    // and nothing allocated per frame except the line of text.
    private func draw(in rect: CGRect, context: CGContext, isDark: Bool) {
        let ink: CGFloat = isDark ? 1 : 0
        let radius = rect.height / 2
        let capsule = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        guard state != .idle else {
            let inset = rect.insetBy(dx: 0.5, dy: 0.5)
            context.addPath(CGPath(roundedRect: inset, cornerWidth: radius - 0.5, cornerHeight: radius - 0.5, transform: nil))
            context.setStrokeColor(CGColor(gray: isDark ? 0.7 : 0.3, alpha: 0.5))
            context.setLineWidth(1)
            context.strokePath()
            drawText(CGColor(gray: isDark ? 0.85 : 0.15, alpha: 1), in: rect, context: context, medium: false)
            return
        }

        // A paused Progress capsule with little fill would barely show its breathing,
        // so until 40% it breathes the whole capsule like the Capsule style.
        let drawnStyle: StatusStyle = style == .progress && state == .paused && progress < 0.4 ? .capsule : style

        switch drawnStyle {
        case .capsule:
            let alpha = state == .paused ? 0.3 + 0.2 * glow : (isDark ? 0.85 : 0.8)
            context.addPath(capsule)
            context.setFillColor(CGColor(gray: ink, alpha: alpha))
            context.fillPath()
            drawText(CGColor(gray: isDark ? 0.08 : 1, alpha: 1), in: rect, context: context, medium: true)

        case .progress:
            // The accent fills left to right as time elapses; the text flips color where the fill passes.
            context.saveGState()
            context.addPath(capsule)
            context.clip()
            context.setFillColor(CGColor(gray: ink, alpha: 0.18))
            context.fill(rect)

            let filled = CGRect(x: rect.minX, y: rect.minY, width: rect.width * progress, height: rect.height)
            let fillAlpha = state == .paused ? 0.45 + 0.3 * glow : 0.8
            context.setFillColor(accent.cgColor(isDark: isDark, alpha: fillAlpha))
            context.fill(filled)

            drawText(CGColor(gray: ink, alpha: 0.95), in: rect, context: context, medium: true)
            context.clip(to: filled)
            drawText(CGColor(gray: accent.isLight ? 0.08 : 1, alpha: 1), in: rect, context: context, medium: true)
            context.restoreGState()
        }
    }

    // MARK: - Text

    /// 11 pt down to 6.5 pt, made once: the menu bar redraws often.
    private static let fontSizes: [CGFloat] = Array(stride(from: 11, through: 6.5, by: -0.5))
    nonisolated(unsafe) private static let mediumFonts: [CTFont] = fontSizes.map {
        NSFont.monospacedSystemFont(ofSize: $0, weight: .medium) as CTFont
    }
    nonisolated(unsafe) private static let regularFonts: [CTFont] = fontSizes.map {
        NSFont.monospacedSystemFont(ofSize: $0, weight: .regular) as CTFont
    }

    /// Centered on the digits' cap height, shrinking to fit (the capsule never grows).
    private func drawText(_ color: CGColor, in rect: CGRect, context: CGContext, medium: Bool) {
        let fonts = medium ? Self.mediumFonts : Self.regularFonts
        var font = fonts[0]
        var line = Self.line(text, font: font)
        var width = CTLineGetTypographicBounds(line, nil, nil, nil)
        for smaller in fonts.dropFirst() where width > rect.width - 4 {
            font = smaller
            line = Self.line(text, font: font)
            width = CTLineGetTypographicBounds(line, nil, nil, nil)
        }

        context.saveGState()
        context.setFillColor(color)
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: (rect.midX - width / 2).rounded(),
            y: ((rect.midY - CTFontGetCapHeight(font) / 2) * 2).rounded() / 2
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private static func line(_ text: String, font: CTFont) -> CTLine {
        let attributes = [
            kCTFontAttributeName: font,
            kCTForegroundColorFromContextAttributeName: kCFBooleanTrue!,
        ] as CFDictionary
        return CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes))
    }
}
