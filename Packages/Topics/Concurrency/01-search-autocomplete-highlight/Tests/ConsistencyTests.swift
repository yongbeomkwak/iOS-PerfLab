import Testing

@testable import Topic01SearchAutocompleteHighlight

/// 모든 Stage가 기준 구현과 같은 결과(상품과 일치 위치)를 내는지 확인한다.
struct ConsistencyTests {
    private let products = Scenario.products

    @Test func stage0MatchesReference() async {
        let search = Stage0Search(products: products)
        await replayTypingScript { query in
            search.filter(query).map {
                SearchMatch(productID: $0.id, highlights: Stage0Search.highlights(in: $0.name, query: query))
            }
        }
    }

    @Test func stage1MatchesReference() async throws {
        let search = Stage1Search(products: products)
        try await replayTypingScript { query in
            try await search.search(query).rows.map {
                SearchMatch(productID: $0.product.id, highlights: $0.highlights)
            }
        }
    }

    @Test func stage1StopsWhenCancelled() async {
        let search = Stage1Search(products: products)
        let task = Task { try await search.search("a") }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func referenceFindsEveryOccurrence() {
        let product = Product(id: 0, name: "하하상회 하하 Speaker")
        #expect(Self.highlights(in: product.name, query: "하하") == [0..<2, 5..<7])
        #expect(Self.highlights(in: product.name, query: "SPEAKER") == [8..<15])
    }

    // MARK: - Reference

    /// 입력 스크립트를 순서대로 넣으며 매 단계 결과를 기준 구현과 비교한다.
    /// 이전 검색어의 결과를 다시 쓰는 Stage(증분 검색)도 같은 순서로 검증하기 위해서다.
    private func replayTypingScript(_ search: (String) async throws -> [SearchMatch]) async rethrows {
        var expected: [String: [SearchMatch]] = [:]
        for (step, query) in Scenario.typingScript.enumerated() {
            let reference = expected[query] ?? referenceMatches(query)
            expected[query] = reference
            let matches = try await search(query)
            #expect(matches == reference, "step \(step): \(query)")
        }
    }

    /// 소문자 이름의 UTF-16 배열을 왼쪽부터 훑어 겹치지 않는 일치 위치를 모두 찾는 가장 단순한 구현.
    private func referenceMatches(_ query: String) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        return products.compactMap { product in
            let highlights = Self.highlights(in: product.name, query: query)
            return highlights.isEmpty ? nil : SearchMatch(productID: product.id, highlights: highlights)
        }
    }

    private static func highlights(in name: String, query: String) -> [Range<Int>] {
        let name = Array(name.lowercased().utf16)
        let query = Array(query.lowercased().utf16)
        var ranges: [Range<Int>] = []
        var start = 0
        while start + query.count <= name.count {
            if name[start..<start + query.count].elementsEqual(query) {
                ranges.append(start..<start + query.count)
                start += query.count
            } else {
                start += 1
            }
        }
        return ranges
    }
}
