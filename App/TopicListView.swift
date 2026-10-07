import Shared
import SwiftUI
import TopicCatalog

struct TopicListView: View {
    let category: TopicCategory

    var body: some View {
        let topics = TopicCatalog.topics(in: category)
        List(topics, id: \.metadata.id) { topic in
            NavigationLink {
                TopicContainerView(topic: topic)
            } label: {
                TopicRow(metadata: topic.metadata)
            }
        }
        .overlay {
            if topics.isEmpty {
                ContentUnavailableView("아직 주제가 없어요", systemImage: category.symbolName)
            }
        }
        .navigationTitle(category.title)
    }
}

private struct TopicRow: View {
    let metadata: TopicMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "#%02d", metadata.number))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(metadata.title)
                    .font(.headline)
            }
            Text(metadata.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(metadata.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.tint)
                Spacer()
                if metadata.status < .archived {
                    Text(metadata.status.title)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
