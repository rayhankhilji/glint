import Foundation

/// A small 8-bit grayscale image (row-major). Used only for transient eye patches cut from the camera's luma plane
/// inside the frame callback; never stored, logged or transmitted (G-SEC-01).
public struct GrayImage: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel count must match dimensions")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int, height: Int, fill: UInt8 = 0) {
        self.init(width: width, height: height, pixels: Array(repeating: fill, count: width * height))
    }

    @inline(__always) public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    /// Bilinear sample at a fractional position (clamped to the image).
    public func sample(_ x: Double, _ y: Double) -> Double {
        let cx = x.clamped(to: 0 ... Double(width - 1))
        let cy = y.clamped(to: 0 ... Double(height - 1))
        let x0 = Int(cx), y0 = Int(cy)
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let fx = cx - Double(x0), fy = cy - Double(y0)
        let top = Double(self[x0, y0]) * (1 - fx) + Double(self[x1, y0]) * fx
        let bottom = Double(self[x0, y1]) * (1 - fx) + Double(self[x1, y1]) * fx
        return top * (1 - fy) + bottom * fy
    }

    /// Resamples `rect` (in this image's pixels) to a `width × height` image.
    public func resampled(_ rect: Rect, width w: Int, height h: Int) -> GrayImage {
        var out = GrayImage(width: w, height: h)
        let sx = rect.width / Double(w), sy = rect.height / Double(h)
        for y in 0 ..< h {
            for x in 0 ..< w {
                let v = sample(rect.minX + (Double(x) + 0.5) * sx - 0.5, rect.minY + (Double(y) + 0.5) * sy - 0.5)
                out[x, y] = UInt8(v.rounded().clamped(to: 0 ... 255))
            }
        }
        return out
    }
}
