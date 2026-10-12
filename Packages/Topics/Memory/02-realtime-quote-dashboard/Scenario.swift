import Foundation
import Shared

/// 모든 Stage가 공유하는 입력과 조건.
///
/// - Stage 간 비교의 공정성을 위해 데이터는 반드시 여기서 `seed` 기반으로 만든다.
/// - Stage 구현 안에서 별도의 데이터를 만들거나 시나리오 파라미터를 바꾸지 않는다.
enum Scenario {
    static let seed: UInt64 = 20_261_007

    static func makeGenerator() -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: seed)
    }

    // TODO: PLAN.md의 시나리오(데이터 규모, 갱신 주기 등)를 여기에 정의한다.
}
