/// 하나의 주제를 비교하기 위한 구현 단계.
public enum Stage: Int, CaseIterable, Codable, Hashable, Sendable, Identifiable, Comparable {
    /// 성능을 신경 쓰지 않은 가장 직관적인 구현 (기준점).
    case naive = 0
    /// 프레임워크 수준의 최적화.
    case optimized = 1
    /// CoreGraphics, CoreAnimation, Metal, GCD 등 저수준 API까지 내려간 최적화.
    case lowLevel = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .naive: "Naive"
        case .optimized: "Optimized"
        case .lowLevel: "Low-level"
        }
    }

    public var shortTitle: String { "S\(rawValue)" }

    public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 같은 Stage를 어떤 UI 프레임워크로 구현했는지.
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
