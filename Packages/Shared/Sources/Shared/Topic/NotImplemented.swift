import SwiftUI
import UIKit

/// 아직 구현되지 않은 Stage 자리를 채우는 SwiftUI 뷰.
public struct NotImplementedView: View {
    let stage: Stage
    let framework: UIFramework

    public init(stage: Stage, framework: UIFramework) {
        self.stage = stage
        self.framework = framework
    }

    public var body: some View {
        ContentUnavailableView(
            "Not Implemented",
            systemImage: "hammer",
            description: Text("\(stage.title) · \(framework.title)")
        )
    }
}

/// 아직 구현되지 않은 Stage 자리를 채우는 UIKit 뷰 컨트롤러.
///
/// - open: 다른 모듈(주제 패키지)의 템플릿이 상속할 수 있게 한다. `public`만으로는 모듈 밖에서 상속할 수 없다.
/// - UIContentUnavailableConfiguration: 빈 화면 안내(아이콘 + 문구)를 시스템 스타일로 보여 주는 구성 (iOS 17+).
open class NotImplementedViewController: UIViewController {
    private let stage: Stage

    public init(stage: Stage) {
        self.stage = stage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "hammer")
        configuration.text = "Not Implemented"
        configuration.secondaryText = "\(stage.title) · UIKit"
        contentUnavailableConfiguration = configuration
    }
}
