import Shared
// @perflab:imports

/// 앱에 노출되는 모든 주제. `scripts/perflab new`가 자동으로 등록한다.
public enum TopicCatalog {
    @MainActor
    public static let all: [any PerfTopic] = [
        // @perflab:entries
    ]

    @MainActor
    public static func topics(in category: TopicCategory) -> [any PerfTopic] {
        all.filter { $0.metadata.category == category }
            .sorted { $0.metadata.number < $1.metadata.number }
    }

    @MainActor
    public static func topic(id: String) -> (any PerfTopic)? {
        all.first { $0.metadata.id == id }
    }
}
