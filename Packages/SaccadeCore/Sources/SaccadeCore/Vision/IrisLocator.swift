import Foundation

/// Sub-pixel iris-center localization from an eye patch by gradient-field voting (Timm & Barth, "Accurate eye
/// centre localisation by means of gradients", VISAPP 2011), restricted to the eye opening and weighted by
/// darkness. Every strong edge on the iris boundary has a gradient pointing away from the center, so the center is
/// the point whose displacement vectors agree best with the gradients. Robust to eyelid occlusion and the corneal
/// highlight, and far more precise than landmark-model pupil estimates.
public enum IrisLocator {
    public struct Result: Sendable, Equatable {
        /// Iris center in the patch's pixel coordinates.
        public var center: Point
        /// 0...1: how much the peak stands out from the rest of the objective surface.
        public var confidence: Double
    }

    /// Working resolution: patches are resampled to this width before voting.
    public static let workingWidth = 48

    /// One gradient vote: an edge pixel and its unit gradient direction.
    struct Vote {
        var x: Double
        var y: Double
        var gx: Double
        var gy: Double
    }

    /// Locates the iris in `patch`. `opening` is the eye outline in patch coordinates (lid contour); candidates and
    /// votes are restricted to it (slightly dilated). Returns `nil` for degenerate input or a flat patch.
    public static func locate(in patch: GrayImage, opening: [Point]) -> Result? {
        guard patch.width >= 8, patch.height >= 4, opening.count >= 3 else { return nil }
        // Resample to the working resolution, preserving aspect.
        let scale = Double(workingWidth) / Double(patch.width)
        let w = workingWidth
        let h = max(4, Int((Double(patch.height) * scale).rounded()))
        let resampled = patch.resampled(
            Rect(x: 0, y: 0, width: Double(patch.width), height: Double(patch.height)), width: w, height: h
        )
        // Corneal highlights (the screen's reflection) add false edges that pull the estimate away from them.
        let img = suppressHighlights(resampled)
        let poly = opening.map { $0 * scale }
        let inside = mask(width: w, height: h, polygon: poly, dilation: 1.5)
        let candidates = mask(width: w, height: h, polygon: poly, dilation: -1.0)
        guard candidates.contains(true), let votes = gradientVotes(img, inside: inside) else { return nil }

        // Darkness prior: the iris is dark. Blurred inverse intensity.
        let darkness = blurredInverse(img)
        func value(_ x: Int, _ y: Int) -> Double {
            guard x >= 0, y >= 0, x < w, y < h else { return 0 }
            return objective(votes, Double(x), Double(y)) * darkness[y * w + x]
        }

        var best = (x: 0, y: 0, value: -1.0)
        var total = 0.0, count = 0.0
        for y in 0 ..< h {
            for x in 0 ..< w where candidates[y * w + x] {
                let v = value(x, y)
                total += v
                count += 1
                if v > best.value {
                    best = (x, y, v)
                }
            }
        }
        guard best.value > 0, count > 0 else { return nil }

        // Sub-pixel refinement: parabolic fit through the peak and its neighbors on each axis.
        let c = best.value
        let ox = parabolicOffset(value(best.x - 1, best.y), c, value(best.x + 1, best.y))
        let oy = parabolicOffset(value(best.x, best.y - 1), c, value(best.x, best.y + 1))
        let center = Point(x: (Double(best.x) + ox + 0.5) / scale - 0.5, y: (Double(best.y) + oy + 0.5) / scale - 0.5)
        let confidence = (1 - (total / count) / c).clamped(to: 0 ... 1)
        return Result(center: center, confidence: confidence)
    }

    /// Edge votes inside the opening: central-difference gradients above a dynamic magnitude threshold.
    /// `nil` when the patch is flat or has too few edges to vote with.
    static func gradientVotes(_ img: GrayImage, inside: [Bool]) -> [Vote]? {
        let w = img.width, h = img.height
        var gx = [Double](repeating: 0, count: w * h), gy = gx, mag = gx
        for y in 1 ..< h - 1 {
            for x in 1 ..< w - 1 where inside[y * w + x] {
                let dx = (Double(img[x + 1, y]) - Double(img[x - 1, y])) / 2
                let dy = (Double(img[x, y + 1]) - Double(img[x, y - 1])) / 2
                gx[y * w + x] = dx
                gy[y * w + x] = dy
                mag[y * w + x] = (dx * dx + dy * dy).squareRoot()
            }
        }
        let mags = mag.enumerated().filter { inside[$0.offset] }.map(\.element)
        guard !mags.isEmpty else { return nil }
        let mean = mags.reduce(0, +) / Double(mags.count)
        let sd = (mags.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(mags.count)).squareRoot()
        let threshold = mean + 0.3 * sd
        guard threshold > 1 else { return nil } // flat patch: nothing to vote with
        var votes: [Vote] = []
        for i in 0 ..< w * h where inside[i] && mag[i] > threshold {
            votes.append(Vote(x: Double(i % w), y: Double(i / w), gx: gx[i] / mag[i], gy: gy[i] / mag[i]))
        }
        return votes.count >= 6 ? votes : nil
    }

