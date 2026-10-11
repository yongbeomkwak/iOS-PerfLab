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
        #expect(metadata.stages == [.naive, .optimized, .advanced])
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

@MainActor
struct PerfMonitorTests {
    /// 60Hz 한 프레임.
    private let frame = 1.0 / 60

    @Test func keepsTargetWhenCallbackIsOnTime() {
        #expect(PerfMonitor.nextPresentation(target: 10.0, frameDuration: frame, now: 9.99) == 10.0)
    }

    /// 콜백이 늦어 예정 시각이 지났으면 지금 이후의 첫 프레임 경계로 올린다.
    @Test func movesStaleTargetToNextFrameBoundary() {
        let presentation = PerfMonitor.nextPresentation(target: 10.0, frameDuration: frame, now: 10.057)
        #expect(presentation >= 10.057)
        #expect(presentation - 10.057 < frame)
        // 프레임 경계는 원래 예정 시각에서 프레임 길이의 정수배만큼 떨어져 있다.
        let frames = (presentation - 10.0) / frame
        #expect(abs(frames - frames.rounded()) < 1e-9)
    }
}
