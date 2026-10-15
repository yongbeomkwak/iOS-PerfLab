// 전략: struct Quote를 id 순서 배열에 담고, 틱마다 제자리에서 고친 뒤 sorted(by:)로 등락률 순 새 배열을 만든다.
final class Stage0QuoteStore: QuoteStore {
    /// id 순서. `quotes[id]`가 그 종목이다.
    private var quotes: [Stage0Quote]
    /// 등락률 순서. 정렬할 때마다 새 배열로 바뀐다.
    private var ranked: [Stage0Quote] = []
    private(set) var summary = MarketSummary()
    private var tick = 0

    init(seeds: [QuoteSeed]) {
        quotes = seeds.map(Stage0Quote.init)
        rank()
        summarize()
    }

    var count: Int { ranked.count }
    var rankedIDs: [Int] { ranked.map(\.id) }

    /// 두 배열의 버퍼 크기. 원소 안의 문자열 저장 공간은 `Scenario.seeds`와 함께 쓰므로 세지 않는다.
    var modelMemoryBytes: Int {
        (quotes.capacity + ranked.capacity) * MemoryLayout<Stage0Quote>.stride
    }

    func applyUpdates(_ batch: [QuoteUpdate]) {
        tick += 1
        for update in batch {
            // 배열 원소의 프로퍼티를 바로 고친다. 이 배열을 다른 곳에서 함께 쓰지 않으면 복사 없이 제자리에서 바뀐다.
            quotes[update.id].previousPrice = quotes[update.id].price
            quotes[update.id].price = update.price
            quotes[update.id].high = max(quotes[update.id].high, update.price)
            quotes[update.id].low = min(quotes[update.id].low, update.price)
            quotes[update.id].volume += update.volumeDelta
            quotes[update.id].updatedTick = tick
        }
    }

    func rank() {
        // sorted(by:): 원본은 그대로 두고 정렬한 새 배열을 돌려준다. 원소(Quote 값)가 새 배열로 복사된다.
        ranked = quotes.sorted { a, b in
            let rateA = a.changeRate
            let rateB = b.changeRate
            return rateA != rateB ? rateA > rateB : a.id < b.id
        }
    }

    func summarize() {
        var summary = MarketSummary()
        for quote in quotes {
            let rate = quote.changeRate
            if rate > 0 {
                summary.rising += 1
            } else if rate < 0 {
                summary.falling += 1
            } else {
                summary.unchanged += 1
            }
        }
        self.summary = summary
    }

    func row(at rank: Int) -> QuoteRow {
        let quote = ranked[rank]
        let move: PriceMove =
            quote.updatedTick != tick
            ? .none : quote.price > quote.previousPrice ? .up : quote.price < quote.previousPrice ? .down : .none
        return QuoteRow(
            id: quote.id,
            symbol: quote.symbol,
            name: quote.name,
            sector: quote.sector,
            price: quote.price,
            changeRate: quote.changeRate,
            move: move
        )
    }
}
