import os

/// Signpost intervals for Instruments profiling (ARCHITECTURE §14, EVAL_GUARDRAILS §6).
public struct GlintSignposts: Sendable {
    public enum Interval: CaseIterable, Sendable {
        case appLaunch, frame, landmarks, map, intent, axSnapshot, render

        /// Signpost names must be static strings.
        var name: StaticString {
            switch self {
            case .appLaunch: "appLaunch"
            case .frame: "frame"
            case .landmarks: "landmarks"
            case .map: "map"
            case .intent: "intent"
            case .axSnapshot: "axSnapshot"
            case .render: "render"
            }
        }
    }

    public static let shared = GlintSignposts()

    private let signposter = OSSignposter(subsystem: GlintLog.subsystem, category: "pipeline")

    public init() {}

    /// Measures `body` as one interval.
    public func measure<T>(_ interval: Interval, _ body: () throws -> T) rethrows -> T {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(interval.name, id: id)
        defer { signposter.endInterval(interval.name, state) }
        return try body()
    }

    /// Begins an interval that ends elsewhere (e.g. app launch → first sample).
    public func begin(_ interval: Interval) -> OSSignpostIntervalState {
        signposter.beginInterval(interval.name, id: signposter.makeSignpostID())
    }

    public func end(_ interval: Interval, _ state: OSSignpostIntervalState) {
        signposter.endInterval(interval.name, state)
    }
}
