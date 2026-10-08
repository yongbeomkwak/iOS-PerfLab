import Foundation

/// 검색 대상 상품.
///
/// - Identifiable: SwiftUI `List`가 `id`로 행을 구분해, 결과가 바뀔 때 어떤 행이 추가되고 사라졌는지 비교한다.
/// - Sendable: S1부터 백그라운드 Task로 넘겨 검색하기 때문에 필요하다. 상수 값만 담은 struct라 컴파일러가 자동으로 인정한다.
struct Product: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

/// 한 상품이 검색어와 일치한 결과. 모든 Stage가 이 형태로 같은 결과를 내야 한다.
struct SearchMatch: Hashable, Sendable {
    let productID: Int
    /// 이름 안에서 검색어와 일치한 위치. `NSRange`와 바로 바꿀 수 있게 UTF-16 오프셋으로 둔다.
    ///
    /// Swift `String`은 글자(Character) 단위라 정수로 바로 접근할 수 없다. UIKit의 `NSRange`는 UTF-16 코드 단위를 센다.
    /// 영문과 완성형 한글은 한 글자가 UTF-16 하나라 오프셋이 글자 수와 같다.
    let highlights: [Range<Int>]
}

/// Swift 배열 힙 버퍼의 헤더 크기 (64비트: 객체 헤더 16B + 개수·용량 16B).
/// 배열이 많은 구조(행마다, 이름마다 배열)는 이 값이 무시할 수 없어 `searchMemory` 추정에 Stage 공통으로 더한다.
let arrayHeaderBytes = 32
