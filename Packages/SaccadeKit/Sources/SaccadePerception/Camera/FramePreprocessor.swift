import CoreVideo
import SaccadeCore

/// The only code that reads camera pixels (G-SEC-01, enforced by check-architecture.sh). It copies one small eye
/// patch from the luma (Y) plane into memory for `IrisLocator`; the patch is discarded as soon as the frame is
/// processed and is never stored, logged or transmitted.
enum FramePreprocessor {
    /// Copies `rect` (image pixels, top-left origin) from the luma plane of a bi-planar YCbCr or BGRA buffer.
    static func eyePatch(from buffer: CVPixelBuffer, rect: Rect) -> GrayImage? {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let x0 = max(0, Int(rect.minX.rounded(.down))), y0 = max(0, Int(rect.minY.rounded(.down)))
        let x1 = min(width, Int(rect.maxX.rounded(.up))), y1 = min(height, Int(rect.maxY.rounded(.up)))
        guard x1 - x0 >= 8, y1 - y0 >= 4 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let planar = CVPixelBufferIsPlanar(buffer)
        guard let base = planar ? CVPixelBufferGetBaseAddressOfPlane(buffer, 0) : CVPixelBufferGetBaseAddress(buffer)
        else {
            return nil
        }
        let rowBytes = planar ? CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) : CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: (x1 - x0) * (y1 - y0))
        var i = 0
        for y in y0 ..< y1 {
            let row = bytes + y * rowBytes
            for x in x0 ..< x1 {
                if planar {
                    pixels[i] = row[x]
                } else { // BGRA: approximate luma from G (fast, monotonic)
                    pixels[i] = row[x * 4 + 1]
                }
                i += 1
            }
        }
        return GrayImage(width: x1 - x0, height: y1 - y0, pixels: pixels)
    }
}
