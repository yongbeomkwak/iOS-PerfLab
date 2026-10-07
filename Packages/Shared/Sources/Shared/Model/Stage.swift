/// 하나의 주제를 비교하기 위한 구현 단계.
///
/// - Int raw value: `topic.json`의 `"stages": [0, 1, 2]`나 launch argument의 숫자와 그대로 대응한다.
/// - CaseIterable: `Stage.allCases`로 모든 단계를 순회할 수 있게 한다 (Picker 등).
/// - Comparable: "Stage 1 이후" 같은 순서 비교를 하기 위해 `<`를 정의한다.
public enum Stage: Int, CaseIterable, Codable, Hashable, Sendable, Identifiable, Comparable {
    /// 성능을 신경 쓰지 않은 가장 직관적인 구현 (기준점).
    case naive = 0
    /// 병목을 알면 바로 떠올리는 관용적인 최적화.
    case optimized = 1
    /// 비용 모델(메모리, 동시성, 자료구조, 렌더링)까지 내려가 다시 설계한 최적화.
    case advanced = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .naive: "Naive"
        case .optimized: "Optimized"
        case .advanced: "Advanced"
        }
    }

    public var shortTitle: String { "S\(rawValue)" }

    public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 같은 Stage를 어떤 UI 프레임워크로 구현했는지.
///
/// String raw value가 `topic.json`, launch argument, 결과 파일 이름(`stage0-uikit`)에 그대로 쓰인다.
public enum UIFramework: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case uikit
    case swiftui

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .uikit: "UIKit"
        case .swiftui: "SwiftUI"
        }
    }
}
