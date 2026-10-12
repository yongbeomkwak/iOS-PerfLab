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
