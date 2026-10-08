import Foundation
import QuartzCore

/// 상품 이름을 검색용으로 한 번만 바꿔 둔 인덱스. Stage 2 화면이 열릴 때 백그라운드에서 만든다.
///
/// S0, S1은 입력마다 5만 개 이름을 `lowercased()`로 새로 만들고 `contains`로 글자 경계를 따지며 비교했다.
/// 이름은 바뀌지 않으므로 소문자 UTF-16 배열을 미리 만들어 두면, 검색은 숫자 배열끼리 비교하는 일만 남는다.
/// 영문과 완성형 한글만 쓰는 시나리오에서는 소문자로 바꿔도 UTF-16 길이가 같아, 이 배열의 위치가 원래 이름의 위치와 같다.
///
/// - Sendable: 백그라운드에서 만들고 검색하며, 결과와 함께 메인 액터로 넘기기 때문에 필요하다.
struct Stage2Index: Sendable {
    /// `Scenario.products`와 같은 순서의 소문자 UTF-16 이름. 검색 결과는 이 배열의 위치(position)로 상품을 가리킨다.
    let names: [[UInt16]]
    /// 인덱스 크기 추정치 (bytes): 이름마다 배열 하나(참조 + 힙 버퍼 헤더) + UTF-16 코드 단위 × 2바이트.
    let bytes: Int
    /// 인덱스를 만드는 데 걸린 시간 (ms).
    let buildTime: Double

    /// @concurrent: 부른 쪽이 메인 액터여도 메인이 아닌 공용 스레드 풀에서 실행된다. 화면은 먼저 그려지고 인덱스는 뒤에서 만들어진다.
    @concurrent
    static func build(from products: [Product]) async -> Stage2Index {
        let start = CACurrentMediaTime()
        var bytes = 0
        let names = products.map { product in
            // String.utf16: 문자열을 UTF-16 코드 단위(UInt16) 순서로 보는 뷰. UIKit의 NSRange와 같은 단위다.
            let name = Array(product.name.lowercased().utf16)
            // 이름마다 배열이 따로라 힙 버퍼가 5만 개다. 버퍼마다 붙는 헤더도 함께 센다.
            bytes += MemoryLayout<[UInt16]>.stride + arrayHeaderBytes + name.count * MemoryLayout<UInt16>.stride
            return name
        }
        return Stage2Index(names: names, bytes: bytes, buildTime: (CACurrentMediaTime() - start) * 1000)
    }

    /// `name`의 `from` 위치부터 `query`가 처음 나오는 위치. 없으면 nil.
    static func firstMatch(of query: [UInt16], in name: [UInt16], from: Int = 0) -> Int? {
        guard !query.isEmpty, name.count >= query.count else { return nil }
        let first = query[0]
        var start = from
        while start <= name.count - query.count {
            // 첫 코드 단위가 다르면 나머지는 비교하지 않는다. 대부분의 위치가 여기서 걸러진다.
            if name[start] == first, name[start..<start + query.count].elementsEqual(query) {
                return start
            }
            start += 1
        }
        return nil
    }

    /// 화면에 보일 행의 일치 위치를 모두 구한다. 결과 전체가 아니라 셀을 만들 때만 부른다 (지연 계산).
    func highlights(at position: Int, query: [UInt16]) -> [Range<Int>] {
        let name = names[position]
        var ranges: [Range<Int>] = []
        var start = 0
        while let found = Self.firstMatch(of: query, in: name, from: start) {
            ranges.append(found..<found + query.count)
            start = found + query.count
        }
        return ranges
    }
}
