import AppKit
import SnapshotTesting
import SwiftUI
import Testing

/// Renders `view` in light and dark appearance and compares against references (TESTING_GUIDE §5.4).
///
/// - `SNAPSHOT_RECORD=1` re-records every reference.
/// - `SACCADE_SNAPSHOT_BOOTSTRAP=1` (CI only, until references recorded on a Mac are committed) records missing
///   references and reports mismatches as known issues instead of failures. See TASK_LOG → Decisions.
@MainActor
func assertSaccadeSnapshot(
    _ view: some View,
    size: CGSize,
    named name: String,
    reduceMotion: Bool = true,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let environment = ProcessInfo.processInfo.environment
    let record: SnapshotTestingConfiguration.Record = environment["SNAPSHOT_RECORD"] == "1" ? .all : .missing
    let bootstrap = environment["SACCADE_SNAPSHOT_BOOTSTRAP"] == "1"

    for (appearanceName, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
        let host = NSHostingView(rootView: AnyView(view.transaction { $0.disablesAnimations = reduceMotion }))
        host.frame = CGRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearanceName)
        host.layoutSubtreeIfNeeded()
        let compare = {
            withSnapshotTesting(record: record) {
                assertSnapshot(
                    of: host as NSView,
                    as: .image(precision: 0.98, perceptualPrecision: 0.98),
                    named: "\(name)-\(suffix)",
                    fileID: fileID,
                    file: filePath,
                    testName: testName,
                    line: line,
                    column: column
                )
            }
        }
        if bootstrap {
            withKnownIssue("Snapshot references not yet recorded on a Mac (bootstrap mode)", isIntermittent: true) {
                compare()
            }
        } else {
            compare()
        }
    }
}
