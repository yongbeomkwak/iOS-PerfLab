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

    /// 입력 스크립트 순서대로 스택을 쌓고 되돌리며 검색해, 증분 검색과 스택 재사용이 매 단계 기준 구현과 같은지 본다.
    @Test func stage2MatchesReference() async throws {
        let index = await Stage2Index.build(from: products)
        var stack = Stage2ResultStack()
        try await replayTypingScript { query in
            let key = Array(query.lowercased().utf16)
            let output = try await Stage2Search.search(key, plan: stack.plan(for: key), index: index)
            stack.push(query: output.query, positions: output.positions)
            return output.positions.map {
                SearchMatch(productID: products[$0].id, highlights: index.highlights(at: $0, query: key))
            }
        }
    }

    /// 화면은 취소된 검색을 스택에 쌓지 않는다. 중간 검색어를 건너뛰어도 결과가 같아야 한다.
    @Test func stage2SkippingQueriesKeepsResults() async throws {
        let index = await Stage2Index.build(from: products)
        var stack = Stage2ResultStack()
        // "풍" → "선풍" → "선풍기"는 접두사가 아닌 포함 관계로 좁힌다.
        for query in ["보", "보조배", "보", "보조배터리", "보조", "풍", "선풍", "선풍기", "풍"] {
            let key = Array(query.lowercased().utf16)
            let output = try await Stage2Search.search(key, plan: stack.plan(for: key), index: index)
            stack.push(query: output.query, positions: output.positions)
            #expect(output.positions.map { products[$0].id } == referenceMatches(query).map(\.productID), "\(query)")
        }
    }

    @Test func stage2StopsWhenCancelled() async {
        let index = await Stage2Index.build(from: products)
        let task = Task { try await Stage2Search.search(Array("a".utf16), plan: .full, index: index) }
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

    /// 소문자 이름에서 `ranges(of:)`로 겹치지 않는 일치 위치를 모두 찾는 가장 단순한 구현.
    /// Stage 구현과 다른 경로(String.Index → UTF-16 오프셋)로 구해 서로 독립적으로 검증한다.
    private func referenceMatches(_ query: String) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        return products.compactMap { product in
            let highlights = Self.highlights(in: product.name, query: query)
            return highlights.isEmpty ? nil : SearchMatch(productID: product.id, highlights: highlights)
        }
    }

    private static func highlights(in name: String, query: String) -> [Range<Int>] {
        // 시나리오는 소문자로 바꿔도 UTF-16 길이가 같은 글자만 쓴다 (ScenarioTests에서 확인).
        let name = name.lowercased()
        return name.ranges(of: query.lowercased()).map {
            name.utf16.distance(
                from: name.startIndex, to: $0.lowerBound)..<name.utf16.distance(
                    from: name.startIndex, to: $0.upperBound)
        }
    }
}
