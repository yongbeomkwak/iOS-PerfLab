import XCTest

/// `scripts/perflab measure`가 실행하는 자동 측정 테스트.
///
/// 환경 변수(xcodebuild 실행 시 `TEST_RUNNER_` 접두사로 전달)
/// - `PERFLAB_TOPIC`: 주제 id (필수, 없으면 skip)
/// - `PERFLAB_STAGES`: `0,1,2`
/// - `PERFLAB_FRAMEWORKS`: `uikit,swiftui`
/// - `PERFLAB_DURATION`, `PERFLAB_WARMUP`: 초 단위
/// - `PERFLAB_REPEAT`: 조합별 반복 횟수
/// - `PERFLAB_BASELINE`: `1`이면 회차마다 빈 화면(`_baseline`)도 측정한다
final class BenchmarkUITests: XCTestCase {
    private let resultIdentifier = "perflab.benchmark.result"
    private let baselineTopicID = "_baseline"

    @MainActor
    func testBenchmark() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let topicID = environment["PERFLAB_TOPIC"], !topicID.isEmpty else {
            throw XCTSkip("PERFLAB_TOPIC is not set")
        }
        let stages = (environment["PERFLAB_STAGES"] ?? "0,1,2").split(separator: ",").map(String.init)
        let frameworks = (environment["PERFLAB_FRAMEWORKS"] ?? "uikit,swiftui").split(separator: ",").map(String.init)
        let duration = Double(environment["PERFLAB_DURATION"] ?? "") ?? 10
        let warmUp = Double(environment["PERFLAB_WARMUP"] ?? "") ?? 2
        let repeatCount = Int(environment["PERFLAB_REPEAT"] ?? "") ?? 1
        let includesBaseline = environment["PERFLAB_BASELINE"] == "1"

        var runs: [(topicID: String, stage: String, framework: String)] = []
        if includesBaseline {
            runs.append((baselineTopicID, "0", "swiftui"))
        }
        for framework in frameworks {
            for stage in stages {
                runs.append((topicID, stage, framework))
            }
        }

        // 회차 단위로 모든 조합을 한 번씩 돌린다. 발열 같은 시간에 따른 변화가 특정 조합에 몰리지 않게 하기 위해서다.
        for round in 1...repeatCount {
            for run in runs {
                try measure(
                    topicID: run.topicID,
                    stage: run.stage,
                    framework: run.framework,
                    round: round,
                    duration: duration,
                    warmUp: warmUp
                )
            }
        }
    }

    @MainActor
    private func measure(
        topicID: String,
        stage: String,
        framework: String,
        round: Int,
        duration: Double,
        warmUp: Double
    ) throws {
        try XCTContext.runActivity(named: "#\(round) \(topicID) · Stage \(stage) · \(framework)") { _ in
            let app = XCUIApplication()
            app.launchArguments = [
                "-PerfLabTopic", topicID,
                "-PerfLabStage", stage,
                "-PerfLabFramework", framework,
                "-PerfLabDuration", String(duration),
                "-PerfLabWarmUp", String(warmUp),
            ]
            app.launch()
            defer { app.terminate() }

            // 측정이 끝날 때까지 앱에 접근성 질의를 보내지 않는다. waitForExistence는 화면 트리를 반복해서 읽어 오고,
            // 앱의 메인 스레드가 그 요청을 처리하느라 측정이 밀린다 (행이 많은 UITableView에서 입력 지연 2ms → 856ms).
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "measuring")], timeout: warmUp + duration)

            let element = app.descendants(matching: .any)[resultIdentifier]
            XCTAssertTrue(element.waitForExistence(timeout: 30), "Benchmark result not found")
            let json = try XCTUnwrap(element.value as? String)

            let attachment = XCTAttachment(data: Data(json.utf8), uniformTypeIdentifier: "public.json")
            attachment.name = "perflab_\(topicID)_r\(round)_stage\(stage)-\(framework).json"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
