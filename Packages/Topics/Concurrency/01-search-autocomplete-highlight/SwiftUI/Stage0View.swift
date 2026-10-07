import Shared
import SwiftUI

// 전략: 입력마다 메인 스레드에서 5만 개 이름을 lowercased() + contains로 거르고,
//   행을 그릴 때 range(of:options:)로 일치 위치를 찾아 강조 문자열을 만든다.
struct Stage0View: View {
    let context: TopicContext
    private let search = Stage0Search(products: Scenario.products)
    @State private var query = ""
    @State private var inputTime: CFTimeInterval = 0
    /// 결과와 함께 바뀌는 검색어. 입력창의 `query`로 강조하면 결과가 바뀌기 전 갱신에서 옛 결과를 새 검색어로 강조하게 된다.
    @State private var appliedQuery = ""
    @State private var results: [Product] = []

    // MARK: - Lifecycle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("상품 검색", text: queryBinding)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Text("\(results.count)건")
                .font(.footnote)
                .foregroundStyle(.secondary)
            // List: 보이는 행만 만드는 지연 목록. results의 id를 이전과 비교해 바뀐 행을 찾는다.
            List(results) { product in
                Text(highlightedName(product.name))
            }
            .listStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: query) { apply(query, inputTime: inputTime) }
        .task {
            if context.isBenchmark { await play() }
        }
    }

    // MARK: - Search

    /// onChange는 입력보다 늦게 실행되므로, 입력 시각은 값이 바뀌는 순간에 잡는다.
    private var queryBinding: Binding<String> {
        Binding(get: { query }, set: { setQuery($0) })
    }

    private func setQuery(_ newValue: String) {
        inputTime = CACurrentMediaTime()
        query = newValue
    }

    private func apply(_ query: String, inputTime: CFTimeInterval) {
        let state = PerfSignpost.signposter.beginInterval("filter")
        let results = context.metrics.measure("filterTime") { search.filter(query) }
        PerfSignpost.signposter.endInterval("filter", state)

        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        self.results = results
        appliedQuery = query
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        // 입력마다 동기로 처리하므로 건너뛰는 결과가 없다.
        context.metrics.record("skippedResults", value: 0, unit: "%")
        context.metrics.record("searchMemory", value: Stage0Search.memory(of: results), unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다. Stage 0은 준비 작업이 없다.
        context.metrics.record("indexBuildTime", value: 0, unit: "ms")
    }

    private func highlightedName(_ name: String) -> AttributedString {
        let state = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", state) }
        // AttributedString: SwiftUI `Text`가 받는 속성 문자열 (iOS 15+). 구간을 자기 인덱스 타입으로 지정한다.
        var text = AttributedString(name)
        for range in Stage0Search.highlights(in: name, query: appliedQuery) {
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
