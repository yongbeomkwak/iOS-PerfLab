import XCTest

/// `scripts/perflab measure`가 실행하는 자동 측정 테스트.
///
/// 환경 변수(xcodebuild 실행 시 `TEST_RUNNER_` 접두사로 전달)
/// - `PERFLAB_TOPIC`: 주제 id (필수, 없으면 skip)
/// - `PERFLAB_STAGES`: `0,1,2`
/// - `PERFLAB_FRAMEWORKS`: `uikit,swiftui`
/// - `PERFLAB_DURATION`, `PERFLAB_WARMUP`: 초 단위
final class BenchmarkUITests: XCTestCase {
    private let resultIdentifier = "perflab.benchmark.result"

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

        for framework in frameworks {
            for stage in stages {
                try XCTContext.runActivity(named: "Stage \(stage) · \(framework)") { _ in
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

                    let element = app.descendants(matching: .any)[resultIdentifier]
                    XCTAssertTrue(element.waitForExistence(timeout: warmUp + duration + 30), "Benchmark result not found")
                    let json = try XCTUnwrap(element.value as? String)

                    let attachment = XCTAttachment(data: Data(json.utf8), uniformTypeIdentifier: "public.json")
                    attachment.name = "perflab_stage\(stage)-\(framework).json"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
