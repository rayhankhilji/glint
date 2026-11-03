import Foundation

/// Deterministic SplitMix64 random number generator (TESTING_GUIDE §4.4). Same seed → same sequence on every
/// platform, so synthetic data and noise in tests and evals are reproducible.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    public let seed: UInt64
    private var state: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniformly distributed `Double` in `0..<1`.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A normally distributed sample (Box–Muller).
    public mutating func nextGaussian(mean: Double = 0, standardDeviation: Double = 1) -> Double {
        let u1 = max(nextUnit(), .leastNonzeroMagnitude)
        let u2 = nextUnit()
        let z = (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
        return mean + standardDeviation * z
    }
}
