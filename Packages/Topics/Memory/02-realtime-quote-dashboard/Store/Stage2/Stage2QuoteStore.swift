// 전략: 종목 하나를 객체로 두지 않고 필드마다 따로 연속 배열에 둔다 (Struct of Arrays). 틱마다 id 순번 배열을 다시 채워
//   같은 배열을 제자리에서 정렬하고, 비교할 때는 가격과 전일 종가 배열만 읽는다.
// 변경: S1의 class 객체 5만 개를 없애고 필드별 배열로 바꿨다. 정렬 결과를 새 배열로 만들지 않고 순번 배열을 재사용한다.
final class Stage2QuoteStore: QuoteStore {
    // 종목 id가 모든 필드 배열의 같은 위치다. 필드를 추가하면 배열도 함께 늘려야 한다.
    private let symbols: [String]
    private let names: [String]
    private let sectors: [String]
    private let previousCloses: [Double]
    // opens, highs, lows, volumes는 화면에 쓰지 않는다. S0, S1과 필드 수와 갱신 일을 맞추려고 둔다 (Model.swift `QuoteSeed`).
    private let opens: [Double]
    private var prices: [Double]
    /// 직전 체결 가격. 깜빡임 방향을 정한다.
    private var previousPrices: [Double]
    private var highs: [Double]
    private var lows: [Double]
    private var volumes: [Double]
    /// 마지막으로 가격이 들어온 틱 번호. 0은 아직 들어온 적 없음이다.
    private var updatedTicks: [Int]
    /// 등락률 순서로 줄 세운 종목 id. 틱마다 새로 만들지 않고 이 배열을 다시 채워 정렬한다.
    /// Int32: 5만 개 id를 담기에 충분하고 원소가 4바이트라 정렬이 옮기는 양이 작다. 값 타입이라 참조 카운트가 없다.
    private var order: [Int32]
    private(set) var summary = MarketSummary()
    private var tick = 0

    init(seeds: [QuoteSeed]) {
        symbols = seeds.map(\.symbol)
        names = seeds.map(\.name)
        sectors = seeds.map(\.sector)
        previousCloses = seeds.map(\.previousClose)
        opens = seeds.map(\.open)
        prices = seeds.map(\.price)
        previousPrices = seeds.map(\.price)
        highs = seeds.map(\.high)
        lows = seeds.map(\.low)
        volumes = seeds.map(\.volume)
        updatedTicks = [Int](repeating: 0, count: seeds.count)
        order = (0..<seeds.count).map { Int32($0) }
        rank()
        summarize()
    }

    var count: Int { order.count }
    var rankedIDs: [Int] { order.map { Int($0) } }

    /// 필드 배열 11개와 순번 배열의 버퍼 크기. 문자열 배열은 String 값(16바이트)까지 세고, 글자 저장 공간은 `Scenario.seeds`와 함께 쓰므로 세지 않는다.
    var modelMemoryBytes: Int {
        let strings = symbols.capacity + names.capacity + sectors.capacity
        let doubles =
            previousCloses.capacity + opens.capacity + prices.capacity + previousPrices.capacity
            + highs.capacity + lows.capacity + volumes.capacity
        return strings * MemoryLayout<String>.stride
            + doubles * MemoryLayout<Double>.stride
            + updatedTicks.capacity * MemoryLayout<Int>.stride
            + order.capacity * MemoryLayout<Int32>.stride
    }

    func applyUpdates(_ batch: [QuoteUpdate]) {
        tick += 1
        for update in batch {
            let id = update.id
            previousPrices[id] = prices[id]
            prices[id] = update.price
            highs[id] = max(highs[id], update.price)
            lows[id] = min(lows[id], update.price)
            volumes[id] += update.volumeDelta
            updatedTicks[id] = tick
        }
    }

    func rank() {
        // S0, S1과 같은 조건을 맞추려고 매번 id 순서에서 출발한다. 직전 순위에서 출발하면 거의 정렬된 입력이라 알고리즘 효과가 섞인다.
        for index in order.indices {
            order[index] = Int32(index)
        }
        // 읽기만 하는 두 배열은 지역 상수로 받아 클로저가 이 두 버퍼만 잡게 한다. 배타성 충돌 때문은 아니다(VERIFICATION 2-6).
        // 이 복사가 정렬 시간에 득인지는 재지 않았다.
        let prices = prices
        let previousCloses = previousCloses
        // sort(by:): 배열을 그 자리에서 정렬한다. 정렬 결과를 담을 새 배열은 만들지 않지만, 정렬 내부의 임시 버퍼까지 없는 것은 아니다
        // (VERIFICATION 2-7). 비교는 두 종목의 등락률만 읽는다.
        order.sort { a, b in
            let idA = Int(a)
            let idB = Int(b)
            let rateA = (prices[idA] - previousCloses[idA]) / previousCloses[idA]
            let rateB = (prices[idB] - previousCloses[idB]) / previousCloses[idB]
            return rateA != rateB ? rateA > rateB : a < b
        }
    }

    func summarize() {
        var summary = MarketSummary()
        for id in prices.indices {
            let rate = (prices[id] - previousCloses[id]) / previousCloses[id]
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
        // 필드마다 따로 있는 배열에서 한 행에 필요한 값을 모은다.
        let id = Int(order[rank])
        let price = prices[id]
        let previousPrice = previousPrices[id]
        let move: PriceMove =
            updatedTicks[id] != tick
            ? .none : price > previousPrice ? .up : price < previousPrice ? .down : .none
        return QuoteRow(
            id: id,
            symbol: symbols[id],
            name: names[id],
            sector: sectors[id],
            price: price,
            changeRate: (price - previousCloses[id]) / previousCloses[id],
            move: move
        )
    }
}
