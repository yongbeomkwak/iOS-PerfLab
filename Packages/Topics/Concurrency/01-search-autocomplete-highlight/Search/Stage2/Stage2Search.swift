import QuartzCore
import Shared

/// Stage 2 검색. 인덱스와 스택이 정한 범위 안에서 숫자 배열 비교로 거른다. 일치 위치는 여기서 구하지 않는다.
enum Stage2Search {
    struct Output: Sendable {
        let query: [UInt16]
        /// 일치한 상품의 위치 (`Scenario.products`와 인덱스의 순서).
        let positions: [Int]
        /// 거르기에 걸린 시간 (ms). 스택의 결과를 다시 쓰면 거의 0이다.
        let filterTime: Double
    }

    /// S1과 같이 백그라운드에서 돌고, 새 입력에 밀려 취소되면 `CancellationError`를 던진다.
    @concurrent
    static func search(_ query: [UInt16], plan: Stage2ResultStack.Plan, index: Stage2Index) async throws -> Output {
        // 어떤 경로였는지 signpost에 남겨 Instruments에서 경로별 시간을 본다. filterTime 평균은 세 경로가 섞인 값이다.
        let state = PerfSignpost.signposter.beginInterval("filter", "\(plan.name, privacy: .public)")
        defer { PerfSignpost.signposter.endInterval("filter", state) }
        let start = CACurrentMediaTime()
        let positions: [Int]
        switch plan {
        case .reuse(let cached):
            positions = cached
        case .narrow(let candidates):
            positions = try filter(candidates, query: query, index: index)
        case .full:
            positions = try filter(index.names.indices, query: query, index: index)
        }
        return Output(query: query, positions: positions, filterTime: (CACurrentMediaTime() - start) * 1000)
    }

    private static func filter(
        _ candidates: some Sequence<Int>,
        query: [UInt16],
        index: Stage2Index
    ) throws -> [Int] {
        guard !query.isEmpty else { return [] }
        return try candidates.filter {
            try Task.checkCancellation()
            return Stage2Index.firstMatch(of: query, in: index.names[$0]) != nil
        }
    }
}
