import Shared
import UIKit

// PERFLAB: NOT_IMPLEMENTED
final class Stage0ViewController: NotImplementedViewController {
    private let context: TopicContext

    init(context: TopicContext) {
        self.context = context
        super.init(stage: .naive)
    }
}
