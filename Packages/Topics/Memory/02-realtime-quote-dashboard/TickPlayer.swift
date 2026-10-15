import QuartzCore
import Shared

/// `Scenario.batches`를 정해진 시각에 차례로 적용하고, 틱마다 지표를 기록한다. 모든 Stage가 같은 방식으로 재생한다.
@MainActor
enum TickPlayer {
    /// k번째 틱을 `시작 + k × tickInterval`에 적용한다.
    ///
    /// 늦어도 건너뛰지 않는다. 느린 Stage가 틱을 덜 받아 좋아 보이지 않게 하기 위해서다 (PLAN.md 시나리오).
    /// `reload`는 화면 갱신을 요청하는 클로저다. UIKit은 `reloadData()`, SwiftUI는 상태 값 변경이다.
    static func play(store: some QuoteStore, context: TopicContext, reload: () -> Void) async {
        let interval =
            Double(Scenario.tickInterval.components.attoseconds) / 1e18
            + Double(Scenario.tickInterval.components.seconds)
        let commits = CommitObserver()
        defer { commits.invalidate() }
        // CACurrentMediaTime: display link의 timestamp와 같은 시계라서 afterNextFrame이 주는 시각과 바로 뺄 수 있다.
        let start = CACurrentMediaTime()
        var step = 0
        while !Task.isCancelled {
            let deadline = start + interval * Double(step)
            let wait = deadline - CACurrentMediaTime()
            if wait > 0 {
                do {
                    try await Task.sleep(for: .seconds(wait))
                } catch {
                    return
                }
            } else {
                // 이미 늦었으면 기다리지 않고 바로 적용하되, 한 번 양보해 메인 스레드의 다른 작업(화면 갱신 등)이 끼어들 수 있게 한다.
                // Task.yield: 지금 작업을 잠시 내려놓고 같은 액터(메인)의 다른 작업에 차례를 넘긴다.
                await Task.yield()
                // Task.yield는 취소돼도 예외를 던지지 않으므로(Task.sleep과 다르다) 양보하는 동안 취소됐는지 한 번 더 본다.
                if Task.isCancelled { return }
            }
            let metrics = context.metrics
            applyTick(Scenario.batches[step % Scenario.batches.count], to: store, metrics: metrics)
            // 측정을 시작할 때 지표가 초기화되므로 틱마다 다시 남긴다. reloadTime 구간에 섞이지 않게 화면 갱신 요청 전에 남긴다.
            metrics.record("modelMemory", value: Double(store.modelMemoryBytes) / 1_048_576, unit: "MB")
            context.afterNextFrame { presented in
                metrics.record("tickLatency", value: (presented - deadline) * 1000, unit: "ms")
            }
            refresh(reload, metrics: metrics, commits: commits)
            step += 1
        }
    }

    private static func applyTick(_ batch: [QuoteUpdate], to store: some QuoteStore, metrics: CustomMetricRecorder) {
        let signposter = PerfSignpost.signposter
        let tickState = signposter.beginInterval("applyTick")
        let start = CACurrentMediaTime()

        var state = signposter.beginInterval("updateQuotes")
        metrics.measure("updateTime") { store.applyUpdates(batch) }
        signposter.endInterval("updateQuotes", state)

        state = signposter.beginInterval("sortQuotes")
        metrics.measure("sortTime") { store.rank() }
        signposter.endInterval("sortQuotes", state)

        state = signposter.beginInterval("summarize")
        metrics.measure("summaryTime") { store.summarize() }
        signposter.endInterval("summarize", state)

        metrics.record("tickTime", value: (CACurrentMediaTime() - start) * 1000, unit: "ms")
        signposter.endInterval("applyTick", tickState)
    }

    /// 화면 갱신을 요청하고, 이번 런루프 회차가 끝날 때까지를 `reloadTime`으로 잰다.
    private static func refresh(_ reload: () -> Void, metrics: CustomMetricRecorder, commits: CommitObserver) {
        let signposter = PerfSignpost.signposter
        let state = signposter.beginInterval("reloadRows")
        let start = CACurrentMediaTime()
        reload()
        commits.afterCommit { end in
            signposter.endInterval("reloadRows", state)
            metrics.record("reloadTime", value: (end - start) * 1000, unit: "ms")
        }
    }
}
