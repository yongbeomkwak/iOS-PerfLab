/// 고정 seed 기반 난수 생성기 (SplitMix64).
///
/// 모든 Stage가 동일한 입력을 받도록 Scenario의 데이터 생성은 반드시 이 생성기를 사용한다.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
