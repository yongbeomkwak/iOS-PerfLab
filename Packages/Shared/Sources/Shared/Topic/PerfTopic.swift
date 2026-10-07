import SwiftUI
import UIKit

/// 하나의 실험 주제. 각 주제 모듈은 이 프로토콜을 따르는 타입 하나를 공개한다.
@MainActor
public protocol PerfTopic {
    var metadata: TopicMetadata { get }

    func makeSwiftUIView(stage: Stage, context: TopicContext) -> AnyView
    func makeUIViewController(stage: Stage, context: TopicContext) -> UIViewController
}

/// Stage 구현에 전달되는 실행 환경.
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
