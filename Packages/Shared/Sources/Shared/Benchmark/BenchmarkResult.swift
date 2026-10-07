import Foundation
import UIKit

/// 녹화 구간 동안의 공통 지표 요약.
public struct BenchmarkMetrics: Codable, Hashable, Sendable {
    public let durationSeconds: Double
    public let fpsAverage: Double
    public let fpsMinimum: Double
    public let hitchCount: Int
    /// 초당 hitch 시간 (ms/s). Apple의 Hitch Time Ratio와 같은 개념.
    public let hitchTimeRatio: Double
    public let cpuAverage: Double
    public let cpuPeak: Double
    public let memoryAverageMB: Double
    public let memoryPeakMB: Double
    public let threadPeak: Int
}

/// 측정 1회의 결과. `Topics/.../results/<device>/stage<N>-<framework>.json`으로 저장된다.
public struct BenchmarkResult: Codable, Hashable, Sendable {
    public struct Environment: Codable, Hashable, Sendable {
        public let deviceModel: String
        public let systemVersion: String
        public let isSimulator: Bool
        public let buildConfiguration: String
        public let maximumFPS: Int
    }

    public let topicID: String
    public let stage: Stage
    public let framework: UIFramework
    public let date: Date
    public let environment: Environment
    public let metrics: BenchmarkMetrics
    public let customMetrics: [CustomMetric]

    public func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

extension BenchmarkResult.Environment {
    @MainActor
    static var current: Self {
        #if targetEnvironment(simulator)
        let isSimulator = true
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        let isSimulator = false
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafeBytes(of: systemInfo.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #endif

        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif

        return Self(
            deviceModel: model,
            systemVersion: UIDevice.current.systemVersion,
            isSimulator: isSimulator,
            buildConfiguration: configuration,
            maximumFPS: UIScreen.main.maximumFramesPerSecond
        )
    }
}
