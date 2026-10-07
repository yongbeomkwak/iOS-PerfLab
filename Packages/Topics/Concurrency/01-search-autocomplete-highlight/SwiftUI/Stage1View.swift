import Shared
import SwiftUI

// 전략: 거르기와 결과 전체의 일치 위치 계산을 백그라운드 Task에서 하고, 새 입력이 오면 이전 Task를 취소해
//   최신 검색어의 결과만 목록에 적용한다. 행은 계산된 위치로 강조 문자열만 만든다.
// 변경: Stage 0의 메인 스레드 동기 검색과 행 단위 위치 계산을 백그라운드 Task + 취소로 옮겼다.
struct Stage1View: View {
    let context: TopicContext
    private let search = Stage1Search(products: Scenario.products)
    @State private var query = ""
    @State private var inputTime: CFTimeInterval = 0
    @State private var rows: [Stage1Search.Row] = []
    /// 진행 중인 검색. `.task(id: query)`도 이전 작업을 자동으로 취소하지만, 화면이 나타날 때 빈 검색어로 한 번 돌고
    /// 밀려난 검색어를 셀 시점이 없어서 UIKit과 같은 방식으로 직접 들고 있는다.
    @State private var searchTask = SearchTaskBox()

    // MARK: - Lifecycle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("상품 검색", text: queryBinding)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Text("\(rows.count)건")
                .font(.footnote)
                .foregroundStyle(.secondary)
            List(rows) { row in
                Text(highlightedName(row))
            }
            .listStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: query) { submit(query, inputTime: inputTime) }
        .task {
            if context.isBenchmark { await play() }
        }
        .onDisappear { searchTask.task?.cancel() }
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
        if let task = searchTask.task {
            task.cancel()
            context.metrics.record("skippedResults", value: 100, unit: "%")
        }
        // View의 메서드는 메인 액터라 Task 본문도 메인 액터에서 돈다. 계산은 @concurrent 함수만 백그라운드로 간다.
        searchTask.task = Task { [search] in
            guard let output = try? await search.search(query) else { return }
            // 계산을 마친 검색의 비용은 적용 여부와 관계없이 남긴다. 버려진 검색을 빼면 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠진다.
            context.metrics.record("filterTime", value: output.filterTime, unit: "ms")
            // 취소는 메인 액터의 submit에서만 일어나므로, 여기서 취소되지 않았다면 최신 검색어의 결과다.
            guard !Task.isCancelled else { return }
            apply(output, inputTime: inputTime)
        }
    }

    private func apply(_ output: Stage1Search.Output, inputTime: CFTimeInterval) {
        searchTask.task = nil
        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        rows = output.rows
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        // 적용된 결과만 평균하므로 건너뛴 검색어의 지연은 빠진다. skippedResults와 함께 읽는다.
        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        context.metrics.record("skippedResults", value: 0, unit: "%")
        context.metrics.record("searchMemory", value: output.memory, unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다. Stage 1은 준비 작업이 없다.
        context.metrics.record("indexBuildTime", value: 0, unit: "ms")
    }

    private func highlightedName(_ row: Stage1Search.Row) -> AttributedString {
        let state = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", state) }
        let name = row.product.name
        var text = AttributedString(name)
        for range in row.highlights {
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

/// 진행 중인 검색 Task를 담는 상자. nil이 아니면 아직 적용 전인 검색이 있다는 뜻이다.
///
/// - class: `@State`에 Task를 바로 두면 입력과 적용마다 상태가 바뀌어 body를 다시 계산할 수 있다.
///   참조 타입 안의 프로퍼티는 SwiftUI가 관찰하지 않으므로(`@Observable` 아님) 바꿔도 화면 갱신이 일어나지 않는다.
///   `@State`는 이 상자 하나를 뷰가 다시 만들어져도 유지하는 역할만 한다.
@MainActor
private final class SearchTaskBox {
    var task: Task<Void, Never>?
}
