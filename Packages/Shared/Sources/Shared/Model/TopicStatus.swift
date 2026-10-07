/// 주제 파이프라인 상태. 값은 "마지막으로 완료된 단계"를 뜻한다.
///
/// proposed → planned → stage0 → stage1 → stage2 → measured → summarized → archived
public enum TopicStatus: String, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case proposed
    case planned
    case stage0
    case stage1
    case stage2
    case measured
    case summarized
    case archived

    public var title: String {
        switch self {
        case .proposed: "Proposed"
        case .planned: "Planned"
        case .stage0: "Stage 0"
        case .stage1: "Stage 1"
        case .stage2: "Stage 2"
        case .measured: "Measured"
        case .summarized: "Summarized"
        case .archived: "Archived"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: TopicStatus, rhs: TopicStatus) -> Bool { lhs.order < rhs.order }
}
