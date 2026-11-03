import AVFoundation
import Foundation
import GlintCore
import GlintPlatform
import Vision

/// Glint's own types are written `GlintCore.FaceObservation` / `GlintCore.Clock` in this file: macOS 15+ Vision
/// declares its own `FaceObservation`, and the standard library has a `Clock`.
///
/// Camera capture + Apple Vision face landmarks (ARCHITECTURE §10.1, Vision provider). Works on Apple Silicon and
/// Intel Macs. Each frame is analyzed on the capture queue and released immediately: only numeric landmarks leave
/// this class (G-SEC-01).
public final class FaceTracker: NSObject, FaceTracking, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {
    // @unchecked: `session` and `configured` are touched only on `sessionQueue`; `sequenceHandler` only on
    // `frameQueue`; the stream continuation is thread-safe.
    public let observations: AsyncStream<GlintCore.FaceObservation?>
    private let continuation: AsyncStream<GlintCore.FaceObservation?>.Continuation
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.glint.camera.session")
    private let frameQueue = DispatchQueue(label: "app.glint.camera.frames", qos: .userInteractive)
    private let sequenceHandler = VNSequenceRequestHandler()
    private let clock: any GlintCore.Clock
    private var configured = false

    public init(clock: any GlintCore.Clock = SystemClock()) {
        let pair = AsyncStream<GlintCore.FaceObservation?>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observations = pair.stream
        continuation = pair.continuation
        self.clock = clock
        super.init()
    }

    public func cameraAuthorization() -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    public func requestCameraAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    public func start() throws(GlintError) {
        switch cameraAuthorization() {
        case .granted: break
        case .restricted: throw .cameraRestricted
        case .denied, .notDetermined: throw .cameraPermissionDenied
        }
        guard Self.preferredCamera() != nil else { throw .cameraNotFound }
        sessionQueue.async { [self] in
            // Look the device up on this queue: AVCaptureDevice isn't Sendable.
            if !configured, let device = Self.preferredCamera() {
                configure(device)
            }
            if configured, !session.isRunning {
                session.startRunning()
            }
        }
    }

    public func stop() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        continuation.yield(nil)
    }

    /// The built-in camera when there is one, otherwise the first external or Continuity camera.
    static func preferredCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first { $0.deviceType == .builtInWideAngleCamera }
            ?? discovery.devices.first
            ?? AVCaptureDevice.default(for: .video)
    }

    /// Runs on `sessionQueue`.
    private func configure(_ device: AVCaptureDevice) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // 640×480 is plenty for landmarks and keeps Vision fast on Intel Macs too.
        session.sessionPreset = session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .high
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            GlintLog.log(.cameraNotFound, in: .perception)
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output
            .videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(output) else {
            GlintLog.log(.cameraNotFound, in: .perception)
            return
        }
        session.addOutput(output)
        configured = true
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate (runs on `frameQueue`)

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        continuation.yield(detectFace(in: pixelBuffer))
    }

    private func detectFace(in pixelBuffer: CVPixelBuffer) -> GlintCore.FaceObservation? {
        let request = VNDetectFaceLandmarksRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            return nil
        }
        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye
        else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: width, height: height)
        let h = Double(height)
        // Vision uses a bottom-left origin; Glint uses top-left.
        func points(_ region: VNFaceLandmarkRegion2D) -> [GlintCore.Point] {
            region.pointsInImage(imageSize: imageSize).map { GlintCore.Point(x: Double($0.x), y: h - Double($0.y)) }
        }
        let box = VNImageRectForNormalizedRect(face.boundingBox, width, height)
        return GlintCore.FaceObservation(
            timestamp: clock.now(),
            imageSize: GlintCore.Size(width: Double(width), height: h),
            leftEye: points(leftEye),
            rightEye: points(rightEye),
            leftPupil: landmarks.leftPupil.flatMap { points($0).first },
            rightPupil: landmarks.rightPupil.flatMap { points($0).first },
            faceBounds: GlintCore.Rect(
                x: Double(box.minX),
                y: h - Double(box.maxY),
                width: Double(box.width),
                height: Double(box.height)
            ),
            yaw: face.yaw?.doubleValue,
            pitch: face.pitch?.doubleValue,
            roll: face.roll?.doubleValue,
            confidence: Double(landmarks.confidence)
        )
    }
}
