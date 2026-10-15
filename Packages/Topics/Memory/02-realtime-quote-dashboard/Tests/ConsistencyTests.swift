import Testing

@testable import Topic02RealtimeQuoteDashboard

/// 모든 Stage가 기준 구현과 같은 결과(순위, 집계, 표시 값)를 내는지 확인한다.
struct ConsistencyTests {
    @Test func stage0MatchesReference() {
        replayBatches(Stage0QuoteStore(seeds: Scenario.seeds))
    }

    @Test func stage0MemoryCountsBothArrays() {
        let store = Stage0QuoteStore(seeds: Scenario.seeds)
        #expect(store.modelMemoryBytes >= 2 * Scenario.quoteCount * MemoryLayout<Stage0Quote>.stride)
    }

    /// 깜빡임은 이번 틱에 바뀐 종목만, 직전 가격과 비교한 방향으로 나온다.
    @Test func stage0MoveReflectsLatestTickOnly() {
        checkMove(Stage0QuoteStore(seeds: Scenario.seeds))
    }

    @Test func stage1MatchesReference() {
        replayBatches(Stage1QuoteStore(seeds: Scenario.seeds))
    }

    /// 참조 배열 두 개와 객체 5만 개를 센다. 객체는 필드(S0의 값 하나와 같은 120B)에 헤더 16B가 붙는다.
    @Test func stage1MemoryCountsArraysAndObjects() {
        let store = Stage1QuoteStore(seeds: Scenario.seeds)
        let arrays = 2 * Scenario.quoteCount * MemoryLayout<Stage1Quote>.stride
        let objects = Scenario.quoteCount * (MemoryLayout<Stage0Quote>.stride + 16)
        #expect(store.modelMemoryBytes >= arrays + objects)
    }

    @Test func stage1MoveReflectsLatestTickOnly() {
        checkMove(Stage1QuoteStore(seeds: Scenario.seeds))
    }

    @Test func stage2MatchesReference() {
        replayBatches(Stage2QuoteStore(seeds: Scenario.seeds))
    }

    /// 필드 배열 11개와 순번 배열을 센다. 문자열 3개, 숫자 필드 8개(Double 7개 + 틱 번호), 순번 4바이트다.
    @Test func stage2MemoryCountsFieldArrays() {
        let store = Stage2QuoteStore(seeds: Scenario.seeds)
        let perQuote =
            3 * MemoryLayout<String>.stride + 7 * MemoryLayout<Double>.stride
            + MemoryLayout<Int>.stride + MemoryLayout<Int32>.stride
        #expect(store.modelMemoryBytes >= Scenario.quoteCount * perQuote)
    }

    @Test func stage2MoveReflectsLatestTickOnly() {
        checkMove(Stage2QuoteStore(seeds: Scenario.seeds))
    }

    // MARK: - Reference

    /// `Scenario.batches`를 처음부터 순서대로 적용하며 매 틱 기준 구현과 비교한다.
    private func replayBatches(_ store: some QuoteStore) {
        var reference = Reference()
        compare(store, reference, tick: 0)
        for (index, batch) in Scenario.batches.enumerated() {
            store.applyUpdates(batch)
            store.rank()
            store.summarize()
            reference.apply(batch)
            compare(store, reference, tick: index + 1)
        }
    }

    private func compare(_ store: some QuoteStore, _ reference: Reference, tick: Int) {
        let rankedIDs = reference.rankedIDs()
        #expect(store.count == Scenario.quoteCount)
        #expect(store.rankedIDs == rankedIDs, "tick \(tick)")
        #expect(store.summary == reference.summary(), "tick \(tick)")
        // 1등, 중간, 꼴등과 이번 틱에 바뀐 종목 몇 개의 표시 값을 본다.
        let changed = reference.lastBatch.prefix(3).map { id in rankedIDs.firstIndex(of: id)! }
        for rank in [0, Scenario.quoteCount / 2, Scenario.quoteCount - 1] + changed {
            #expect(store.row(at: rank) == reference.row(id: rankedIDs[rank]), "tick \(tick) rank \(rank)")
        }
    }

    /// 깜빡임은 이번 틱에 바뀐 종목만, 직전 가격과 비교한 방향으로 나온다.
    private func checkMove(_ store: some QuoteStore) {
        let id = 7
        let seedPrice = Scenario.seeds[id].price
        store.applyUpdates([QuoteUpdate(id: id, price: seedPrice + 1, volumeDelta: 1)])
        store.rank()
        #expect(row(of: id, in: store).move == .up)
        store.applyUpdates([QuoteUpdate(id: id, price: seedPrice, volumeDelta: 1)])
        store.rank()
        #expect(row(of: id, in: store).move == .down)
        store.applyUpdates([QuoteUpdate(id: id, price: seedPrice, volumeDelta: 1)])
        store.rank()
        #expect(row(of: id, in: store).move == .none)
        store.applyUpdates([])
        store.rank()
        #expect(row(of: id, in: store).move == .none)
    }

    private func row(of id: Int, in store: some QuoteStore) -> QuoteRow {
        store.row(at: store.rankedIDs.firstIndex(of: id)!)
    }

    /// 가장 단순한 기준 구현. 종목마다 필요한 값만 따로 들고, 매번 처음부터 계산한다.
    private struct Reference {
        private var prices = Scenario.seeds.map(\.price)
        private var previousPrices = Scenario.seeds.map(\.price)
        private var changedInLastTick = Set<Int>()
        private(set) var lastBatch: [Int] = []

        mutating func apply(_ batch: [QuoteUpdate]) {
            for update in batch {
                previousPrices[update.id] = prices[update.id]
                prices[update.id] = update.price
            }
            changedInLastTick = Set(batch.map(\.id))
            lastBatch = batch.map(\.id)
        }

        func rate(_ id: Int) -> Double {
            (prices[id] - Scenario.seeds[id].previousClose) / Scenario.seeds[id].previousClose
        }

        func rankedIDs() -> [Int] {
            let rates = (0..<Scenario.quoteCount).map(rate)
            return (0..<Scenario.quoteCount).sorted { a, b in
                rates[a] != rates[b] ? rates[a] > rates[b] : a < b
            }
        }

        func summary() -> MarketSummary {
            var summary = MarketSummary()
            for id in 0..<Scenario.quoteCount {
                let rate = rate(id)
                if rate > 0 {
                    summary.rising += 1
                } else if rate < 0 {
                    summary.falling += 1
                } else {
                    summary.unchanged += 1
                }
            }
            return summary
        }

        func row(id: Int) -> QuoteRow {
            let seed = Scenario.seeds[id]
            var move = PriceMove.none
            if changedInLastTick.contains(id) {
                if prices[id] > previousPrices[id] {
                    move = .up
                } else if prices[id] < previousPrices[id] {
                    move = .down
                }
            }
            return QuoteRow(
                id: id,
                symbol: seed.symbol,
                name: seed.name,
                sector: seed.sector,
                price: prices[id],
                changeRate: rate(id),
                move: move
            )
        }
    }
}
