import CoreGraphics
import Foundation
import SwiftUI

/// Measurement helpers over the emitted `Path` constants — the Swift side of
/// the pipeline's double-entry verification: Python measures the parametric
/// source, these helpers re-measure the committed constants, and the two must
/// agree within the shared tolerances.
///
/// Sampling flattens cubic/quadratic segments the same way the pipeline's
/// `flatten` does (parametric evaluation at fixed step counts), so both sides
/// measure polygons of equivalent resolution.
enum PathMeasuring {

    // MARK: - Flattening

    /// Flattens every subpath of `path` to a closed point loop.
    static func flatten(_ path: Path, steps: Int = 48) -> [[CGPoint]] {
        var loops: [[CGPoint]] = []
        var segments: [Segment] = []
        var cursor = CGPoint.zero
        var subpathStart = CGPoint.zero
        var subpathOpen = false

        func closeCurrentLoop() {
            guard subpathOpen, !segments.isEmpty else {
                segments = []
                subpathOpen = false
                return
            }
            loops.append(sampled(segments, start: subpathStart, steps: steps))
            segments = []
            subpathOpen = false
        }

        path.forEach { element in
            switch element {
            case let .move(p):
                closeCurrentLoop()
                cursor = p
                subpathStart = p
                subpathOpen = true
            case let .line(p):
                segments.append(.line(p))
                cursor = p
            case let .quadCurve(p, control):
                segments.append(.quadCurve(control: control, end: p))
                cursor = p
            case let .curve(p, c1, c2):
                segments.append(.curve(c1: c1, c2: c2, end: p))
                cursor = p
            case .closeSubpath:
                // Close back to the subpath's origin so the loop is watertight
                // for crossing counts.
                if cursor != subpathStart {
                    segments.append(.line(subpathStart))
                }
                closeCurrentLoop()
                cursor = subpathStart
            }
        }
        closeCurrentLoop()
        return loops
    }

    private enum Segment {
        case line(CGPoint)
        case quadCurve(control: CGPoint, end: CGPoint)
        case curve(c1: CGPoint, c2: CGPoint, end: CGPoint)
    }

    private static func sampled(_ segments: [Segment], start: CGPoint, steps: Int) -> [CGPoint] {
        var points: [CGPoint] = [start]
        var cursor = start
        for segment in segments {
            switch segment {
            case let .line(end):
                points.append(end)
                cursor = end
            case let .quadCurve(control, end):
                for step in 1...steps {
                    let t = Double(step) / Double(steps)
                    points.append(quad(cursor, control, end, t))
                }
                cursor = end
            case let .curve(c1, c2, end):
                for step in 1...steps {
                    let t = Double(step) / Double(steps)
                    points.append(cubic(cursor, c1, c2, end, t))
                }
                cursor = end
            }
        }
        return points
    }

    private static func quad(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: Double)
        -> CGPoint {
        let u = 1.0 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
            y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
    }

    private static func cubic(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double
    ) -> CGPoint {
        let u = 1.0 - t
        let uu = u * u
        let tt = t * t
        return CGPoint(
            x: uu * u * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + tt * t * p3.x,
            y: uu * u * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + tt * t * p3.y)
    }

    // MARK: - Measurement

    static func boundingBox(_ loops: [[CGPoint]]) -> CGRect {
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for loop in loops {
            for p in loop {
                minX = min(minX, Double(p.x))
                minY = min(minY, Double(p.y))
                maxX = max(maxX, Double(p.x))
                maxY = max(maxY, Double(p.y))
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func boundingBox(of path: Path) -> CGRect {
        boundingBox(flatten(path))
    }

    /// Total horizontal extent covered by the loops at a given y (counting
    /// outline crossings, like the pipeline's `width_at_y`).
    static func widthAtY(_ loops: [[CGPoint]], atY y: Double) -> Double {
        var crossings: [Double] = []
        for loop in loops {
            for i in 0..<loop.count {
                let a = loop[i]
                let b = loop[(i + 1) % loop.count]
                let (y0, y1) = (Double(a.y), Double(b.y))
                if (y0 <= y && y1 > y) || (y1 <= y && y0 > y) {
                    let t = (y - y0) / (y1 - y0)
                    crossings.append(Double(a.x) + t * (Double(b.x) - Double(a.x)))
                }
            }
        }
        guard crossings.count >= 2 else { return 0 }
        crossings.sort()
        // Pair up crossings: under the nonzero rule the covered spans of these
        // shapes cross an even number of outlines at any scanline.
        var width = 0.0
        var i = 0
        while i + 1 < crossings.count {
            width += crossings[i + 1] - crossings[i]
            i += 2
        }
        return width
    }

    static func widthAtY(_ path: Path, atY y: Double) -> Double {
        widthAtY(flatten(path), atY: y)
    }

    /// Even-odd containment across all loops: for the compound shapes here
    /// (convex-ish parts, counter-wound holes) parity matches the nonzero
    /// render.
    static func contains(_ loops: [[CGPoint]], _ point: CGPoint) -> Bool {
        var inside = false
        for loop in loops {
            var crossings = 0
            for i in 0..<loop.count {
                let a = loop[i]
                let b = loop[(i + 1) % loop.count]
                let (y0, y1) = (Double(a.y), Double(b.y))
                if (y0 <= Double(point.y) && y1 > Double(point.y))
                    || (y1 <= Double(point.y) && y0 > Double(point.y)) {
                    let t = (Double(point.y) - y0) / (y1 - y0)
                    let x = Double(a.x) + t * (Double(b.x) - Double(a.x))
                    if x > Double(point.x) { crossings += 1 }
                }
            }
            if crossings % 2 == 1 { inside = !inside }
        }
        return inside
    }

    static func contains(_ path: Path, _ point: CGPoint) -> Bool {
        contains(flatten(path), point)
    }
}
