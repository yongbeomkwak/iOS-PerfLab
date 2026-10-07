/// 고정 seed 기반 난수 생성기 (SplitMix64).
///
/// 사용처: 각 주제의 `Scenario.makeGenerator()`가 만들고, Scenario의 데이터 생성 함수가
/// `randomElement(using:)`, `shuffled(using:)`, `Int.random(in:using:)`에 넘긴다.
/// 예) #01 `Scenario.makeProducts()`가 상품 이름 5만 개를 만들 때.
///
/// 시스템 기본 생성기(`SystemRandomNumberGenerator`)는 실행마다 값이 달라진다.
/// seed를 고정하면 모든 Stage와 모든 측정 회차가 같은 데이터를 받는다. 공정한 비교의 전제다.
/// SplitMix64는 몇 번의 곱셈과 시프트로 끝나는 빠르고 단순한 알고리즘이다. 보안용 난수로는 쓰지 않는다.
///
/// - RandomNumberGenerator: 표준 라이브러리의 `random(using:)` 계열 API가 받는 프로토콜. `next()`만 구현하면 된다.
/// - Sendable: 테스트나 백그라운드 작업에서 데이터를 만들 때 다른 스레드로 넘길 수 있게 한다.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        // `&+=`, `&*`: 넘치면 앱을 멈추는 대신 비트를 버리고 계속하는 연산자. 해시와 난수 계산은 넘침을 전제로 한다.
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
