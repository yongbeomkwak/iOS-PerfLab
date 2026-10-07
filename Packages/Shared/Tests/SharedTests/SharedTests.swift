import Foundation
import Testing
@testable import Shared

struct SeededRandomNumberGeneratorTests {
    @Test func sameSeedProducesSameSequence() {
        var a = SeededRandomNumberGenerator(seed: 42)
        var b = SeededRandomNumberGenerator(seed: 42)
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
    }

    @Test func differentSeedProducesDifferentSequence() {
        var a = SeededRandomNumberGenerator(seed: 1)
        var b = SeededRandomNumberGenerator(seed: 2)
        #expect(a.next() != b.next())
    }
}

struct TopicMetadataTests {
    @Test func decodesTopicJSON() throws {
        let json = """
        {
          "id": "01-sample", "number": 1, "title": "Sample", "summary": "summary",
          "category": "rendering", "tags": ["CoreGraphics"], "status": "proposed",
          "stages": [0, 1, 2], "frameworks": ["uikit", "swiftui"]
        }
        """
        let metadata = try JSONDecoder().decode(TopicMetadata.self, from: Data(json.utf8))
        #expect(metadata.category == .rendering)
        #expect(metadata.stages == [.naive, .optimized, .lowLevel])
        #expect(metadata.status < .archived)
    }
}

@MainActor
struct CustomMetricRecorderTests {
    @Test func averagesRepeatedRecords() {
        let recorder = CustomMetricRecorder()
        recorder.record("parse", value: 10, unit: "ms")
        recorder.record("parse", value: 20, unit: "ms")
        #expect(recorder.snapshot == [CustomMetric(name: "parse", value: 15, unit: "ms")])
    }
}
