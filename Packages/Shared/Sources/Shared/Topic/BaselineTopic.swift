import SwiftUI
import UIKit

/// 빈 화면만 띄우는 기준 측정용 주제. 앱 목록에는 노출하지 않는다.
///
/// 아무 부하가 없을 때의 지표(측정 노이즈 바닥)를 Stage 결과와 같은 조건에서 함께 측정해 비교 기준으로 쓴다.
public struct BaselineTopic: PerfTopic {
    public static let id = "_baseline"

    public let metadata = TopicMetadata(
        id: Self.id,
        number: 0,
        title: "Baseline",
        summary: "부하 없는 빈 화면",
        category: .rendering,
        tags: [],
        status: .archived,
        stages: [.naive],
        frameworks: [.swiftui]
    )

    public init() {}

    public func makeSwiftUIView(stage: Stage, context: TopicContext) -> AnyView {
        AnyView(Color(uiColor: .systemBackground))
    }

    public func makeUIViewController(stage: Stage, context: TopicContext) -> UIViewController {
        UIViewController()
    }
}
