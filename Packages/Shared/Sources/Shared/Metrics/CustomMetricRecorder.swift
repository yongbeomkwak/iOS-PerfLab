import Foundation
import QuartzCore

/// FPS 같은 공통 지표로 표현되지 않는 주제별 지표 (예: 파싱 시간, 디코딩 시간).
public struct CustomMetric: Codable, Hashable, Sendable {
    public let name: String
    public let value: Double
    public let unit: String
}

/// Stage 구현이 주제별 지표를 기록할 때 사용한다. 같은 이름으로 여러 번 기록하면 평균을 낸다.
@MainActor
public final class CustomMetricRecorder {
    private var values: [String: (unit: String, values: [Double])] = [:]
    private var order: [String] = []

    public init() {}

    public func record(_ name: String, value: Double, unit: String) {
        if values[name] == nil { order.append(name) }
        values[name, default: (unit, [])].values.append(value)
    }

    /// 클로저 실행 시간을 ms 단위로 기록하고 결과를 반환한다.
    @discardableResult
    public func measure<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        let start = CACurrentMediaTime()
        let result = try work()
        record(name, value: (CACurrentMediaTime() - start) * 1000, unit: "ms")
        return result
    }

    public func reset() {
        values = [:]
        order = []
    }

    public var snapshot: [CustomMetric] {
        order.compactMap { name in
            guard let entry = values[name], !entry.values.isEmpty else { return nil }
            let average = entry.values.reduce(0, +) / Double(entry.values.count)
            return CustomMetric(name: name, value: average, unit: entry.unit)
        }
    }
}
