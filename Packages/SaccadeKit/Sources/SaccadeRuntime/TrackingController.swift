import Foundation
import Observation
import SaccadeCore
import SaccadePerception
import SaccadePlatform
import SaccadeServices

/// Owns the live eye-tracking loop (ARCHITECTURE §3 SaccadeRuntime): decides when the camera runs, feeds every frame
/// through the `GazeEstimator` and any active `CalibrationSession`, persists calibration results, and publishes the
/// app status. All decisions it applies come from SaccadeCore.
@MainActor
@Observable
public final class TrackingController {
    public private(set) var status: SaccadeStatus = .off
    public private(set) var latest: GazeSample?
    public private(set) var calibration: CalibrationSession?
    public private(set) var stored: StoredCalibration?

    /// Called after every processed frame and status change, for UI that isn't driven by observation.
    @ObservationIgnored public var onUpdate: @MainActor () -> Void = {}
    /// Called once per recognized gesture.
    @ObservationIgnored public var onGesture: @MainActor (BlinkGrammar.Gesture, GazeSample) -> Void = { _, _ in }

    @ObservationIgnored private let tracker: any FaceTracking
    @ObservationIgnored private let profiles: ProfileStore
    @ObservationIgnored private let clock: any SaccadeCore.Clock
    @ObservationIgnored private let pointsPerDegree: Double
    @ObservationIgnored private var estimator: GazeEstimator
    @ObservationIgnored private var settings: Settings
    @ObservationIgnored private var cameraRunning = false
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var frameTimes: [TimeInterval] = []
    @ObservationIgnored private var lastFaceTime: TimeInterval?

    /// No face for this long switches to "away" (PRD F-10).
    static let awayAfter: TimeInterval = 5

    public init(
        tracker: any FaceTracking,
        profiles: ProfileStore,
        settings: Settings,
        pointsPerDegree: Double,
        clock: any SaccadeCore.Clock = SystemClock()
    ) {
        self.tracker = tracker
        self.profiles = profiles
        self.settings = settings
        self.pointsPerDegree = pointsPerDegree
        self.clock = clock
        let stored = profiles.load()
        self.stored = stored
        estimator = GazeEstimator(model: stored?.result.model)
    }

    public var isCalibrated: Bool { stored != nil }

    /// The accuracy of the saved calibration, in degrees.
    public var accuracyDegrees: Double? { stored?.medianErrorDegrees }

    // MARK: Control

    /// Applies new settings: starts or stops the camera as needed.
    public func apply(settings: Settings) {
        self.settings = settings
        refresh()
    }

    /// Starts a calibration run on a screen of `screenSize` points.
    public func beginCalibration(screenSize: Size) {
        calibration = CalibrationSession(screenSize: screenSize)
        refresh()
    }

    /// Ends the calibration UI (after a result, a failure or Esc). A successful result is already saved.
    public func endCalibration() {
        calibration = nil
        refresh()
    }

    /// Re-evaluates whether the camera should run and what the status is.
    public func refresh() {
        let paused = settings.pausedUntil.map { $0 > Date() } ?? false
        let wantsCamera = calibration != nil || (settings.isEnabled && !paused)
        guard wantsCamera else {
            stopCamera()
            status = SaccadeStatus.resolve(settings: settings, hasCalibration: isCalibrated, now: Date())
            onUpdate()
            return
        }
        switch tracker.cameraAuthorization() {
        case .granted:
            startCamera()
        case .notDetermined:
            status = .starting
            Task { [weak self] in
                guard let self else { return }
                _ = await tracker.requestCameraAccess()
                refresh()
            }
        case .denied, .restricted:
            stopCamera()
            status = .needsAttention(.cameraPermissionMissing)
        }
        onUpdate()
    }

    // MARK: Camera

    private func startCamera() {
        guard !cameraRunning else { return }
        do {
            try tracker.start()
        } catch {
            SaccadeLog.log(error, in: .perception)
            status = error == .cameraNotFound ? .needsAttention(.cameraMissing) :
                .needsAttention(.cameraPermissionMissing)
            return
        }
        cameraRunning = true
        status = isCalibrated || calibration != nil ? .starting : .needsAttention(.notCalibrated)
        if streamTask == nil {
            let stream = tracker.observations
            streamTask = Task { [weak self] in
                for await observation in stream {
                    self?.handle(observation)
                }
            }
        }
    }

    private func stopCamera() {
        guard cameraRunning else { return }
        tracker.stop()
        cameraRunning = false
        latest = nil
        frameTimes.removeAll()
    }

    // MARK: Frames

    /// Processes one frame. Internal (not private) so tests can drive frames deterministically.
    func handle(_ observation: FaceObservation?) {
        guard cameraRunning else { return }
        let t = clock.now()
        let sample = estimator.ingest(observation, at: t)
        latest = sample
        if sample.faceVisible {
            lastFaceTime = t
        }
        updateFrameRate(t)

        if var session = calibration {
            session.ingest(features: sample.faceVisible ? sample.features : nil, at: t)
            calibration = session
            if case let .finished(result) = session.phase, stored?.result != result {
                save(result)
            }
        } else if let gesture = sample.gesture {
            onGesture(gesture, sample)
        }
        status = liveStatus(at: t)
        onUpdate()
    }

    private func save(_ result: CalibrationResult) {
        let degrees = result.medianErrorDegrees(pointsPerDegree: pointsPerDegree)
        let record = StoredCalibration(createdAt: Date(), result: result, medianErrorDegrees: degrees)
        do {
            try profiles.save(record)
        } catch {
            SaccadeLog.log(error, in: .storage)
        }
        stored = record
        estimator.setModel(result.model)
    }

    private func liveStatus(at t: TimeInterval) -> SaccadeStatus {
        if calibration != nil {
            return .tracking(fps: fps)
        }
        guard isCalibrated else { return .needsAttention(.notCalibrated) }
        if let last = lastFaceTime, t - last > Self.awayAfter {
            return .away
        }
        if latest?.faceVisible == true || lastFaceTime != nil {
            return .tracking(fps: fps)
        }
        return .starting
    }

    private func updateFrameRate(_ t: TimeInterval) {
        frameTimes.append(t)
        frameTimes.removeAll { t - $0 > 1 }
    }

    private var fps: Int { frameTimes.count }
}
