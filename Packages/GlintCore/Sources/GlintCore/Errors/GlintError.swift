/// The single error type crossing module boundaries (ARCHITECTURE §5.3). Each case has a stable `code`
/// that is used in logs, diagnostics exports and bucketed telemetry. Codes never change once shipped.
public enum GlintError: Error, Equatable, Hashable, Sendable {
    case cameraPermissionDenied
    case cameraRestricted
    case accessibilityNotTrusted
    case cameraNotFound
    case cameraInterrupted(CameraInterruptionReason)
    case modelLoadFailed(LandmarkProviderKind)
    case modelChecksumMismatch
    case notCalibrated
    case calibrationInsufficient(anchorsOK: Int)
    case mapperSingular
    case axTimeout
    case axActionUnsupported(AXActionName)
    case axElementInvalid
    case actuationFailed
    case settingsCorrupt
    case persistenceFailed

    /// Stable, user-invisible identifier (SCREAMING_SNAKE). Safe to log at `.public`.
    public var code: String {
        switch self {
        case .cameraPermissionDenied: "CAMERA_PERMISSION_DENIED"
        case .cameraRestricted: "CAMERA_RESTRICTED"
        case .accessibilityNotTrusted: "AX_PERMISSION_MISSING"
        case .cameraNotFound: "CAMERA_NOT_FOUND"
        case .cameraInterrupted: "CAMERA_INTERRUPTED"
        case .modelLoadFailed: "MODEL_LOAD_FAILED"
        case .modelChecksumMismatch: "MODEL_CHECKSUM_MISMATCH"
        case .notCalibrated: "NOT_CALIBRATED"
        case .calibrationInsufficient: "CALIBRATION_INSUFFICIENT"
        case .mapperSingular: "MAPPER_SINGULAR"
        case .axTimeout: "AX_TIMEOUT"
        case .axActionUnsupported: "AX_ACTION_UNSUPPORTED"
        case .axElementInvalid: "AX_ELEMENT_GONE"
        case .actuationFailed: "ACTUATION_FAILED"
        case .settingsCorrupt: "SETTINGS_CORRUPT"
        case .persistenceFailed: "PERSISTENCE_FAILED"
        }
    }

    /// The error's category (EVAL_GUARDRAILS §5), which decides where it is shown to the user.
    public var category: GlintErrorCategory {
        switch self {
        case .cameraPermissionDenied, .cameraRestricted, .accessibilityNotTrusted: .permission
        case .cameraNotFound, .cameraInterrupted: .device
        case .modelLoadFailed, .modelChecksumMismatch: .model
        case .notCalibrated, .calibrationInsufficient, .mapperSingular: .calibration
        case .axTimeout, .axActionUnsupported, .axElementInvalid, .actuationFailed: .system
        case .settingsCorrupt, .persistenceFailed: .storage
        }
    }

    /// Every case once, with representative associated values. Used by catalogue tests and diagnostics.
    public static let catalogue: [GlintError] = [
        .cameraPermissionDenied, .cameraRestricted, .accessibilityNotTrusted, .cameraNotFound,
        .cameraInterrupted(.unknown), .modelLoadFailed(.mediapipe), .modelChecksumMismatch, .notCalibrated,
        .calibrationInsufficient(anchorsOK: 0), .mapperSingular, .axTimeout, .axActionUnsupported(.press),
        .axElementInvalid, .actuationFailed, .settingsCorrupt, .persistenceFailed,
    ]
}

/// Error categories from EVAL_GUARDRAILS §5.
public enum GlintErrorCategory: String, Sendable, CaseIterable {
    case permission, device, model, calibration, system, storage
}

/// Why the camera session stopped delivering frames.
public enum CameraInterruptionReason: String, Sendable, Codable, CaseIterable {
    case deviceInUseByAnotherClient
    case deviceDisconnected
    case systemPressure
    case unknown
}

/// Which landmark provider produced an observation (ARCHITECTURE §10.1).
public enum LandmarkProviderKind: String, Sendable, Codable, CaseIterable {
    case mediapipe
    case vision
}

/// Accessibility actions Glint is allowed to perform (G-SEC-04). Raw values are the AX action names.
public enum AXActionName: String, Sendable, Codable, CaseIterable {
    case press = "AXPress"
    case showMenu = "AXShowMenu"
    case raise = "AXRaise"
}
