import Foundation

/// Live counters shown in Settings → Advanced and written by "Export diagnostics" (ARCHITECTURE §14).
/// Contains only numbers and enum-like codes, never strings from other apps (G-SEC-14).
public struct Diagnostics: Equatable, Sendable, Codable {
    /// Occurrences per `GlintError.code`.
    public private(set) var errorCounts: [String: Int] = [:]
    /// Frame → sample latency in milliseconds.
    public private(set) var latency = LatencyWindow(capacity: 300)
    public var provider: LandmarkProviderKind?
    public var framesPerSecond: Double = 0

    public init() {}

    public mutating func record(_ error: GlintError) {
        errorCounts[error.code, default: 0] += 1
    }

    public mutating func recordLatency(milliseconds: Double) {
        latency.append(milliseconds)
    }

    public func count(of error: GlintError) -> Int {
        errorCounts[error.code] ?? 0
    }
}

/// A fixed-size window of samples with percentile queries.
public struct LatencyWindow: Equatable, Sendable, Codable {
    public let capacity: Int
    public private(set) var samples: [Double] = []
    private var next = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        guard value.isFinite else { return }
        if samples.count < capacity {
            samples.append(value)
        } else {
            samples[next] = value
        }
        next = (next + 1) % capacity
    }

    /// The `p`-th percentile (0...100) using nearest-rank, or `nil` when empty.
    public func percentile(_ p: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let rank = Int((p.clamped(to: 0 ... 100) / 100 * Double(sorted.count)).rounded(.up))
        return sorted[max(rank, 1) - 1]
    }
}
