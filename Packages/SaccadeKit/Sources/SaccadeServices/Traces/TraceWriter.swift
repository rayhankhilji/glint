import Foundation
import SaccadeCore
import SaccadePlatform

/// Appends a `saccade-trace/v2` session to `traces/session-<timestamp>.jsonl`, off the main thread, in batches.
/// Features and click labels only: never images (G-SEC-01). Stops writing at `maxBytes` so a forgotten recording
/// can't fill the disk.
public final class TraceWriter: @unchecked Sendable {
    // @unchecked: `pending`, `handle` and `written` are touched only on `queue`.
    public let url: URL
    private let queue = DispatchQueue(label: "app.saccade.trace", qos: .utility)
    private var handle: FileHandle?
    private var pending: [String] = []
    private var written = 0
    public static let maxBytes = 64 * 1024 * 1024
    static let batchSize = 90

    /// Creates the file. Returns `nil` if the directory or file can't be created.
    public init?(paths: AppPaths, startedAt date: Date = Date()) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let stamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
        url = paths.tracesDirectory.appendingPathComponent("session-\(stamp).jsonl")
        do {
            try FileManager.default.createDirectory(at: paths.tracesDirectory, withIntermediateDirectories: true)
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return nil }
            handle = try FileHandle(forWritingTo: url)
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
            return nil
        }
    }

    public func append(_ record: TraceRecord) {
        let line = SessionTrace.encodeLine(record)
        queue.async {
            self.pending.append(line)
            if self.pending.count >= Self.batchSize {
                self.flushLocked()
            }
        }
    }

    /// Writes everything pending and closes the file. Safe to call more than once.
    public func close() {
        queue.sync {
            flushLocked()
            try? handle?.close()
            handle = nil
        }
    }

    private func flushLocked() {
        guard let handle, !pending.isEmpty else { return }
        let data = Data((pending.joined(separator: "\n") + "\n").utf8)
        pending.removeAll(keepingCapacity: true)
        guard written + data.count <= Self.maxBytes else { return }
        do {
            try handle.write(contentsOf: data)
            written += data.count
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
        }
    }

    deinit {
        close()
    }
}
