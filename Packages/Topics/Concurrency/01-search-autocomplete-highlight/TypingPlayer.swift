import QuartzCore
import Shared

/// Benchmark 모드에서 `Scenario.typingScript`를 정해진 시각에 차례로 입력한다. 모든 Stage가 같은 방식으로 재생한다.
@MainActor
enum TypingPlayer {
    /// k번째 입력을 `시작 + k × keystrokeInterval`에 넣는다.
    ///
    /// 늦어도 건너뛰지 않는다. 느린 Stage가 입력을 덜 받아 좋아 보이지 않게 하기 위해서다 (PLAN.md 시나리오).
    /// `inputDelay`는 예정 시각부터, 입력을 처리한 뒤 첫 프레임이 화면에 나갈 시각까지다 ("글자가 늦게 찍힌다").
    static func play(context: TopicContext, input: (String) -> Void) async {
        let interval =
            Double(Scenario.keystrokeInterval.components.attoseconds) / 1e18
            + Double(Scenario.keystrokeInterval.components.seconds)
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
                // 이미 늦었으면 기다리지 않고 바로 넣되, 한 번 양보해 메인 스레드의 다른 작업이 끼어들 수 있게 한다.
                // Task.yield: 지금 작업을 잠시 내려놓고 같은 액터(메인)의 다른 작업에 차례를 넘긴다.
                await Task.yield()
            }
            input(Scenario.typingScript[step % Scenario.typingScript.count])
            let metrics = context.metrics
            context.afterNextFrame { presented in
                metrics.record("inputDelay", value: (presented - deadline) * 1000, unit: "ms")
            }
            step += 1
        }
    }
}
