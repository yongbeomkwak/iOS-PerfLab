import Shared
import SwiftUI

// 전략: struct Quote(필드 12개) 배열을 틱마다 제자리에서 고치고, sorted(by:)로 등락률 순 새 배열을 만들고,
//   id 순서 배열을 훑어 집계한 뒤 틱 번호를 바꿔 보이는 행만 다시 그린다.
struct Stage0View: View {
    let context: TopicContext
    /// 화면이 처음 나타날 때 한 번 만들고, 다시 나타나도 유지한다 (UIKit Stage도 화면이 살아 있는 동안 모델을 유지한다).
    /// `@State`의 초깃값 식은 뷰 값이 만들어질 때마다 다시 계산되므로, 5만 개 모델을 거기서 만들지 않는다.
    @State private var store: Stage0QuoteStore?
    /// 틱마다 1씩 는다. 모델은 class라 SwiftUI가 변화를 모르므로, 이 값을 바꿔 다시 그리게 한다.
    @State private var tick = 0

    // MARK: - Lifecycle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let store {
                let summary = store.summary
                Text("상승 \(summary.rising) · 하락 \(summary.falling) · 보합 \(summary.unchanged)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                // List: 보이는 행만 만드는 지연 목록.
                // ForEach(상수 범위): 범위가 바뀌지 않는다고 약속하는 형태라 행은 위치(순위)로 구분된다.
                List {
                    ForEach(0..<Scenario.quoteCount) { rank in
                        QuoteRowView(rank: rank, row: store.row(at: rank), tick: tick)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 8)
        .task {
            let store = self.store ?? Stage0QuoteStore(seeds: Scenario.seeds)
            self.store = store
            await play(store)
        }
    }

    // MARK: - Benchmark

    /// 틱은 Benchmark와 Interactive 모드 모두 재생한다 (PLAN.md 시나리오).
    private func play(_ store: Stage0QuoteStore) async {
        await TickPlayer.play(store: store, context: context) { tick += 1 }
    }
}
