import Foundation

/// 검색 대상 상품.
struct Product: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

/// 한 상품이 검색어와 일치한 결과. 모든 Stage가 이 형태로 같은 결과를 내야 한다.
struct SearchMatch: Hashable, Sendable {
    let productID: Int
    /// 이름 안에서 검색어와 일치한 위치. `NSRange`와 바로 바꿀 수 있게 UTF-16 오프셋으로 둔다.
    let highlights: [Range<Int>]
}
