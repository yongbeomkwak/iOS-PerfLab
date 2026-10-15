import SwiftUI

/// SwiftUI Stage들이 함께 쓰는 시세 행. 모든 Stage가 같은 뷰를 써서 UI 비용을 같게 한다.
struct QuoteRowView: View {
    let rank: Int
    let row: QuoteRow
    /// 틱마다 바뀌는 값. 이번 틱에 가격이 바뀐 행만 깜빡임을 다시 시작한다.
    let tick: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(rank + 1)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading) {
                Text(row.name)
                Text("\(row.symbol) · \(row.sector)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(row.price.formatted(.number.precision(.fractionLength(0))))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                Text(row.changeRate.formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always())))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(QuoteStyle.rateColor(row.changeRate))
            }
        }
        .frame(height: QuoteStyle.rowHeight)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(
            // keyframeAnimator: trigger 값이 바뀌면 키프레임을 재생한다 (iOS 17+, Apple 문서). 재생 중에는 content를 매 프레임 다시 부른다.
            // 바뀌지 않은 행은 trigger가 -1에 머물러 재생하지 않는다. 직전 틱에 바뀌었던 행은 -1로 바뀌며 한 번 더 재생되지만 색이 없어 보이지 않는다.
            // UIKit QuoteCell이 바뀐 행만 애니메이션하는 것에 최대한 맞춘 것이다.
            Rectangle()
                .fill(.clear)
                .keyframeAnimator(
                    initialValue: 0.0,
                    trigger: row.move == .none ? -1 : tick,
                    content: { content, opacity in
                        content.background(QuoteStyle.flashColor(row.move)?.opacity(opacity) ?? .clear)
                    },
                    keyframes: Self.flashKeyframes
                )
        )
    }

    /// 배경 불투명도를 1로 올렸다가 `flashDuration` 동안 0으로 내린다.
    ///
    /// nonisolated: body 안의 클로저로 넘겼을 때, 메인 액터 소속으로 추론된 클로저가 메인이 아닌 SwiftUI 스레드에서 불려
    /// 격리 검사에 걸려 앱이 멈췄다 (시뮬레이터 크래시 리포트: `ViewGraphDisplayLink.displayLinkTimer(isAsyncThread:)` →
    /// `updateOutputsAsync` → 이 클로저 → `dispatch_assert_queue` 실패). 이 매개변수는 `@Sendable`이 아니라서 컴파일러가 막지 못한다.
    nonisolated private static func flashKeyframes(_: Double) -> some Keyframes<Double> {
        KeyframeTrack {
            MoveKeyframe(1.0)
            LinearKeyframe(0.0, duration: QuoteStyle.flashDuration)
        }
    }
}

/// UIKit과 SwiftUI 행이 같은 모양을 내도록 크기와 색을 한곳에 둔다.
enum QuoteStyle {
    static let rowHeight: CGFloat = 56
    static let flashDuration = 0.3

    static func rateColor(_ rate: Double) -> Color {
        rate > 0 ? .red : rate < 0 ? .blue : .secondary
    }

    static func flashColor(_ move: PriceMove) -> Color? {
        switch move {
        case .up: .red.opacity(0.25)
        case .down: .blue.opacity(0.25)
        case .none: nil
        }
    }
}
