import Foundation
import QuartzCore

/// 메인 런루프가 이번 회차의 일을 마치고 잠들기 직전의 시각을 한 번 알려 준다. `reloadTime`의 끝점이다.
///
/// Core Animation 커밋 관찰자는 `beforeWaiting`에 order 2000000으로 걸려 있다 (macOS 런루프 출력, VERIFICATION 0-14. iOS 값은 출력해 보지 않았다).
/// 관찰자를 가장 늦은 순서로 걸어, 같은 시점의 다른 관찰자(커밋 포함)가 모두 끝난 뒤 시각을 읽는다.
/// UIKit 셀 구성과 SwiftUI 행 갱신이 이 구간에 들어오는 것은 Stage 0에서 임시 출력으로 확인했다 (PLAN.md `reloadTime`).
@MainActor
final class CommitObserver {
    private var observer: CFRunLoopObserver?
    private var waiters: [(CFTimeInterval) -> Void] = []

    init() {
        // CFRunLoopObserver: 런루프가 특정 단계(잠들기 직전 등)에 들어갈 때 불리는 콜백.
        // order: 같은 단계의 관찰자는 이 값이 작은 순서로 불린다. 최댓값으로 걸어 가장 마지막에 불리게 한다.
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeWaiting.rawValue,
            true,
            CFIndex.max
        ) { [weak self] _, _ in
            // invalidate를 놓쳐도 관찰자가 이 객체를 붙잡아 두지 않게 약하게 잡는다.
            // 메인 런루프에 걸었으므로 콜백은 메인 스레드에서 불린다. 아니면 assumeIsolated가 앱을 멈춰 알려 준다.
            MainActor.assumeIsolated { self?.fire() }
        }
        // commonModes: 기본 모드와 common으로 표시된 모드 모두에 건다. 스크롤 중 모드도 여기에 들어 있는 것으로 알려져 있다 (추정).
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    /// 다음 `beforeWaiting` 시각을 한 번 알려 준다.
    func afterCommit(_ body: @escaping (CFTimeInterval) -> Void) {
        waiters.append(body)
    }

    func invalidate() {
        if let observer { CFRunLoopObserverInvalidate(observer) }
        observer = nil
        waiters = []
    }

    private func fire() {
        guard !waiters.isEmpty else { return }
        let now = CACurrentMediaTime()
        let waiters = self.waiters
        self.waiters = []
        for waiter in waiters { waiter(now) }
    }
}
