/// 검색어별 결과를 쌓아 둔 스택. 아래 항목의 검색어는 항상 위 항목의 검색어에 포함된다 ("보" ⊂ "보조" ⊂ "보조배").
///
/// - 글자를 더하면: 새 검색어를 포함하는 이름은 위 항목의 검색어도 포함하므로, 위 항목의 결과 안에서만 거른다 (증분 검색).
/// - 글자를 지우면: 새 검색어를 포함하지 않는 항목을 꺼내 버린다. 같은 검색어가 남아 있으면 그 결과를 계산 없이 다시 쓴다.
/// - struct: 메인 액터의 화면이 값으로 들고, 검색에 필요한 결과만 꺼내 백그라운드로 넘긴다. 공유하지 않으니 잠금이 필요 없다.
struct Stage2ResultStack {
    /// 이번 검색을 어디서 시작할지.
    enum Plan: Sendable {
        /// 스택에 같은 검색어의 결과가 있다. 계산하지 않는다.
        case reuse([Int])
        /// 이 결과 안에서만 거른다.
        case narrow([Int])
        /// 5만 개 전체를 거른다.
        case full

        var name: String {
            switch self {
            case .reuse: "reuse"
            case .narrow: "narrow"
            case .full: "full"
            }
        }
    }

    private var entries: [(query: [UInt16], positions: [Int])] = []
    /// 스택 크기 추정치 (bytes). 항목마다 배열 두 개(검색어, 결과 위치)의 헤더 + 원소 수 × stride.
    private(set) var bytes = 0

    mutating func plan(for query: [UInt16]) -> Plan {
        // 새 검색어에 포함되지 않는 위 항목은 더는 쓸모가 없다.
        while let top = entries.last, Stage2Index.firstMatch(of: top.query, in: query) == nil {
            entries.removeLast()
            bytes -= Self.bytes(of: top)
        }
        guard let top = entries.last else { return .full }
        return top.query == query ? .reuse(top.positions) : .narrow(top.positions)
    }

    /// 화면에 적용한 결과를 쌓는다.
    ///
    /// 계산을 마친 결과는 적용되지 않았어도 그 검색어의 정답이지만, 스택을 바꾸는 곳을 메인 액터의 적용 한 곳으로 두어
    /// "아래 항목의 검색어 ⊂ 위 항목의 검색어"를 단순하게 지킨다.
    mutating func push(query: [UInt16], positions: [Int]) {
        guard !query.isEmpty, entries.last?.query != query else { return }
        entries.append((query, positions))
        bytes += Self.bytes(of: (query, positions))
    }

    private static func bytes(of entry: (query: [UInt16], positions: [Int])) -> Int {
        2 * arrayHeaderBytes + entry.query.count * MemoryLayout<UInt16>.stride
            + entry.positions.count * MemoryLayout<Int>.stride
    }
}
