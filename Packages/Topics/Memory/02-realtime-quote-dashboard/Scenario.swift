import Foundation
import Shared

/// 모든 Stage가 공유하는 입력과 조건.
///
/// - Stage 간 비교의 공정성을 위해 데이터는 반드시 여기서 `seed` 기반으로 만든다.
/// - Stage 구현 안에서 별도의 데이터를 만들거나 시나리오 파라미터를 바꾸지 않는다.
enum Scenario {
    static let seed: UInt64 = 20_261_007

    static let quoteCount = 50_000
    /// 1초에 4번 시세 묶음이 들어온다.
    static let tickInterval: Duration = .milliseconds(250)
    static let updatesPerTick = 5_000
    /// 미리 만들어 두는 틱 묶음 수. 측정 중에는 차례로 반복해서 적용한다.
    static let batchCount = 40
    /// 가격 제한폭. 모든 가격은 전일 종가의 ±30% 안에 있다.
    static let priceLimit = 0.3

    static func makeGenerator() -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: seed)
    }

    // MARK: - Seeds

    /// 모든 Stage가 같은 배열에서 자기 모델을 만든다. 화면이 다시 만들어져도 한 번만 생성되도록 static으로 둔다.
    static let seeds = makeSeeds()

    /// 이름은 `접두어 + 업종어 (+ " 우")`다. 예) "미래반도체", "한빛바이오로직스 우"
    ///
    /// 길이를 섞은 이유: Swift `String`은 UTF-8로 15바이트 이하면 값 안에 바로 담고, 넘으면 힙에 따로 둔다.
    /// 한글은 한 글자에 3바이트라 5글자까지는 값 안에, 6글자부터는 힙에 들어간다. 실제 종목명처럼 두 경우가 섞이게 한다.
    static func makeSeeds() -> [QuoteSeed] {
        var generator = makeGenerator()
        // 단어 목록은 비어 있지 않은 상수라 randomElement가 nil일 수 없다.
        return (0..<quoteCount).map { id in
            var name = prefixes.randomElement(using: &generator)! + industries.randomElement(using: &generator)!
            if Int.random(in: 0..<10, using: &generator) == 0 {
                name += " 우"
            }
            let previousClose = Double(Int.random(in: 1_000...500_000, using: &generator))
            let open = limited(previousClose * (1 + Double.random(in: -0.05...0.05, using: &generator)), previousClose)
            let price = limited(previousClose * (1 + Double.random(in: -0.1...0.1, using: &generator)), previousClose)
            return QuoteSeed(
                id: id,
                symbol: String(format: "%06d", id),
                name: name,
                sector: sectors.randomElement(using: &generator)!,
                previousClose: previousClose,
                open: open,
                price: price,
                high: max(open, price),
                low: min(open, price),
                volume: Double(Int.random(in: 0...1_000_000, using: &generator))
            )
        }
    }

    private static let prefixes = [
        "한빛", "미래", "대한", "동방", "새솔", "누리", "하나로", "청운", "금강", "태평양", "온새미", "가온",
    ]
    private static let industries = [
        "전자", "화학", "제약", "바이오로직스", "반도체", "에너지솔루션", "금융지주", "건설", "중공업",
        "엔터테인먼트", "식품", "통신",
    ]
    private static let sectors = ["반도체", "2차전지", "바이오", "금융", "건설", "화학", "IT", "자동차", "엔터", "식품"]

    // MARK: - Ticks

    /// Benchmark와 Interactive 모드 모두 `tickInterval`마다 다음 묶음을 적용한다. 끝나면 처음부터 반복한다.
    static let batches = makeBatches()

    /// 묶음마다 서로 다른 종목 `updatesPerTick`개의 새 가격과 거래량 증가분이다.
    ///
    /// 새 가격은 직전 가격이 아니라 전일 종가 기준으로 정한다. 그래서 묶음을 반복해도 가격이 한쪽으로 흘러가지 않는다.
    static func makeBatches() -> [[QuoteUpdate]] {
        var generator = makeGenerator()
        let ids = Array(0..<quoteCount)
        return (0..<batchCount).map { _ in
            ids.shuffled(using: &generator).prefix(updatesPerTick).map { id in
                let previousClose = seeds[id].previousClose
                return QuoteUpdate(
                    id: id,
                    price: limited(
                        previousClose * (1 + Double.random(in: -priceLimit...priceLimit, using: &generator)),
                        previousClose
                    ),
                    volumeDelta: Double(Int.random(in: 1...1_000, using: &generator))
                )
            }
        }
    }

    /// 원 단위로 반올림하고 가격 제한폭 안으로 자른다.
    private static func limited(_ price: Double, _ previousClose: Double) -> Double {
        let bound = previousClose * priceLimit
        return min(max(price.rounded(), (previousClose - bound).rounded(.up)), (previousClose + bound).rounded(.down))
    }
}
