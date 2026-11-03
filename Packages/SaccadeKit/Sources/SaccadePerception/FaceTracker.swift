import AVFoundation
import Foundation
import SaccadeCore
import SaccadePlatform
import Vision

/// Saccade's own types are written `SaccadeCore.FaceObservation` / `SaccadeCore.Clock` in this file: macOS 15+ Vision
/// declares its own `FaceObservation`, and the standard library has a `Clock`.
///
/// Camera capture + Apple Vision face landmarks (ARCHITECTURE §10.1, Vision provider). Works on Apple Silicon and
/// Intel Macs. Each frame is analyzed on the capture queue and released immediately: only numeric landmarks leave
/// this class (G-SEC-01).
public final class FaceTracker: NSObject, FaceTracking, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {
    // @unchecked: `session` and `configured` are touched only on `sessionQueue`; `sequenceHandler` only on
    // `frameQueue`; the stream continuation is thread-safe.
    public let observations: AsyncStream<SaccadeCore.FaceObservation?>
    private let continuation: AsyncStream<SaccadeCore.FaceObservation?>.Continuation
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.saccade.camera.session")
    private let frameQueue = DispatchQueue(label: "app.saccade.camera.frames", qos: .userInteractive)
    private let sequenceHandler = VNSequenceRequestHandler()
    private let clock: any SaccadeCore.Clock
    private var configured = false

    public init(clock: any SaccadeCore.Clock = SystemClock()) {
        let pair = AsyncStream<SaccadeCore.FaceObservation?>.makeStream(bufferingPolicy: .bufferingNewest(1))
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

    public func start() throws(SaccadeError) {
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
        // 720p puts ~2× more pixels on each iris than 640×480, which IrisLocator turns into precision.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .high
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            SaccadeLog.log(.cameraNotFound, in: .perception)
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
            SaccadeLog.log(.cameraNotFound, in: .perception)
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

    private func detectFace(in pixelBuffer: CVPixelBuffer) -> SaccadeCore.FaceObservation? {
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
        // Vision uses a bottom-left origin; Saccade uses top-left.
        func points(_ region: VNFaceLandmarkRegion2D) -> [SaccadeCore.Point] {
            region.pointsInImage(imageSize: imageSize).map { SaccadeCore.Point(x: Double($0.x), y: h - Double($0.y)) }
        }
        let box = VNImageRectForNormalizedRect(face.boundingBox, width, height)
        let leftOutline = points(leftEye)
        let rightOutline = points(rightEye)
        return SaccadeCore.FaceObservation(
            timestamp: clock.now(),
            imageSize: SaccadeCore.Size(width: Double(width), height: h),
            leftEye: leftOutline,
            rightEye: rightOutline,
            leftPupil: landmarks.leftPupil.flatMap { points($0).first },
            rightPupil: landmarks.rightPupil.flatMap { points($0).first },
            leftIris: Self.iris(in: pixelBuffer, outline: leftOutline),
            rightIris: Self.iris(in: pixelBuffer, outline: rightOutline),
            faceBounds: SaccadeCore.Rect(
                x: Double(box.minX), y: h - Double(box.maxY), width: Double(box.width), height: Double(box.height)
            ),
            yaw: face.yaw?.doubleValue,
            pitch: face.pitch?.doubleValue,
            roll: face.roll?.doubleValue,
            confidence: Double(landmarks.confidence)
        )
    }

    /// Sub-pixel iris center for one eye (image pixels), measured from the eye patch around its outline.
    static func iris(in buffer: CVPixelBuffer, outline: [SaccadeCore.Point]) -> SaccadeCore.Point? {
        guard outline.count >= 4,
              let minX = outline.map(\.x).min(), let maxX = outline.map(\.x).max(),
              let minY = outline.map(\.y).min(), let maxY = outline.map(\.y).max()
        else { return nil }
        let w = maxX - minX, h = max(maxY - minY, w * 0.25)
        let rect = SaccadeCore.Rect(x: minX - w * 0.15, y: minY - h * 0.5, width: w * 1.3, height: h * 2)
        guard let patch = FramePreprocessor.eyePatch(from: buffer, rect: rect) else { return nil }
        let origin = SaccadeCore.Point(x: max(0, rect.minX.rounded(.down)), y: max(0, rect.minY.rounded(.down)))
        let opening = outline.map { $0 - origin }
        guard let result = IrisLocator.locate(in: patch, opening: opening),
              result.confidence >= 0.12 else { return nil }
        return result.center + origin
    }
}
