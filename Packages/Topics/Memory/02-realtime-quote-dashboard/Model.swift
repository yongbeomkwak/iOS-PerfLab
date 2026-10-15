/// 화면을 열 때 한 번 받는 종목 하나의 초기 시세.
///
/// 모든 Stage가 이 값으로 자기 모델(struct, class, 필드별 배열)을 만든다. 문자열은 여기서 만든 것을 그대로 넘겨받아
/// Stage마다 문자열 저장 공간이 따로 생기지 않게 한다.
struct QuoteSeed: Equatable {
    let id: Int
    /// 6자리 종목 코드. 예) "005930"
    let symbol: String
    let name: String
    let sector: String
    /// 전일 종가. 등락률의 기준이다.
    let previousClose: Double
    let open: Double
    let price: Double
    let high: Double
    let low: Double
    let volume: Double
}

/// 한 틱에 들어오는 종목 하나의 체결 소식.
///
/// 같은 틱 안에서 같은 종목은 한 번만 나온다.
struct QuoteUpdate: Equatable {
    let id: Int
    let price: Double
    /// 이번 체결로 늘어난 거래량.
    let volumeDelta: Double
}

/// 직전 틱에 가격이 바뀐 방향. 행의 깜빡임 색을 정한다.
enum PriceMove: Equatable {
    case up
    case down
    /// 직전 틱에 바뀌지 않았거나, 바뀌었지만 직전 가격과 같다.
    case none
}

/// 화면이 행 하나를 그리는 데 필요한 값. 모든 Stage의 모델이 이 형태로 같은 값을 내준다.
///
/// 화면은 Stage마다 다른 모델 타입을 모르고 이 값만 안다. 그래서 UI 비용이 모든 Stage에서 같다 (PLAN.md "UI 갱신 방식은 모든 Stage에서 고정한다").
struct QuoteRow: Equatable {
    let id: Int
    let symbol: String
    let name: String
    let sector: String
    let price: Double
    let changeRate: Double
    let move: PriceMove
}

/// 상승·하락·보합 종목 수.
struct MarketSummary: Equatable {
    var rising = 0
    var falling = 0
    var unchanged = 0
}
