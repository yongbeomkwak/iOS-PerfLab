/// 종목 하나의 시세. S0의 `Stage0Quote`와 필드와 갱신 규칙이 같고, 타입만 참조 타입이다.
///
/// - final: 상속을 막는다. 하위 클래스가 프로퍼티를 재정의할 수 없어 컴파일러가 동적 디스패치 없이 바로 접근할 수 있다.
///   다만 이 앱의 Release는 전체 모듈 최적화라 internal 클래스는 final이 없어도 그렇게 추론된다 (VERIFICATION 1-1).
///   여기서는 성능보다 "상속하지 않는다"는 의도를 밝히는 역할이고, CONVENTIONS 3절의 기본값이다.
final class Stage1Quote {
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
