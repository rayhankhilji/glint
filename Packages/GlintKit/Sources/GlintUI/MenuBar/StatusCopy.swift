import Foundation
import GlintCore

/// User-facing text for each status (DESIGN_SYSTEM §9.1, §10).
enum StatusCopy {
    static func statusLine(for status: GlintStatus) -> String {
        switch status {
        case .starting:
            return String(localized: "Starting…", bundle: .module)
        case let .tracking(fps):
            return String(localized: "Tracking · \(fps) fps", bundle: .module)
        case .off:
            return String(localized: "Off — camera is off", bundle: .module)
        case let .paused(until):
            guard let until else { return String(localized: "Paused", bundle: .module) }
            let time = until.formatted(date: .omitted, time: .shortened)
            return String(localized: "Paused · resumes \(time)", bundle: .module)
        case .away:
            return String(localized: "Waiting for you…", bundle: .module)
        case .needsAttention(.lowLight):
            return String(localized: "Too dark to see your eyes", bundle: .module)
        case .needsAttention(.notCalibrated):
            return String(localized: "Calibrate to start", bundle: .module)
        case .needsAttention:
            return String(localized: "Glint can't run right now", bundle: .module)
        }
    }

    /// Banner text for problems that block Glint, or `nil` when no banner is needed.
    static func banner(for status: GlintStatus) -> (message: String, action: String)? {
        guard case let .needsAttention(attention) = status else { return nil }
        switch attention {
        case .cameraPermissionMissing:
            return (
                String(localized: "Glint can't see — camera access is off", bundle: .module),
                String(localized: "Fix", bundle: .module)
            )
        case .accessibilityPermissionMissing:
            return (
                String(localized: "Glint can't act — Accessibility is off", bundle: .module),
                String(localized: "Fix", bundle: .module)
            )
        case .cameraMissing:
            return (
                String(localized: "No camera found", bundle: .module),
                String(localized: "Help", bundle: .module)
            )
        case .notCalibrated, .lowLight:
            return nil
        }
    }
}
