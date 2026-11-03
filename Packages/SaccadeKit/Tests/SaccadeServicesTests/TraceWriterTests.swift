import Foundation
import SaccadeCore
import SaccadeCoreTestSupport
import SaccadePlatform
import Testing
@testable import SaccadeServices

@Suite("TraceWriter")
struct TraceWriterTests {
    @Test("Writes JSON Lines under traces/ that decode back to the same records")
    func writesTrace() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let writer = try #require(TraceWriter(paths: AppPaths(root: root)))
        let records: [TraceRecord] = [.header(TraceHeader(screen: Size(width: 1440, height: 900), pointsPerDegree: 47))]
            + (0 ..< 200)
            .map { .frame(TraceFrame(t: Double($0) / 30, features: nil, confidence: 0, faceVisible: false)) }
            + [.label(TraceLabel(t: 7, truth: Point(x: 10, y: 20), weight: 1))]
        records.forEach(writer.append)
        writer.close()
        #expect(writer.url.deletingLastPathComponent().lastPathComponent == "traces")
        let text = try String(contentsOf: writer.url, encoding: .utf8)
        #expect(try SessionTrace.decode(text) == records)
    }
}
