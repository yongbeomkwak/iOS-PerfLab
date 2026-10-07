import Foundation
import QuartzCore
import Shared

/// Stage 1 검색. Stage 0과 같은 거르기와 위치 계산을 백그라운드에서 하고, 결과 전체의 일치 위치를 미리 구해 함께 넘긴다.
///
/// - Sendable: 메인 액터 밖(백그라운드)에서 쓰기 때문에 필요하다. 상수 배열만 담은 struct라 자동으로 인정된다.
struct Stage1Search: Sendable {
    /// 목록 한 행. 셀은 미리 계산된 `highlights`로 강조 문자열만 만든다.
    struct Row: Identifiable, Sendable {
        let product: Product
        /// 이름 안의 모든 일치 위치 (UTF-16 오프셋).
        let highlights: [Range<Int>]

        var id: Int { product.id }
    }

    /// 검색 한 번의 결과와, 메인 스레드로 돌아가 기록할 값.
    struct Output: Sendable {
        let rows: [Row]
        /// 거르기 + 위치 계산에 걸린 시간 (ms). 지표 기록은 메인 액터에서만 하므로 값으로 들고 간다.
        let filterTime: Double
        /// 결과 배열 + 미리 계산한 일치 위치의 크기 추정치 (MB). 일치 위치 배열마다 붙는 힙 헤더는 빠진다.
        let memory: Double
    }

    let products: [Product]

    /// 결과를 계산한다. 새 입력에 밀려 Task가 취소되면 `CancellationError`를 던지고 중간에 멈춘다.
    ///
    /// @concurrent: 부른 쪽이 메인 액터여도 이 함수는 메인이 아닌 공용 스레드 풀에서 실행된다.
    /// 메인 스레드는 그동안 입력과 그리기를 계속 처리한다.
    @concurrent
    func search(_ query: String) async throws -> Output {
        let state = PerfSignpost.signposter.beginInterval("filter")
        let start = CACurrentMediaTime()
        let (rows, highlightCount) = try matches(for: query)
        let filterTime = (CACurrentMediaTime() - start) * 1000
        PerfSignpost.signposter.endInterval("filter", state)
        let bytes = rows.count * MemoryLayout<Row>.stride + highlightCount * MemoryLayout<Range<Int>>.stride
        return Output(rows: rows, filterTime: filterTime, memory: Double(bytes) / 1_048_576)
    }

    /// 결과와, 크기 추정에 쓸 일치 위치 개수. 개수는 결과를 만드는 반복문 안에서 함께 센다.
    private func matches(for query: String) throws -> (rows: [Row], highlightCount: Int) {
        guard !query.isEmpty else { return ([], 0) }
        // Task.checkCancellation: 취소는 강제로 멈추는 것이 아니라 표시만 남긴다(협력적 취소).
        // 계산하는 쪽이 이렇게 직접 확인해야 쓸모없어진 검색을 끝까지 돌지 않는다. 확인 자체는 플래그 하나를 읽는 비용이다.
        // filter와 map은 rethrows라 클로저가 던지면 그대로 멈추고 에러를 넘긴다.
        let filtered = try products.filter {
            try Task.checkCancellation()
            return $0.name.lowercased().contains(query.lowercased())
        }
        var highlightCount = 0
        let rows = try filtered.map {
            try Task.checkCancellation()
            let highlights = Self.highlights(in: $0.name, query: query)
            highlightCount += highlights.count
            return Row(product: $0, highlights: highlights)
        }
        return (rows, highlightCount)
    }

    /// Stage 0과 같은 방식으로 이름 안의 모든 일치 위치를 찾는다.
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

}
