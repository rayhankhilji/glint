import Foundation

/// One calibration sample: gaze features observed while the user looked at `target` (screen points).
public struct CalibrationSample: Sendable, Equatable, Codable {
    public var features: [Double]
    public var target: Point
    public var weight: Double
    /// Identifies the calibration anchor (or click) the sample belongs to, for grouped cross-validation.
    public var group: Int

    public init(features: [Double], target: Point, weight: Double = 1, group: Int) {
        self.features = features
        self.target = target
        self.weight = weight
        self.group = group
    }
}

/// A fitted per-user gaze mapping (ADR-006): standardized features → polynomial basis → ridge regression per axis.
public struct MapperModel: Sendable, Equatable, Codable {
    public var featureVersion: Int
    public var mean: [Double]
    public var std: [Double]
    public var coefX: [Double]
    public var coefY: [Double]
    public var lambda: Double
    /// Cross-validated RMS error in points: the base of the live uncertainty radius.
    public var residualPoints: Double

    /// Predicts the screen point for raw mapper inputs.
    public func predict(_ inputs: [Double]) -> Point {
        let phi = GazeMapper.basis(GazeMapper.standardize(inputs, mean: mean, std: std))
        return Point(x: GazeMapper.dot(coefX, phi), y: GazeMapper.dot(coefY, phi))
    }

    /// 1σ uncertainty in points for a frame with the given provider confidence (ARCHITECTURE §10.3).
    public func uncertainty(confidence: Double) -> Double {
        (residualPoints * (1 + 2 * (1 - confidence.clamped(to: 0 ... 1)))).clamped(to: 20 ... 300)
    }
}

public enum GazeMapper {
    /// Ridge strengths tried by cross-validation.
    static let lambdas: [Double] = [0.001, 0.01, 0.1, 1, 10]

    /// Fits a model. Samples are grouped (one group per calibration anchor) and cross-validated leave-group-out,
    /// so the reported error is for a point the model has never seen.
    /// - Throws: `GlintError.calibrationInsufficient` with fewer than 5 groups, `.mapperSingular` if unsolvable.
    public static func fit(_ samples: [CalibrationSample]) throws(GlintError) -> MapperModel {
        let groups = Set(samples.map(\.group))
        guard groups.count >= 5, samples.count >= 20 else {
            throw .calibrationInsufficient(anchorsOK: groups.count)
        }
        let (mean, std) = statistics(samples.map(\.features))
        var best: (lambda: Double, error: Double)?
        for lambda in lambdas {
            guard let error = crossValidatedError(samples, lambda: lambda, mean: mean, std: std) else { continue }
            if best == nil || error < best?.error ?? .infinity {
                best = (lambda, error)
            }
        }
        guard let best, let (coefX, coefY) = solve(samples, lambda: best.lambda, mean: mean, std: std) else {
            throw .mapperSingular
        }
        return MapperModel(
            featureVersion: GazeFeatures.featureVersion, mean: mean, std: std,
            coefX: coefX, coefY: coefY, lambda: best.lambda, residualPoints: best.error
        )
    }

    /// Median error (points) per group when each group is predicted by a model fitted without it.
    public static func leaveGroupOutErrors(_ samples: [CalibrationSample], lambda: Double) -> [Int: Double] {
        let (mean, std) = statistics(samples.map(\.features))
        var errors: [Int: Double] = [:]
        for group in Set(samples.map(\.group)) {
            let train = samples.filter { $0.group != group }
            let test = samples.filter { $0.group == group }
            guard let (cx, cy) = solve(train, lambda: lambda, mean: mean, std: std) else { continue }
            let distances = test.map { sample -> Double in
                let phi = basis(standardize(sample.features, mean: mean, std: std))
                return Point(x: dot(cx, phi), y: dot(cy, phi)).distance(to: sample.target)
            }
            errors[group] = median(distances)
        }
        return errors
    }

    // MARK: Internals

    /// Polynomial basis over standardized inputs: bias, linear terms, eye-average quadratics and pose couplings.
    static func basis(_ z: [Double]) -> [Double] {
        let u = (z[0] + z[2]) / 2
        let v = (z[1] + z[3]) / 2
        let yaw = z[4], pitch = z[5], scale = z[9]
        return [1] + z + [u * u, v * v, u * v, u * scale, v * scale, yaw * u, pitch * v]
    }

    static var basisCount: Int { 1 + GazeFeatures.mapperInputCount + 7 }

    static func standardize(_ x: [Double], mean: [Double], std: [Double]) -> [Double] {
        zip(x, zip(mean, std)).map { value, ms in (value - ms.0) / ms.1 }
    }

    static func statistics(_ rows: [[Double]]) -> (mean: [Double], std: [Double]) {
        let n = Double(rows.count)
        let width = rows.first?.count ?? 0
        var mean = [Double](repeating: 0, count: width)
        for row in rows {
            for i in 0 ..< width {
                mean[i] += row[i] / n
            }
        }
        var std = [Double](repeating: 0, count: width)
        for row in rows {
            for i in 0 ..< width {
                std[i] += (row[i] - mean[i]) * (row[i] - mean[i]) / n
            }
        }
        // Constant inputs (e.g. no head pose from the provider) get unit scale instead of dividing by zero.
        return (mean, std.map { $0 > 1e-12 ? $0.squareRoot() : 1 })
    }

    static func solve(
        _ samples: [CalibrationSample], lambda: Double, mean: [Double], std: [Double]
    ) -> ([Double], [Double])? {
        let p = basisCount
        var ata = [Double](repeating: 0, count: p * p)
        var atx = [Double](repeating: 0, count: p)
        var aty = [Double](repeating: 0, count: p)
        for sample in samples {
            let phi = basis(standardize(sample.features, mean: mean, std: std))
            let w = sample.weight
            for i in 0 ..< p {
                atx[i] += w * phi[i] * sample.target.x
                aty[i] += w * phi[i] * sample.target.y
                for j in 0 ..< p {
                    ata[i * p + j] += w * phi[i] * phi[j]
                }
            }
        }
        for i in 1 ..< p { // the intercept isn't penalized
            ata[i * p + i] += lambda
        }
        ata[0] += 1e-9
        guard let cx = LinearAlgebra.choleskySolve(ata, atx, n: p),
              let cy = LinearAlgebra.choleskySolve(ata, aty, n: p) else { return nil }
        return (cx, cy)
    }

    static func crossValidatedError(
        _ samples: [CalibrationSample], lambda: Double, mean: [Double], std: [Double]
    ) -> Double? {
        var squared = 0.0
        var count = 0.0
        for group in Set(samples.map(\.group)) {
            let train = samples.filter { $0.group != group }
            guard let (cx, cy) = solve(train, lambda: lambda, mean: mean, std: std) else { return nil }
            for sample in samples where sample.group == group {
                let phi = basis(standardize(sample.features, mean: mean, std: std))
                let d = Point(x: dot(cx, phi), y: dot(cy, phi)).distance(to: sample.target)
                squared += d * d
                count += 1
            }
        }
        return count > 0 ? (squared / count).squareRoot() : nil
    }

    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return .nan }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
