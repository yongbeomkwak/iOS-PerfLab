import Shared
import Testing

@testable import Topic02RealtimeQuoteDashboard

struct ScenarioTests {
    @Test func scenarioIsDeterministic() {
        var a = Scenario.makeGenerator()
        var b = Scenario.makeGenerator()
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
    }

    @Test func seedsAreDeterministic() {
        #expect(Scenario.makeSeeds() == Scenario.seeds)
    }

    @Test func batchesAreDeterministic() {
        #expect(Scenario.makeBatches() == Scenario.batches)
    }

    /// SwiftUI Stage들은 `ForEach`에 리터럴 범위 `0..<50_000`을 쓴다 (Stage0View 주석).
    /// `quoteCount`를 바꾸면 이 테스트가 깨져 뷰의 리터럴도 고치게 한다. 뷰의 리터럴만 바꾸는 경우는 잡지 못한다.
    @Test func listRangeMatchesQuoteCount() {
        #expect(Scenario.quoteCount == 50_000)
    }

    @Test func seedsMatchScenarioScale() {
        #expect(Scenario.seeds.count == Scenario.quoteCount)
        #expect(Scenario.seeds.map(\.id) == Array(0..<Scenario.quoteCount))
        #expect(Set(Scenario.seeds.map(\.symbol)).count == Scenario.quoteCount)
    }

    @Test func seedPricesStayWithinLimitAndRange() {
        for seed in Scenario.seeds {
            let bound = seed.previousClose * Scenario.priceLimit
            for price in [seed.open, seed.price] {
                #expect(abs(price - seed.previousClose) <= bound)
            }
            #expect(seed.low <= min(seed.open, seed.price))
            #expect(seed.high >= max(seed.open, seed.price))
        }
    }

    @Test func eachBatchUpdatesDistinctQuotesWithinLimit() {
        #expect(Scenario.batches.count == Scenario.batchCount)
        for batch in Scenario.batches {
            #expect(batch.count == Scenario.updatesPerTick)
            #expect(Set(batch.map(\.id)).count == batch.count)
            for update in batch {
                let previousClose = Scenario.seeds[update.id].previousClose
                #expect(abs(update.price - previousClose) <= previousClose * Scenario.priceLimit)
                #expect(update.volumeDelta >= 1)
            }
        }
    }

    /// 이름 길이가 섞였는지 확인한다. 15바이트 이하는 String 값 안에, 넘으면 힙에 저장된다 (Scenario.makeSeeds 주석).
    @Test func namesMixInlineAndHeapLengths() {
        let lengths = Scenario.seeds.map(\.name.utf8.count)
        #expect(lengths.contains { $0 <= 15 })
        #expect(lengths.contains { $0 > 15 })
    }
}
