import Foundation

/// Opt-in state for anonymous metrics and crash reports (F-12). Off until the user says yes.
public struct MetricsConsent: Equatable, Sendable, Codable {
    public var state: ConsentState
    public var changedAt: Date?
    /// Random per install. Regenerated on opt-out → opt-in and on "Delete all data" (ARCHITECTURE §4).
    public var installID: UUID

    public init(state: ConsentState = .neverAsked, changedAt: Date? = nil, installID: UUID) {
        self.state = state
        self.changedAt = changedAt
        self.installID = installID
    }

    /// Whether TelemetryDeck/Sentry may be initialized at all (G-SEC-05).
    public var allowsSending: Bool { state == .optedIn }

    /// Applies a user choice. Opting back in after an opt-out gets a fresh install ID so the two periods
    /// can't be linked.
    public func updated(
        to newState: ConsentState,
        at date: Date,
        newInstallID: () -> UUID = UUID.init
    ) -> MetricsConsent {
        guard newState != state else { return self }
        let id = (state == .optedOut && newState == .optedIn) ? newInstallID() : installID
        return MetricsConsent(state: newState, changedAt: date, installID: id)
    }
}

public enum ConsentState: String, Sendable, Codable, CaseIterable {
    case neverAsked, optedIn, optedOut
}
