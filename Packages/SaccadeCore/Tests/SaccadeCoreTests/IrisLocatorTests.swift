import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

@Suite("Iris localization")
struct IrisLocatorTests {
    @Test("Finds the iris center to sub-pixel precision across positions", arguments: [
        Point(x: 32, y: 16), Point(x: 24, y: 15), Point(x: 40, y: 17), Point(x: 28.4, y: 16.6), Point(x: 36.7, y: 14.3),
    ])
    func locatesCenter(iris: Point) throws {
        let eye = SyntheticEyeImage.render(iris: iris, seed: UInt64(iris.x * 10))
        let result = try #require(IrisLocator.locate(in: eye.image, opening: eye.opening))
        #expect(result.center.distance(to: iris) < 0.8, "found \(result.center) for \(iris)")
        #expect(result.confidence > 0.2)
    }

    @Test("Precision across 200 noisy renders: median error under 0.5 px")
    func statistical() {
        var rng = SeededGenerator(seed: 77)
        var errors: [Double] = []
        for i in 0 ..< 200 {
            let iris = Point(x: 22 + rng.nextUnit() * 20, y: 13 + rng.nextUnit() * 6)
            let eye = SyntheticEyeImage.render(iris: iris, noise: 8, seed: UInt64(i) + 1000)
            if let r = IrisLocator.locate(in: eye.image, opening: eye.opening) {
                errors.append(r.center.distance(to: iris))
            }
        }
        #expect(errors.count >= 195)
        let median = GazeMapper.median(errors)
        #expect(median < 0.5, "median \(median) px")
    }

    @Test("Works when the upper lid covers part of the iris")
    func partialOcclusion() throws {
        let iris = Point(x: 33, y: 13)
        let eye = SyntheticEyeImage.render(iris: iris, irisRadius: 8, lidOpening: 0.3)
        let result = try #require(IrisLocator.locate(in: eye.image, opening: eye.opening))
        #expect(result.center.distance(to: iris) < 1.5, "\(result.center)")
    }

    @Test("Works on a small, low-resolution eye (upsampled 32 px patch)")
    func smallEye() throws {
        let iris = Point(x: 18, y: 8)
        let eye = SyntheticEyeImage.render(width: 32, height: 16, iris: iris, irisRadius: 3.6, noise: 5)
        let result = try #require(IrisLocator.locate(in: eye.image, opening: eye.opening))
        #expect(result.center.distance(to: iris) < 1.0, "\(result.center)")
    }

    @Test("A flat patch gives no result")
    func flat() {
        let img = GrayImage(width: 64, height: 32, fill: 120)
        let opening = [Point(x: 4, y: 16), Point(x: 32, y: 4), Point(x: 60, y: 16), Point(x: 32, y: 28)]
        #expect(IrisLocator.locate(in: img, opening: opening) == nil)
    }

    @Test("Resampling and bilinear sampling")
    func resampling() {
        var img = GrayImage(width: 2, height: 1)
        img[0, 0] = 0
        img[1, 0] = 200
        #expect(img.sample(0.5, 0) == 100)
        let up = img.resampled(Rect(x: 0, y: 0, width: 2, height: 1), width: 4, height: 1)
        #expect(up.width == 4 && up[0, 0] == 0 && up[3, 0] == 200)
    }
}
