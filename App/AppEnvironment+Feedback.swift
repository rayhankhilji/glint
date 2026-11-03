import AppKit
import SaccadeCore
import SaccadePlatform
import SaccadeRuntime
import SaccadeServices
import SaccadeUI

/// HUD messages, click sound, live accuracy and diagnostics, and session recording.
extension AppEnvironment {
    // MARK: HUD

    func announce(_ event: HUDEvent) {
        guard hudPolicy.admit(event, at: ProcessInfo.processInfo.systemUptime) else { return }
        hud.show(HUDMessage.make(for: event, liveDegrees: tracking.liveAccuracyDegrees))
    }

    /// After each click label: publish live accuracy and, rarely, advise.
    func reviewAccuracy() {
        let live = tracking.liveAccuracyDegrees.map { AccuracyReading(medianErrorDegrees: $0) }
        if settingsModel.liveAccuracy != live {
            settingsModel.liveAccuracy = live
        }
        switch AccuracyAdvice.evaluate(calibrated: tracking.accuracyDegrees, live: tracking.liveAccuracyDegrees) {
        case .recalibrate: announce(.accuracyDipped)
        case .improved: announce(.accuracyImproved)
        case .none: break
        }
    }

    func playClickSound() {
        guard settings.clickSound, let clickSound else { return }
        clickSound.stop()
        clickSound.volume = 0.35
        clickSound.play()
    }

    // MARK: Diagnostics

    /// Refreshes Settings → Advanced at most twice a second.
    func refreshDiagnostics() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDiagnostics >= 0.5 else { return }
        lastDiagnostics = now
        var fps = 0
        if case let .tracking(rate) = tracking.status {
            fps = rate
        }
        let sample = tracking.latest
        let diagnostics = LiveDiagnostics(
            framesPerSecond: fps,
            sigmaPoints: sample?.sigma ?? 0,
            confidence: sample?.confidence ?? 0,
            learnedClicks: tracking.learnedLabels,
            accessibilityP50: coordinator.snapshotLatency.percentile(50),
            accessibilityP95: coordinator.snapshotLatency.percentile(95)
        )
        if settingsModel.diagnostics != diagnostics {
            settingsModel.diagnostics = diagnostics
        }
    }

    // MARK: Recording

    /// Starts or stops the features-only trace to match the setting.
    func updateRecording() {
        if settings.recordTraces, traceWriter == nil, let writer = TraceWriter(paths: paths) {
            traceWriter = writer
            let frame = GazeOverlayWindowController.primaryFrame
            tracking.beginTrace(screen: Size(width: frame.width, height: frame.height)) { record in
                writer.append(record)
            }
        } else if !settings.recordTraces, let writer = traceWriter {
            tracking.traceSink = nil
            writer.close()
            traceWriter = nil
        }
    }

    func revealTraces() {
        try? FileManager.default.createDirectory(at: paths.tracesDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(paths.tracesDirectory)
    }
}