    /// Mean squared agreement between displacement directions from (cx, cy) and the outward gradients.
    static func objective(_ votes: [Vote], _ cx: Double, _ cy: Double) -> Double {
        var sum = 0.0
        for v in votes {
            let dx = v.x - cx, dy = v.y - cy
            let n = (dx * dx + dy * dy).squareRoot()
            guard n > 0.5 else { continue }
            let d = (dx * v.gx + dy * v.gy) / n
            if d > 0 {
                sum += d * d
            }
        }
        return sum / Double(votes.count)
    }

    /// Vertex offset (−0.5...0.5) of the parabola through three equally spaced samples.
    static func parabolicOffset(_ left: Double, _ center: Double, _ right: Double) -> Double {
        let denominator = left - 2 * center + right
        guard abs(denominator) > 1e-12 else { return 0 }
        return (0.5 * (left - right) / denominator).clamped(to: -0.5 ... 0.5)
    }

    /// Removes small bright specks: a grayscale opening (min then max, radius 2) erases bright structures narrower
    /// than 5 px; pixels are replaced only where they stood out, so iris and lid edges stay untouched.
    static func suppressHighlights(_ img: GrayImage) -> GrayImage {
        let opened = filter(filter(img, radius: 2, pick: min), radius: 2, pick: max)
        var out = img
        for i in 0 ..< img.pixels.count where Int(img.pixels[i]) - Int(opened.pixels[i]) > 25 {
            out.pixels[i] = opened.pixels[i]
        }
        return out
    }

    /// Square min/max filter.
    static func filter(_ img: GrayImage, radius r: Int, pick: (UInt8, UInt8) -> UInt8) -> GrayImage {
        var out = img
        for y in 0 ..< img.height {
            for x in 0 ..< img.width {
                var v = img[x, y]
                for yy in max(0, y - r) ... min(img.height - 1, y + r) {
                    for xx in max(0, x - r) ... min(img.width - 1, x + r) {
                        v = pick(v, img[xx, yy])
                    }
                }
                out[x, y] = v
            }
        }
        return out
    }

    /// Inverse intensity (255 − I), 3×3 box blurred, normalized to 0...1.
    static func blurredInverse(_ img: GrayImage) -> [Double] {
        let w = img.width, h = img.height
        var out = [Double](repeating: 0, count: w * h)
        for y in 0 ..< h {
            for x in 0 ..< w {
                var sum = 0.0, n = 0.0
                for dy in -1 ... 1 {
                    for dx in -1 ... 1 {
                        let xx = x + dx, yy = y + dy
                        guard xx >= 0, yy >= 0, xx < w, yy < h else { continue }
                        sum += 255 - Double(img[xx, yy])
                        n += 1
                    }
                }
                out[y * w + x] = sum / n / 255
            }
        }
        return out
    }

    /// Pixels inside `polygon`, grown (positive) or shrunk (negative) by `dilation` pixels.
    static func mask(width w: Int, height h: Int, polygon: [Point], dilation: Double) -> [Bool] {
        var out = [Bool](repeating: false, count: w * h)
        for y in 0 ..< h {
            for x in 0 ..< w {
                let p = Point(x: Double(x), y: Double(y))
                let distance = edgeDistance(p, polygon)
                let inPolygon = contains(p, polygon)
                out[y * w + x] = dilation >= 0 ? (inPolygon || distance <= dilation) :
                    (inPolygon && distance >= -dilation)
            }
        }
        return out
    }

    static func contains(_ p: Point, _ polygon: [Point]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0 ..< polygon.count {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func edgeDistance(_ p: Point, _ polygon: [Point]) -> Double {
        var best = Double.infinity
        for i in 0 ..< polygon.count {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            let ab = b - a, ap = p - a
            let len2 = ab.x * ab.x + ab.y * ab.y
            let t = len2 > 0 ? ((ap.x * ab.x + ap.y * ab.y) / len2).clamped(to: 0 ... 1) : 0
            best = min(best, p.distance(to: a + ab * t))
        }
        return best
    }
}
