import Foundation

/// Minimal dense linear algebra for the gaze mapper (ADR-004: Foundation only, no Accelerate).
enum LinearAlgebra {
    /// Solves `A x = b` for symmetric positive-definite `A` (row-major, n × n) by Cholesky decomposition.
    /// Returns `nil` if `A` isn't positive definite.
    static func choleskySolve(_ a: [Double], _ b: [Double], n: Int) -> [Double]? {
        precondition(a.count == n * n && b.count == n, "dimension mismatch")
        var l = [Double](repeating: 0, count: n * n)
        for i in 0 ..< n {
            for j in 0 ... i {
                var sum = a[i * n + j]
                for k in 0 ..< j {
                    sum -= l[i * n + k] * l[j * n + k]
                }
                if i == j {
                    guard sum > 1e-12 else { return nil }
                    l[i * n + i] = sum.squareRoot()
                } else {
                    l[i * n + j] = sum / l[j * n + j]
                }
            }
        }
        var y = [Double](repeating: 0, count: n)
        for i in 0 ..< n {
            var sum = b[i]
            for k in 0 ..< i {
                sum -= l[i * n + k] * y[k]
            }
            y[i] = sum / l[i * n + i]
        }
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = y[i]
            for k in (i + 1) ..< n {
                sum -= l[k * n + i] * x[k]
            }
            x[i] = sum / l[i * n + i]
        }
        return x
    }
}
