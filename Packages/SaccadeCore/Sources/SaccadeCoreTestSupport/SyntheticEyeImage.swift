import Foundation
import SaccadeCore

/// Renders a grayscale eye patch with a known iris center (skin, almond-shaped opening, sclera, iris, pupil,
/// corneal highlight, sensor noise) to test `IrisLocator` without a camera.
public enum SyntheticEyeImage {
    public struct Eye {
        public var image: GrayImage
        public var opening: [Point]
        public var irisCenter: Point
    }

    public static func render(
        width: Int = 64, height: Int = 32, iris: Point, irisRadius: Double = 7, lidOpening: Double = 0.42,
        noise: Double = 6, highlight: Bool = true, seed: UInt64 = 1
    ) -> Eye {
        var rng = SeededGenerator(seed: seed)
        var img = GrayImage(width: width, height: height)
        let cx = Double(width) / 2, cy = Double(height) / 2
        let halfW = Double(width) * 0.44, halfH = Double(height) * lidOpening
        let opening = (0 ..< 16).map { i -> Point in
            let a = Double(i) / 16 * 2 * .pi
            return Point(x: cx + cos(a) * halfW, y: cy + sin(a) * halfH)
        }
        for y in 0 ..< height {
            for x in 0 ..< width {
                let p = Point(x: Double(x), y: Double(y))
                let nx = (p.x - cx) / halfW, ny = (p.y - cy) / halfH
                var v: Double
                if nx * nx + ny * ny > 1 {
                    v = 150 // skin / lid
                } else {
                    let d = p.distance(to: iris)
                    v = d < irisRadius * 0.4 ? 18 : (d < irisRadius ? 70 : 215) // pupil, iris, sclera
                    if highlight, p.distance(to: iris + Point(x: 1.8, y: -1.8)) < 1.3 {
                        v = 250
                    }
                }
                img[x, y] = UInt8((v + rng.nextGaussian(standardDeviation: noise)).rounded().clamped(to: 0 ... 255))
            }
        }
        return Eye(image: img, opening: opening, irisCenter: iris)
    }
}
