import Shared
import Testing
@testable import __MODULE__

struct ScenarioTests {
    @Test func scenarioIsDeterministic() {
        var a = Scenario.makeGenerator()
        var b = Scenario.makeGenerator()
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
    }

    // Stage 간 결과(출력)가 동일한지 검증하는 정합성 테스트를 여기에 추가한다.
}
