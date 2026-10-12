/// 화면을 열 때 한 번 받는 종목 하나의 초기 시세.
///
/// 모든 Stage가 이 값으로 자기 모델(struct, class, 필드별 배열)을 만든다. 문자열은 여기서 만든 것을 그대로 넘겨받아
/// Stage마다 문자열 저장 공간이 따로 생기지 않게 한다.
/// - Sendable: 테스트에서 Scenario 데이터를 여러 테스트가 함께 읽을 수 있게 한다.
struct QuoteSeed: Equatable, Sendable {
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
struct QuoteUpdate: Equatable, Sendable {
    let id: Int
    let price: Double
    /// 이번 체결로 늘어난 거래량.
    let volumeDelta: Double
}
