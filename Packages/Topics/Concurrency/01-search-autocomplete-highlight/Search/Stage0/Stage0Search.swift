import Foundation

/// Stage 0 검색. 입력마다 전체 상품을 처음부터 거르고, 일치 위치는 셀을 그릴 때 구한다.
struct Stage0Search {
    let products: [Product]

    func filter(_ query: String) -> [Product] {
        guard !query.isEmpty else { return [] }
        // lowercased(): 소문자로 바꾼 새 String을 만든다. 15바이트(UTF-8)를 넘으면 힙 메모리를 할당한다 (한글은 글자당 3바이트).
        // contains: Foundation이 제공하는 부분 문자열 검색. 유니코드 글자 경계를 따지며 비교해서 단순 바이트 비교보다 느리다.
        return products.filter { $0.name.lowercased().contains(query.lowercased()) }
    }

    /// 이름 안의 모든 일치 위치를 UTF-16 오프셋으로 돌려준다.
    static func highlights(in name: String, query: String) -> [Range<Int>] {
        // range(of:options:range:): 지정한 범위 안에서 첫 일치 위치를 String.Index 범위로 돌려준다.
        // String.Index는 "몇 번째 글자"가 아니라 문자열 내부 위치라서, UTF-16 오프셋은 처음부터 다시 세어(distance) 얻는다.
        var ranges: [Range<Int>] = []
        var searchStart = name.startIndex
        while let found = name.range(of: query, options: .caseInsensitive, range: searchStart..<name.endIndex) {
            let lower = name.utf16.distance(from: name.utf16.startIndex, to: found.lowerBound)
            let upper = name.utf16.distance(from: name.utf16.startIndex, to: found.upperBound)
            ranges.append(lower..<upper)
            searchStart = found.upperBound
        }
        return ranges
    }

    /// 결과 배열이 차지하는 크기 추정치 (MB). Stage 0은 인덱스나 미리 계산한 위치가 없다.
    static func memory(of results: [Product]) -> Double {
        // MemoryLayout.stride: 배열에서 원소 하나가 차지하는 바이트 수. String은 내부 포인터 크기만 세므로 추정치다.
        Double(results.count * MemoryLayout<Product>.stride) / 1_048_576
    }
}
