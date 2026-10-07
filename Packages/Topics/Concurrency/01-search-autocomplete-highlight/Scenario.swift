import Foundation
import Shared

/// 모든 Stage가 공유하는 입력과 조건.
///
/// - Stage 간 비교의 공정성을 위해 데이터는 반드시 여기서 `seed` 기반으로 만든다.
/// - Stage 구현 안에서 별도의 데이터를 만들거나 시나리오 파라미터를 바꾸지 않는다.
enum Scenario {
    static let seed: UInt64 = 20_261_007

    static let productCount = 50_000
    /// 1초에 10자를 입력하는 속도.
    static let keystrokeInterval: Duration = .milliseconds(100)

    static func makeGenerator() -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: seed)
    }

    // MARK: - Products

    /// 모든 Stage가 같은 배열을 쓴다. SwiftUI 뷰처럼 자주 다시 만들어지는 곳에서도 한 번만 생성되도록 static으로 둔다.
    static let products = makeProducts()

    /// 이름은 `브랜드 + 수식어 1~3개 + 품목 + (모델명)`이다.
    ///
    /// 영문(ASCII)과 완성형 한글만 쓴다. 이 범위에서는 `lowercased()`가 UTF-16 길이를 바꾸지 않아
    /// 원본과 소문자 이름의 일치 위치가 같다.
    static func makeProducts() -> [Product] {
        var generator = makeGenerator()
        // 단어 목록은 비어 있지 않은 상수라 randomElement가 nil일 수 없다.
        return (0..<productCount).map { id in
            var words = [brands.randomElement(using: &generator)!]
            let descriptorCount = Int.random(in: 1...3, using: &generator)
            words += descriptors.shuffled(using: &generator).prefix(descriptorCount)
            words.append(nouns.randomElement(using: &generator)!)
            if Bool.random(using: &generator) {
                words.append(models.randomElement(using: &generator)!)
            }
            return Product(id: id, name: words.joined(separator: " "))
        }
    }

    private static let brands = [
        "하하상회", "루마", "노바", "모아", "다온", "하늘공방", "Pixel Lab", "Orbit", "Zenith", "Kite",
    ]
    private static let descriptors = [
        "무선", "초경량", "프리미엄", "미니", "대용량", "저소음", "휴대용", "스마트", "방수", "접이식",
        "하하", "고속", "Ultra", "Classic",
    ]
    private static let nouns = [
        "이어폰", "충전기", "보조배터리", "키보드", "마우스", "텀블러", "가습기", "선풍기",
        "백팩", "운동화", "스탠드", "케이블", "스피커", "머그컵", "거치대", "Speaker",
    ]
    private static let models = ["Pro", "Max", "Air", "Mini", "Lite", "Plus", "S", "X", "2", "3"]

    // MARK: - Typing

    /// Benchmark 모드에서 `keystrokeInterval`마다 차례로 입력창에 넣는 검색어. 끝나면 처음부터 반복한다.
    ///
    /// 단어를 한 글자씩 입력한 뒤 한 글자씩 지운다. 글자가 늘 때(결과가 좁아짐)와
    /// 줄 때(결과가 넓어짐)를 모두 만든다. 한글은 자모 조합 과정 없이 완성된 글자 단위로 입력한다.
    static let typingScript: [String] = typedWords.flatMap { word in
        let characters = Array(word)
        let typing = (1...characters.count).map { String(characters.prefix($0)) }
        let deleting = typing.dropLast().reversed()
        return typing + deleting + [""]
    }

    private static let typedWords = ["무선", "보조배터리", "pro", "하하", "SPEAKER", "미니 선풍기", "스마트", "air"]
}
