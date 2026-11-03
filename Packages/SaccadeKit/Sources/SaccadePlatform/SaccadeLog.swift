import os
import SaccadeCore

/// Saccade's logging entry point (ARCHITECTURE §14). Interpolations are `.private` by default; only error codes,
/// enums and numbers may be marked `.public` (G-SEC-03).
public enum SaccadeLog {
    public static let subsystem = "app.saccade"

    public enum Category: String, CaseIterable, Sendable {
        case perception, gaze, intent, ax, actuation, ui, storage, telemetry, update
    }

    public static func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// Logs an error once at `.error` with its stable code as the only public value.
    public static func log(_ error: SaccadeError, in category: Category) {
        logger(category).error("\(message(for: error), privacy: .public)")
    }

    /// The exact text logged for an error: its code and category, nothing user- or app-derived.
    public static func message(for error: SaccadeError) -> String {
        "error code=\(error.code) category=\(error.category.rawValue)"
    }
}
