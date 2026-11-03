import SaccadeCore

/// Camera permission state.
public enum CameraAuthorization: Sendable, Equatable {
    case notDetermined, granted, denied, restricted
}

/// Produces one `FaceObservation` (or `nil` when no face is found) per camera frame.
public protocol FaceTracking: AnyObject, Sendable {
    var observations: AsyncStream<FaceObservation?> { get }
    func cameraAuthorization() -> CameraAuthorization
    func requestCameraAccess() async -> Bool
    func start() throws(SaccadeError)
    func stop()
}
