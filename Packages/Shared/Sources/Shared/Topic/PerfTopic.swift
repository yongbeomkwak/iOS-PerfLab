import SwiftUI
import UIKit

/// 하나의 실험 주제. 각 주제 모듈은 이 프로토콜을 따르는 타입 하나를 공개한다.
///
/// 앱 셸은 주제의 구체 타입을 모르고 이 프로토콜만 안다. `TopicCatalog`가 주제 목록을 `[any PerfTopic]`으로 모아
/// 넘기면, 셸은 Stage와 프레임워크를 고른 뒤 화면을 만들어 달라고 요청한다.
/// - `any PerfTopic`: 서로 다른 구체 타입을 한 배열에 담기 위한 존재 타입(existential). 호출은 동적 디스패치로 이뤄진다.
/// - `AnyView`: 반환 타입이 Stage마다 다른 SwiftUI 뷰를 하나의 타입으로 감싸는 타입 지우개(type eraser).
@MainActor
public protocol PerfTopic {
    var metadata: TopicMetadata { get }

    func makeSwiftUIView(stage: Stage, context: TopicContext) -> AnyView
    func makeUIViewController(stage: Stage, context: TopicContext) -> UIViewController
}

/// Stage 구현에 전달되는 실행 환경.
///
/// Stage는 이 값만 보고 "자동 측정 중인가", "지표를 어디에 기록하나"를 안다. Shared의 다른 타입에 직접 의존하지 않게 하는 창구다.
@MainActor
public struct TopicContext {
    public enum Mode: Sendable {
        /// 사용자가 직접 조작하는 모드.
        case interactive
        /// 자동 측정 모드. Stage 구현은 사용자 입력 없이 시나리오를 스스로 재생해야 한다.
        case benchmark
    }

    public let mode: Mode
    /// 주제별 커스텀 지표(예: 파싱 시간)를 측정 결과에 기록한다.
    public let metrics: CustomMetricRecorder

    private let nextFrame: (@escaping @MainActor (CFTimeInterval) -> Void) -> Void

    public var isBenchmark: Bool { mode == .benchmark }

    /// `nextFrame`는 `PerfMonitor.afterNextFrame(_:)`을 넘긴다. 테스트처럼 화면이 없으면 기본값(아무것도 하지 않음)을 쓴다.
    public init(
        mode: Mode,
        metrics: CustomMetricRecorder,
        nextFrame: @escaping (@escaping @MainActor (CFTimeInterval) -> Void) -> Void = { _ in }
    ) {
        self.mode = mode
        self.metrics = metrics
        self.nextFrame = nextFrame
    }

    /// 다음 프레임이 화면에 나갈 예정 시각(`CACurrentMediaTime` 기준)을 한 번 알려 준다.
    ///
    /// 입력을 처리한 직후 호출하면 "입력 → 화면 반영" 시각을 잴 수 있다. 시각만 전달하므로 측정 비용은 거의 없다.
    public func afterNextFrame(_ body: @escaping @MainActor (CFTimeInterval) -> Void) {
        nextFrame(body)
    }
}
