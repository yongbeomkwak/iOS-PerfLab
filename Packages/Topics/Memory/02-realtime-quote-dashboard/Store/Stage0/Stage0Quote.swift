/// 종목 하나의 시세. 필드 12개를 가진 값 타입이다.
///
/// 화면에 쓰지 않는 필드(open, high, low, volume)도 둔다. 실제 시세 모델처럼 필드가 많은 값을 재현하는 것이
/// 이 실험의 조건이다 (PLAN.md 가설 4). S1, S2도 같은 필드를 같은 규칙으로 갱신하도록 구현한다.
/// 이 필드들은 화면에 나오지 않아 정합성 테스트는 비교하지 않는다.
struct Stage0Quote {
    let id: Int
    let symbol: String
    let name: String
    let sector: String
    let previousClose: Double
    let open: Double
    var price: Double
    /// 직전 체결 가격. 깜빡임 방향을 정한다.
    var previousPrice: Double
    var high: Double
    var low: Double
    var volume: Double
    /// 마지막으로 가격이 들어온 틱 번호. 0은 아직 들어온 적 없음이다.
    var updatedTick: Int

    init(seed: QuoteSeed) {
        id = seed.id
        symbol = seed.symbol
        name = seed.name
        sector = seed.sector
        previousClose = seed.previousClose
        open = seed.open
        price = seed.price
        previousPrice = seed.price
        high = seed.high
        low = seed.low
        volume = seed.volume
        updatedTick = 0
    }

    /// 전일 종가 대비 등락률. 저장하지 않고 읽을 때마다 계산한다.
    var changeRate: Double { (price - previousClose) / previousClose }
}
