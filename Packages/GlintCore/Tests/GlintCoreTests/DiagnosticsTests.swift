import Foundation
import Testing
@testable import GlintCore

@Suite("Diagnostics")
struct DiagnosticsTests {
    @Test("Errors are counted by code")
    func counting() {
        var d = Diagnostics()
        d.record(.axTimeout)
        d.record(.axTimeout)
        d.record(.cameraInterrupted(.deviceDisconnected))
        #expect(d.count(of: .axTimeout) == 2)
        #expect(d.count(of: .cameraInterrupted(.unknown)) == 1)
        #expect(d.count(of: .settingsCorrupt) == 0)
    }

    @Test("Latency window keeps the newest samples and reports nearest-rank percentiles")
    func latencyWindow() {
        var w = LatencyWindow(capacity: 4)
        #expect(w.percentile(50) == nil)
        for v in [10.0, 20, 30, 40, 50, .nan] {
            w.append(v)
        }
        #expect(w.samples.sorted() == [20, 30, 40, 50])
        #expect(w.percentile(50) == 30)
        #expect(w.percentile(95) == 50)
        #expect(w.percentile(0) == 20)
    }

    @Test("Exported diagnostics contain only codes, numbers and enum values (G-SEC-14)")
    func exportIsNumericOrEnum() throws {
        var d = Diagnostics()
        d.provider = .vision
        d.framesPerSecond = 29.97
        d.record(.axTimeout)
        d.recordLatency(milliseconds: 31)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(d))
        let allowedStrings = Set(GlintError.catalogue.map(\.code)).union(LandmarkProviderKind.allCases.map(\.rawValue))
        func check(_ value: Any) {
            switch value {
            case let dict as [String: Any]:
                dict.values.forEach(check)
            case let array as [Any]: array.forEach(check)
            case let string as String: #expect(allowedStrings.contains(string), "unexpected string \(string)")
            default: break
            }
        }
        check(json)
        let counts = try #require((json as? [String: Any])?["errorCounts"] as? [String: Any])
        #expect(Set(counts.keys).isSubset(of: Set(GlintError.catalogue.map(\.code))))
    }
}
