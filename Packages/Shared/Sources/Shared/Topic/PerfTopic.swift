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

    public var isBenchmark: Bool { mode == .benchmark }

    public init(mode: Mode, metrics: CustomMetricRecorder) {
        self.mode = mode
        self.metrics = metrics
    }
}
