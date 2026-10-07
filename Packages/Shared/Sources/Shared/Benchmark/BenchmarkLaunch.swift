import Foundation

/// UI 테스트가 launch argument로 전달한 자동 측정 설정.
///
/// `-PerfLabTopic 01-slug -PerfLabStage 0 -PerfLabFramework uikit -PerfLabDuration 10`
public struct BenchmarkLaunch: Sendable {
    public static let resultIdentifier = "perflab.benchmark.result"

    public let topicID: String
    public let stage: Stage
    public let framework: UIFramework
    /// 화면 진입 후 측정 시작 전까지 대기하는 시간.
    public let warmUpSeconds: Double
    public let durationSeconds: Double

    public static var current: BenchmarkLaunch? {
        let defaults = UserDefaults.standard
        guard
            let topicID = defaults.string(forKey: "PerfLabTopic"),
            let stage = Stage(rawValue: defaults.integer(forKey: "PerfLabStage")),
            let framework = defaults.string(forKey: "PerfLabFramework").flatMap(UIFramework.init(rawValue:))
        else { return nil }

        let duration = defaults.double(forKey: "PerfLabDuration")
        let warmUp = defaults.double(forKey: "PerfLabWarmUp")
        return BenchmarkLaunch(
            topicID: topicID,
            stage: stage,
            framework: framework,
            warmUpSeconds: warmUp > 0 ? warmUp : 2,
            durationSeconds: duration > 0 ? duration : 10
        )
    }
}
