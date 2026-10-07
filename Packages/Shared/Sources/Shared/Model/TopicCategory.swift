/// 하단 탭 바에 노출되는 대주제.
public enum TopicCategory: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case rendering
    case animation
    case concurrency
    case memory
    case dataIO

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rendering: "Rendering"
        case .animation: "Animation"
        case .concurrency: "Concurrency"
        case .memory: "Memory"
        case .dataIO: "Data & I/O"
        }
    }

    /// SF Symbol 이름.
    public var symbolName: String {
        switch self {
        case .rendering: "paintbrush.pointed"
        case .animation: "wand.and.rays"
        case .concurrency: "arrow.triangle.branch"
        case .memory: "memorychip"
        case .dataIO: "externaldrive"
        }
    }
}
