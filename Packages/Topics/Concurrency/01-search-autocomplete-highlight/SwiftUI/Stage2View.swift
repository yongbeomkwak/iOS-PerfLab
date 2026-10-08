import Shared
import SwiftUI

// 전략: 소문자 UTF-16 인덱스를 미리 만들고, 앞 검색어의 결과 안에서만 거르며(지우면 결과 스택을 되돌림),
//   일치 위치는 보이는 행만 구한다. 백그라운드 Task + 취소는 Stage 1과 같다.
// 변경: Stage 1의 5만 개 lowercased() + contains를 인덱스 + 증분 검색으로, 결과 전체 위치 계산을 행 단위 지연 계산으로 바꿨다.
//   검색어 소문자 변환은 입력당 한 번으로, 결과는 상품 위치(Int) 배열로 바뀌었다.
struct Stage2View: View {
    let context: TopicContext
    private let products = Scenario.products
    @State private var query = ""
    @State private var inputTime: CFTimeInterval = 0
    /// 일치한 상품의 위치 (`products`의 인덱스).
    @State private var positions: [Int] = []
    /// 결과와 함께 바뀌는 소문자 UTF-16 검색어. 행의 일치 위치 계산에 쓴다.
    @State private var appliedQuery: [UInt16] = []
    /// 화면을 다시 그릴 필요가 없는 검색 상태(진행 중인 Task, 인덱스, 결과 스택). Stage 1처럼 참조 타입 상자에 둔다.
    @State private var state = SearchState()

    // MARK: - Lifecycle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("상품 검색", text: queryBinding)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Text("\(positions.count)건")
                .font(.footnote)
                .foregroundStyle(.secondary)
            // 위치 값이 서로 다르므로 그대로 행의 id로 쓴다.
            List(positions, id: \.self) { position in
                Text(highlightedName(at: position))
            }
            .listStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: query) { submit(query, inputTime: inputTime) }
        .task {
            state.buildIndex(from: products)
            if context.isBenchmark { await play() }
        }
        .onDisappear { state.searchTask?.cancel() }
    }

    // MARK: - Search

    private var queryBinding: Binding<String> {
        Binding(get: { query }, set: { setQuery($0) })
    }

    private func setQuery(_ newValue: String) {
        inputTime = CACurrentMediaTime()
        query = newValue
    }

    private func submit(_ query: String, inputTime: CFTimeInterval) {
        guard let indexTask = state.indexTask else { return }
        if let task = state.searchTask {
            task.cancel()
            context.metrics.record("skippedResults", value: 100, unit: "%")
        }
        // 검색어의 소문자 변환은 5만 번이 아니라 입력마다 한 번이다.
        let key = Array(query.lowercased().utf16)
        // 스택 정리와 시작 범위 결정은 메인 액터에서 한다. 스택은 메인 액터만 바꾸므로 잠금 없이 안전하다.
        let plan = state.stack.plan(for: key)
        state.searchTask = Task {
            // Task.value: 작업이 끝날 때까지 기다려 결과를 받는다. 이미 끝났으면 바로 돌려준다.
            let index = await indexTask.value
            guard let output = try? await Stage2Search.search(key, plan: plan, index: index) else { return }
            // 계산을 마친 검색의 비용은 적용 여부와 관계없이 남긴다. 버려진 검색을 빼면 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠진다.
            context.metrics.record("filterTime", value: output.filterTime, unit: "ms")
            // 취소는 메인 액터의 submit에서만 일어나므로, 여기서 취소되지 않았다면 최신 검색어의 결과다.
            guard !Task.isCancelled else { return }
            apply(output, index: index, inputTime: inputTime)
        }
    }

    private func apply(_ output: Stage2Search.Output, index: Stage2Index, inputTime: CFTimeInterval) {
        state.searchTask = nil
        state.stack.push(query: output.query, positions: output.positions)
        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        // 행이 읽는 인덱스는 결과(@State)보다 먼저 넣어, 결과가 바뀌어 다시 그릴 때 함께 보이게 한다.
        state.index = index
        positions = output.positions
        appliedQuery = output.query
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        // 적용된 결과만 평균하므로 건너뛴 검색어의 지연은 빠진다. skippedResults와 함께 읽는다.
        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        context.metrics.record("skippedResults", value: 0, unit: "%")
        // 현재 결과는 스택 맨 위 항목과 같은 배열(copy-on-write로 공유)이라 스택 크기에 이미 들어 있다.
        context.metrics.record("searchMemory", value: Double(index.bytes + state.stack.bytes) / 1_048_576, unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다.
        context.metrics.record("indexBuildTime", value: index.buildTime, unit: "ms")
    }

    private func highlightedName(at position: Int) -> AttributedString {
        let signpost = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", signpost) }
        let name = products[position].name
        var text = AttributedString(name)
        for range in state.index?.highlights(at: position, query: appliedQuery) ?? [] {
            // AttributedString은 자기 인덱스만 받아서, UTF-16 오프셋을 String.Index를 거쳐 한 번 더 바꿔야 한다.
            let lower = String.Index(utf16Offset: range.lowerBound, in: name)
            let upper = String.Index(utf16Offset: range.upperBound, in: name)
            guard let attributedRange = Range(lower..<upper, in: text) else { continue }
            text[attributedRange].font = .body.bold()
            text[attributedRange].foregroundColor = .accentColor
        }
        return text
    }

    // MARK: - Benchmark

    private func play() async {
        await TypingPlayer.play(context: context) { setQuery($0) }
    }
}

/// 화면 갱신과 상관없는 검색 상태를 담는 상자.
///
/// - class: `@State`에 바로 두면 입력과 적용마다 상태가 바뀌어 body를 다시 계산할 수 있다.
///   참조 타입 안의 프로퍼티는 SwiftUI가 관찰하지 않으므로(`@Observable` 아님) 바꿔도 화면 갱신이 일어나지 않는다.
@MainActor
private final class SearchState {
    var searchTask: Task<Void, Never>?
    private(set) var indexTask: Task<Stage2Index, Never>?
    var index: Stage2Index?
    var stack = Stage2ResultStack()

    /// 인덱스 생성을 한 번만 시작한다. `@State`의 초기값은 뷰가 다시 만들어질 때마다 평가되므로 init에서 시작하지 않는다.
    func buildIndex(from products: [Product]) {
        guard indexTask == nil else { return }
        indexTask = Task { await Stage2Index.build(from: products) }
    }
}
