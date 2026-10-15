/// Stage마다 다른 시세 모델이 화면과 `TickPlayer`에 내놓는 공통 창구.
///
/// 틱 하나를 반영, 정렬, 집계 세 단계로 나눠 부르게 해서 단계마다 시간을 따로 잰다 (`updateTime`, `sortTime`, `summaryTime`).
/// 구현은 Stage마다 따로 두고 공유하지 않는다. 공유하는 것은 이 약속뿐이다.
/// - AnyObject: 화면과 `TickPlayer`가 같은 모델을 함께 고쳐야 해서 참조 타입으로 묶는다. 모든 Stage가 모델 그릇은 class로 쓰고,
///   Stage마다 다른 것은 그 안에 종목을 담는 방식이다.
protocol QuoteStore: AnyObject {
    /// 정렬된 행 수. 항상 `Scenario.quoteCount`다.
    var count: Int { get }
    var summary: MarketSummary { get }
    /// 순위대로 늘어놓은 종목 id. 정합성 테스트가 쓴다.
    var rankedIDs: [Int] { get }
    /// 시세를 담으려고 들고 있는 구조의 크기 추정치 (PLAN.md `modelMemory` 계산법).
    var modelMemoryBytes: Int { get }

    /// 틱 하나의 체결 소식을 반영한다. 이번 틱에 바뀐 종목이 `PriceMove`를 갖게 된다.
    func applyUpdates(_ batch: [QuoteUpdate])
    /// 등락률 내림차순, 같으면 id 오름차순으로 줄 세운다.
    func rank()
    /// 상승·하락·보합 수를 센다.
    func summarize()
    /// `rank` 순위(0부터)의 표시용 값.
    func row(at rank: Int) -> QuoteRow
}
