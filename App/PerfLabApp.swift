import Shared
import SwiftUI
import TopicCatalog

@main
struct PerfLabApp: App {
    var body: some Scene {
        WindowGroup {
            if let benchmark = BenchmarkLaunch.current {
                BenchmarkRootView(benchmark: benchmark)
            } else {
                RootTabView()
            }
        }
    }
}

/// UI 테스트의 자동 측정 진입점. 목록을 거치지 않고 바로 주제 화면을 연다.
private struct BenchmarkRootView: View {
    let benchmark: BenchmarkLaunch

    var body: some View {
        NavigationStack {
            if let topic {
                TopicContainerView(topic: topic, benchmark: benchmark)
            } else {
                ContentUnavailableView(
                    "Unknown Topic",
                    systemImage: "questionmark",
                    description: Text(benchmark.topicID)
                )
            }
        }
    }

    private var topic: (any PerfTopic)? {
        if benchmark.topicID == BaselineTopic.id { return BaselineTopic() }
        return TopicCatalog.topic(id: benchmark.topicID)
    }
}
