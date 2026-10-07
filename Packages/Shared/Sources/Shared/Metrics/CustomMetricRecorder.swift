import Foundation
import QuartzCore

/// FPS 같은 공통 지표로 표현되지 않는 주제별 지표 (예: 파싱 시간, 디코딩 시간).
public struct CustomMetric: Codable, Hashable, Sendable {
    public let name: String
    public let value: Double
    public let unit: String
}

/// Stage 구현이 주제별 지표를 기록할 때 사용한다. 같은 이름으로 여러 번 기록하면 평균을 낸다.
///
/// `TopicContainerView`가 하나 만들어 `TopicContext.metrics`로 Stage에 넘긴다. 자동 측정이 녹화를 시작할 때 `reset()`된다.
/// - @MainActor: 여러 스레드가 동시에 기록하면 딕셔너리가 깨질 수 있어, 기록은 메인 스레드에서만 하게 한다.
///   백그라운드 작업의 값은 메인 스레드로 돌아와서 기록한다.
/// - class: Stage와 컨테이너가 같은 기록 저장소를 공유해야 하므로 값 타입이 아닌 참조 타입이다.
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
        // CACurrentMediaTime: 기기가 켜진 뒤 흐른 시간(초). 시계 변경에 영향받지 않아 구간 측정에 쓴다.
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
