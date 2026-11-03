import Testing
@testable import GlintCore

@Suite("GlintError catalogue")
struct GlintErrorTests {
    /// The catalogue in ARCHITECTURE §5.3. Codes are public contract: changing one breaks diagnostics and
    /// telemetry history, so this list must only ever grow.
    static let documentedCodes: Set<String> = [
        "CAMERA_PERMISSION_DENIED", "CAMERA_RESTRICTED", "AX_PERMISSION_MISSING", "CAMERA_NOT_FOUND",
        "CAMERA_INTERRUPTED", "MODEL_LOAD_FAILED", "MODEL_CHECKSUM_MISMATCH", "NOT_CALIBRATED",
        "CALIBRATION_INSUFFICIENT", "MAPPER_SINGULAR", "AX_TIMEOUT", "AX_ACTION_UNSUPPORTED", "AX_ELEMENT_GONE",
        "ACTUATION_FAILED", "SETTINGS_CORRUPT", "PERSISTENCE_FAILED",
    ]

    @Test("Every case has a unique, documented code")
    func codesMatchDocs() {
        let codes = GlintError.catalogue.map(\.code)
        #expect(Set(codes).count == codes.count)
        #expect(Set(codes) == Self.documentedCodes)
    }

    @Test("Codes are SCREAMING_SNAKE_CASE")
    func codeFormat() {
        for error in GlintError.catalogue {
            #expect(error.code.allSatisfy { $0.isUppercase || $0 == "_" }, "\(error.code)")
        }
    }

    @Test("Codes don't depend on associated values")
    func codesIgnoreAssociatedValues() {
        #expect(GlintError.cameraInterrupted(.deviceDisconnected).code == GlintError.cameraInterrupted(.unknown).code)
        #expect(GlintError.calibrationInsufficient(anchorsOK: 3).code == "CALIBRATION_INSUFFICIENT")
    }

    @Test("Every category is used")
    func categoriesCovered() {
        #expect(Set(GlintError.catalogue.map(\.category)) == Set(GlintErrorCategory.allCases))
    }

    @Test("AX action raw values are the real AX action names")
    func axActionNames() {
        #expect(AXActionName.press.rawValue == "AXPress")
        #expect(AXActionName.showMenu.rawValue == "AXShowMenu")
        #expect(AXActionName.raise.rawValue == "AXRaise")
    }
}
