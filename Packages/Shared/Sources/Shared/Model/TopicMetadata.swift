import Foundation

/// 주제 폴더의 `topic.json`과 1:1로 대응하는 메타데이터.
public struct TopicMetadata: Codable, Hashable, Sendable, Identifiable {
    /// `NN-slug` 형식. 예) `01-image-feed-scroll`
    public let id: String
    public let number: Int
    public let title: String
    public let summary: String
    public let category: TopicCategory
    public let tags: [String]
    public let status: TopicStatus
    public let stages: [Stage]
    public let frameworks: [UIFramework]

    /// 각 주제 모듈에서 `TopicMetadata.load(from: .module)`로 호출한다.
    public static func load(from bundle: Bundle) -> TopicMetadata {
        guard let url = bundle.url(forResource: "topic", withExtension: "json") else {
            fatalError("topic.json not found in \(bundle.bundlePath)")
        }
        do {
            return try JSONDecoder().decode(TopicMetadata.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Failed to decode topic.json: \(error)")
        }
    }
}
