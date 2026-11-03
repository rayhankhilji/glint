import Foundation
import SaccadeCore

/// User-facing text for each status (DESIGN_SYSTEM §9.1, §10).
enum StatusCopy {
    static func statusLine(for status: SaccadeStatus) -> String {
        switch status {
        case .starting:
            return String(localized: "Starting…")
        case let .tracking(fps):
            return String(localized: "Tracking · \(fps) fps")
        case .off:
            return String(localized: "Off — camera is off")
        case let .paused(until):
            guard let until else { return String(localized: "Paused") }
            let time = until.formatted(date: .omitted, time: .shortened)
            return String(localized: "Paused · resumes \(time)")
        case .away:
            return String(localized: "Waiting for you…")
        case .needsAttention(.lowLight):
            return String(localized: "Too dark to see your eyes")
        case .needsAttention(.notCalibrated):
            return String(localized: "Calibrate to start")
        case .needsAttention:
            return String(localized: "Saccade can't run right now")
        }
    }

    /// Banner text for problems that block Saccade, or `nil` when no banner is needed.
    static func banner(for status: SaccadeStatus) -> (message: String, action: String)? {
        guard case let .needsAttention(attention) = status else { return nil }
        switch attention {
        case .cameraPermissionMissing:
            return (
                String(localized: "Saccade can't see — camera access is off"),
                String(localized: "Fix")
            )
        case .accessibilityPermissionMissing:
            return (
                String(localized: "Saccade can't act — Accessibility is off"),
                String(localized: "Fix")
            )
        case .cameraMissing:
            return (
                String(localized: "No camera found"),
                String(localized: "Help")
            )
        case .notCalibrated, .lowLight:
            return nil
        }
    }
}
