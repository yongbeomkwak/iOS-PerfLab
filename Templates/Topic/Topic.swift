import Shared
import SwiftUI
import UIKit

public struct __TYPE__: PerfTopic {
    public let metadata = TopicMetadata.load(from: .module)

    public init() {}

    public func makeSwiftUIView(stage: Stage, context: TopicContext) -> AnyView {
        switch stage {
        case .naive: AnyView(Stage0View(context: context))
        case .optimized: AnyView(Stage1View(context: context))
        case .lowLevel: AnyView(Stage2View(context: context))
        }
    }

    public func makeUIViewController(stage: Stage, context: TopicContext) -> UIViewController {
        switch stage {
        case .naive: Stage0ViewController(context: context)
        case .optimized: Stage1ViewController(context: context)
        case .lowLevel: Stage2ViewController(context: context)
        }
    }
}
