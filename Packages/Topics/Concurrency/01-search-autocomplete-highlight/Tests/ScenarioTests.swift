import Shared
import Testing

@testable import Topic01SearchAutocompleteHighlight

struct ScenarioTests {
    @Test func scenarioIsDeterministic() {
        var a = Scenario.makeGenerator()
        var b = Scenario.makeGenerator()
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
        #expect(Scenario.makeProducts() == Scenario.makeProducts())
    }

    @Test func productsHaveExpectedShape() {
        let products = Scenario.makeProducts()
        #expect(products.count == Scenario.productCount)
        #expect(products.map(\.id) == Array(0..<Scenario.productCount))
    }

    /// 모든 Stage가 원본 이름의 UTF-16 오프셋을 소문자 이름에서 그대로 쓸 수 있다는 전제를 지킨다.
    @Test func lowercasingKeepsUTF16Length() {
        for product in Scenario.makeProducts() {
            #expect(product.name.lowercased().utf16.count == product.name.utf16.count)
        }
    }

    @Test func typingScriptNarrowsAndWidens() {
        let script = Scenario.typingScript
        #expect(script.first == "무")
        #expect(script.contains("미니 선풍기"))
        #expect(script.last == "")
        // 한 번에 한 글자씩만 바뀐다.
        for (previous, next) in zip([""] + script, script) {
            #expect(abs(previous.count - next.count) == 1 || (previous.isEmpty && next.isEmpty))
        }
    }

    /// 입력하는 단어가 실제로 결과를 만들어야 부하가 생긴다.
    @Test func everyTypedQueryHasMatches() {
        let names = Scenario.makeProducts().map { $0.name.lowercased() }
        for query in Set(Scenario.typingScript) where !query.isEmpty {
            #expect(names.contains { $0.contains(query.lowercased()) }, "\(query)")
        }
    }
}
