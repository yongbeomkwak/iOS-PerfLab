import Darwin

// 전략: final class Quote를 id 순서 배열에 담고, 틱마다 객체를 고친 뒤 sorted(by:)로 등락률 순 새 참조 배열을 만든다.
// 변경: S0의 struct Quote를 class로 바꿨다. 배열 칸이 120바이트 값에서 8바이트 참조가 되고, 종목마다 힙 객체가 하나씩 생긴다.
final class Stage1QuoteStore: QuoteStore {
    /// id 순서. `quotes[id]`가 그 종목이다.
    private var quotes: [Stage1Quote]
    /// 등락률 순서. 정렬할 때마다 새 배열로 바뀌지만, 담긴 참조는 `quotes`와 같은 객체를 가리킨다.
    private var ranked: [Stage1Quote] = []
    private(set) var summary = MarketSummary()
    private var tick = 0
    /// 객체 5만 개가 할당기에서 실제로 받은 크기의 합. 객체는 화면이 살아 있는 동안 그대로이므로 한 번만 센다.
    private let objectBytes: Int

    init(seeds: [QuoteSeed]) {
        quotes = seeds.map(Stage1Quote.init)
        // malloc_size: 할당기가 이 주소에 실제로 내준 바이트 수. 요청한 크기를 할당 단위로 올린 값이라 객체 크기보다 클 수 있다.
        // Unmanaged.passUnretained: 참조 카운트를 바꾸지 않고 객체의 주소를 꺼낸다.
        objectBytes = quotes.reduce(0) { $0 + malloc_size(Unmanaged.passUnretained($1).toOpaque()) }
        rank()
        summarize()
    }

    var count: Int { ranked.count }
    var rankedIDs: [Int] { ranked.map(\.id) }

    /// 두 참조 배열의 버퍼 + 객체들. 객체 안의 문자열 저장 공간은 `Scenario.seeds`와 함께 쓰므로 세지 않는다.
    var modelMemoryBytes: Int {
        (quotes.capacity + ranked.capacity) * MemoryLayout<Stage1Quote>.stride + objectBytes
    }

    func applyUpdates(_ batch: [QuoteUpdate]) {
        tick += 1
        for update in batch {
            // 참조 타입이라 꺼낸 객체를 고치면 배열이 가리키는 그 객체가 바뀐다.
            let quote = quotes[update.id]
            quote.previousPrice = quote.price
            quote.price = update.price
            quote.high = max(quote.high, update.price)
            quote.low = min(quote.low, update.price)
            quote.volume += update.volumeDelta
            quote.updatedTick = tick
        }
    }

    func rank() {
        // sorted(by:): 원본은 그대로 두고 정렬한 새 배열을 돌려준다. 새 배열로 복사되는 것은 객체가 아니라 참조다.
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
