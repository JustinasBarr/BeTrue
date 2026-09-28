//
//  LaunchSplashCutout.swift
//  BeTrue
//

import CoreText
import UIKit

/// The wordmark's glyph outlines, where its label draws them, and the zoom that ends inside one.
nonisolated struct LaunchSplashCutout {
    /// The launch screen's bounds.
    var bounds: CGRect
    /// Glyph outlines in `bounds` coordinates, for the even-odd rule, so counters stay filled.
    var glyphs: CGPath
    /// Solid ink the zoom ends in: the stem of the "T" in "BeTrue.".
    var landing: CGRect

    /// A rectangle reaching a quarter of the screen past each edge, minus the glyphs. Scaled down
    /// to 0.8 about any point on the screen, it still covers the screen.
    var coverPath: CGPath {
        let path = CGMutablePath()
        path.addRect(bounds.insetBy(dx: -bounds.width / 4, dy: -bounds.height / 4))
        path.addPath(glyphs)
        return path
    }

    /// The scale about `zoomAnchor` at which `landing` covers `bounds`.
    var fillScale: Double { max(bounds.width / landing.width, bounds.height / landing.height) }

    /// The point the wordmark and its cutout scale about, placed so that at `fillScale` the
    /// landing is centred on the screen. It lies inside the landing, so any larger scale keeps
    /// the screen covered.
    var zoomAnchor: CGPoint {
        let scale = fillScale
        return CGPoint(x: (scale * landing.midX - bounds.midX) / (scale - 1),
                       y: (scale * landing.midY - bounds.midY) / (scale - 1))
    }
}

extension LaunchSplashCutout {
    /// For a one-line `wordmark` inside `view`, laid out and not yet transformed. Nil when no
    /// glyph has a solid stroke to zoom into.
    init?(wordmark: UILabel, in view: UIView) {
        guard let text = wordmark.text, !text.isEmpty, let font = wordmark.font else { return nil }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        // Where UILabel draws the line: centred vertically, aligned horizontally.
        let bounds = wordmark.bounds
        let textHeight = wordmark.textRect(forBounds: bounds, limitedToNumberOfLines: 1).height
        let lineX: CGFloat = switch wordmark.textAlignment {
        case .center: bounds.midX - lineWidth / 2
        case .right: bounds.maxX - lineWidth
        default: bounds.minX
        }
        let baseline = bounds.midY - textHeight / 2 + font.ascender
        let origin = wordmark.convert(CGPoint(x: lineX, y: baseline), to: view)

        var outlines: [CGPath] = []
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            var runGlyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &runGlyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let runFont = (CTRunGetAttributes(run) as? [NSAttributedString.Key: Any])?[.font] as? UIFont ?? font
            let ctFont = CTFontCreateWithName(runFont.fontName as CFString, runFont.pointSize, nil)
            for (glyph, position) in zip(runGlyphs, positions) {
                // Glyph outlines point up from the baseline.
                var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                                  tx: origin.x + position.x, ty: origin.y - position.y)
                if let outline = CTFontCreatePathForGlyph(ctFont, glyph, &transform) {
                    outlines.append(outline)
                }
            }
        }
        // The largest, so the zoom goes the least far: the "T" stem, not the full stop.
        guard let landing = outlines.compactMap(Self.landing(in:))
            .max(by: { $0.width * $0.height < $1.width * $1.height })
        else { return nil }
        let glyphs = CGMutablePath()
        for outline in outlines { glyphs.addPath(outline) }
        self.init(bounds: view.bounds, glyphs: glyphs, landing: landing)
        guard fillScale > 1, landing.contains(zoomAnchor) else { return nil }
    }

    /// A solid stroke of `glyph`, a tenth in from its edges: for a "T", its stem from the baseline
    /// to the top of the bar. Found by stepping out along a row, then down a column, from the
    /// middle of the glyph a quarter of the way up.
    private static func landing(in glyph: CGPath) -> CGRect? {
        let box = glyph.boundingBoxOfPath
        let start = CGPoint(x: box.midX, y: box.maxY - box.height / 4)
        guard glyph.contains(start, using: .evenOdd) else { return nil }
        let left = edge(of: glyph, from: start, toward: CGPoint(x: box.minX - 1, y: start.y)).x
        let right = edge(of: glyph, from: start, toward: CGPoint(x: box.maxX + 1, y: start.y)).x
        let middle = CGPoint(x: (left + right) / 2, y: start.y)
        let top = edge(of: glyph, from: middle, toward: CGPoint(x: middle.x, y: box.minY - 1)).y
        let bottom = edge(of: glyph, from: middle, toward: CGPoint(x: middle.x, y: box.maxY + 1)).y
        let stroke = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        let landing = stroke.insetBy(dx: stroke.width / 10, dy: stroke.height / 10)
        // The steps only follow one row and one column, so check the whole rectangle is ink.
        let steps = 8
        let fractions = (0...steps).map { CGFloat($0) / CGFloat(steps) }
        let isSolid = fractions.allSatisfy { across in
            fractions.allSatisfy { down in
                glyph.contains(CGPoint(x: landing.minX + across * landing.width,
                                       y: landing.minY + down * landing.height),
                               using: .evenOdd)
            }
        }
        return isSolid ? landing : nil
    }

    /// The last point of `glyph` on the way from `inside` toward `outside`, found by halving.
    private static func edge(of glyph: CGPath, from inside: CGPoint, toward outside: CGPoint) -> CGPoint {
        var inside = inside
        var outside = outside
        for _ in 0..<20 {
            let middle = CGPoint(x: (inside.x + outside.x) / 2, y: (inside.y + outside.y) / 2)
            if glyph.contains(middle, using: .evenOdd) { inside = middle } else { outside = middle }
        }
        return inside
    }
}
