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
///
/// 앱은 이 값을 JSON 문자열로 바꿔 접근성 값(accessibilityValue)에 실어 둔다. UI 테스트가 그 값을 읽어
/// 첨부 파일로 남기고, `scripts/perflab measure`가 첨부를 꺼내 파일로 저장한다.
/// - Codable: JSON으로 바꾸고(Encodable) 다시 읽을(Decodable) 수 있게 한다. 프로퍼티가 모두 Codable이면 컴파일러가 구현을 만들어 준다.
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
    static func current(maximumFPS: Int) -> Self {
        // #if targetEnvironment(simulator): 시뮬레이터용 빌드인지를 컴파일할 때 정한다. 실행 중 분기가 아니다.
        #if targetEnvironment(simulator)
            let isSimulator = true
            let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
            let isSimulator = false
            // uname: 커널의 기기 정보를 읽는 POSIX API. machine 필드에 "iPhone17,1" 같은 모델 식별자가 들어 있다.
            var systemInfo = utsname()
            uname(&systemInfo)
            let model = withUnsafeBytes(of: systemInfo.machine) {
                String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
            }
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
            maximumFPS: maximumFPS
        )
    }
}
