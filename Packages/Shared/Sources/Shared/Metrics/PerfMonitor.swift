import Foundation
import Observation
import QuartzCore
import UIKit

/// 일정 주기(기본 0.5초)로 샘플링한 성능 지표. HUD가 `current`로 보여 주고, 녹화 중에는 모아서 요약한다.
///
/// - Codable: 결과 JSON으로 저장할 수 있게 한다.
/// - Sendable: 값만 담은 구조체라 스레드 사이로 넘겨도 안전하다는 표시.
public struct PerfSample: Codable, Hashable, Sendable {
    public let fps: Double
    /// 100% = 코어 1개를 완전히 사용.
    public let cpuPercent: Double
    public let memoryMB: Double
    public let threadCount: Int
}

/// CADisplayLink와 시스템 API로 FPS, Hitch, CPU, 메모리, 스레드 수를 실시간 수집한다.
///
/// `TopicContainerView`가 하나 만들어 HUD 표시와 자동 측정 녹화에 쓴다.
/// FPS와 Hitch는 메인 스레드가 display link 콜백을 제때 처리했는지로 판단한다.
/// 렌더 서버(GPU) 단계의 hitch는 잡히지 않으므로 Instruments의 Animation Hitches로 확인한다.
///
/// - @MainActor: display link 콜백과 UI 갱신이 모두 메인 스레드에서 일어나므로, 상태를 메인 스레드에서만 만지게 컴파일러가 강제한다.
/// - @Observable: `current`가 바뀌면 이 값을 읽는 SwiftUI 뷰(HUD)만 다시 그려지게 하는 매크로 (Observation 프레임워크).
@MainActor
@Observable
public final class PerfMonitor {
    /// 가장 최근 샘플.
    public private(set) var current = PerfSample(fps: 0, cpuPercent: 0, memoryMB: 0, threadCount: 0)
    /// 측정 시작 이후 누적 hitch 횟수.
    public private(set) var hitchCount = 0
    /// 화면이 붙은 window의 최대 주사율. `start(in:)` 전에는 60으로 가정한다.
    public private(set) var maximumFPS = 60

    private let sampleInterval: CFTimeInterval
    /// CADisplayLink: 화면이 새로 그려질 때마다(vsync) 메인 런루프에서 호출되는 타이머.
    /// 메인 스레드가 바쁘면 콜백이 늦거나 건너뛰어지므로, 콜백 간격으로 프레임 누락을 알 수 있다.
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var windowStart: CFTimeInterval = 0
    private var windowFrames = 0
    private var windowCPUTime: Double = 0

    private var recording: Recording?
    /// `start(in:)`를 부르고 아직 `stop()`하지 않은 화면 수.
    ///
    /// Stage나 프레임워크를 바꾸면 SwiftUI가 window를 알려 주는 뷰를 새로 만든다. 새 뷰가 먼저 붙고(start) 옛 뷰가 나중에 떨어지므로(stop),
    /// 횟수를 세지 않으면 옛 뷰의 stop이 막 시작된 측정을 멈춰 HUD가 굳는다. 마지막 화면이 떨어질 때만 멈춘다.
    private var activeViews = 0
    /// 다음 display link 콜백에서 한 번 부를 클로저들 (`afterNextFrame(_:)`).
    private var frameWaiters: [@MainActor (CFTimeInterval) -> Void] = []

    public init(sampleInterval: CFTimeInterval = 0.5) {
        self.sampleInterval = sampleInterval
    }

    /// `window`가 속한 화면의 주사율로 측정을 시작한다. 이미 측정 중이면 그대로 이어 간다.
    ///
    /// `stop()`과 짝을 맞춰 부른다.
    public func start(in window: UIWindow) {
        activeViews += 1
        maximumFPS = window.windowScene?.screen.maximumFramesPerSecond ?? maximumFPS
        guard displayLink == nil else { return }
        let link = CADisplayLink(
            target: DisplayLinkProxy { [weak self] link in self?.tick(link) },
            selector: #selector(DisplayLinkProxy.tick(_:))
        )
        // 콘텐츠가 멈춰 있어도 최대 주사율로 콜백을 받아야 프레임 누락을 판단할 수 있다.
        // ProMotion 기기는 화면 변화가 없으면 주사율을 낮추는데, preferredFrameRateRange로 최대 주사율을 요청한다.
        let maximum = Float(maximumFPS)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: maximum, maximum: maximum, preferred: maximum)
        // .common 모드: 스크롤 중(tracking 모드)에도 콜백을 받는다. .default로 등록하면 스크롤하는 동안 멈춘다.
        link.add(to: .main, forMode: .common)
        displayLink = link
        reset()
    }

    /// `start(in:)`를 부른 화면이 모두 떨어지면 측정을 멈춘다.
    public func stop() {
        activeViews = max(activeViews - 1, 0)
        guard activeViews == 0 else { return }
        displayLink?.invalidate()
        displayLink = nil
        frameWaiters = []
    }

    /// 다음 프레임이 화면에 나갈 예정 시각(`CACurrentMediaTime` 기준)을 한 번 알려 준다.
    ///
    /// 메인 스레드 작업 직후에 등록하면, 그 작업과 화면 반영(CA 커밋)이 끝난 뒤의 첫 콜백에서 불린다.
    /// "입력 → 화면 반영" 지연을 잴 때 쓴다. 렌더 서버(GPU) 단계가 밀린 경우는 포함되지 않는다.
    public func afterNextFrame(_ body: @escaping @MainActor (CFTimeInterval) -> Void) {
        guard displayLink != nil else { return }
        frameWaiters.append(body)
    }

    /// Stage나 프레임워크를 바꿀 때 누적 값을 초기화한다.
    public func reset() {
        lastTimestamp = nil
        windowFrames = 0
        windowStart = CACurrentMediaTime()
        windowCPUTime = SystemMetrics.cpuTime()
        hitchCount = 0
    }

    // MARK: - Recording

    public func startRecording() {
        reset()
        recording = Recording(startTime: CACurrentMediaTime())
    }

    /// 녹화를 종료하고 요약을 반환한다.
    public func stopRecording() -> BenchmarkMetrics? {
        guard let recording else { return nil }
        self.recording = nil
        return recording.summarize(endTime: CACurrentMediaTime())
    }

    // MARK: - Private

    private func tick(_ link: CADisplayLink) {
        // timestamp: 이번 프레임이 시작된 시각, targetTimestamp: 다음 프레임이 화면에 나갈 예정 시각.
        // 둘의 차이가 이 기기의 한 프레임 길이다 (120Hz면 약 8.3ms).
        if let lastTimestamp {
            let frameDuration = link.timestamp - lastTimestamp
            let expected = link.targetTimestamp - link.timestamp
            // 기대 프레임 시간의 1.5배를 넘기면 한 프레임 이상 밀린 것으로 본다.
            if expected > 0, frameDuration > expected * 1.5 {
                hitchCount += 1
                recording?.addHitch(duration: frameDuration - expected)
            }
        }
        lastTimestamp = link.timestamp
        windowFrames += 1
        if !frameWaiters.isEmpty {
            let waiters = frameWaiters
            frameWaiters = []
            for waiter in waiters { waiter(link.targetTimestamp) }
        }

        let elapsed = link.timestamp - windowStart
        guard elapsed >= sampleInterval else { return }

        let cpuTime = SystemMetrics.cpuTime()
        let sample = PerfSample(
            fps: Double(windowFrames) / elapsed,
            cpuPercent: (cpuTime - windowCPUTime) / elapsed * 100,
            memoryMB: Double(SystemMetrics.memoryFootprint()) / 1_048_576,
            threadCount: SystemMetrics.threadCount()
        )
        current = sample
        recording?.samples.append(sample)
        windowFrames = 0
        windowStart = link.timestamp
        windowCPUTime = cpuTime
    }
}

private extension PerfMonitor {
    /// 자동 측정의 녹화 구간 동안 샘플과 hitch를 모은다. 녹화가 끝나면 `BenchmarkMetrics`로 요약한다.
    struct Recording {
        let startTime: CFTimeInterval
        var samples: [PerfSample] = []
        var hitchCount = 0
        var hitchDuration: CFTimeInterval = 0

        mutating func addHitch(duration: CFTimeInterval) {
            hitchCount += 1
            hitchDuration += duration
        }

        func summarize(endTime: CFTimeInterval) -> BenchmarkMetrics {
            let duration = endTime - startTime
            func average(_ values: [Double]) -> Double {
                values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            }
            return BenchmarkMetrics(
                durationSeconds: duration,
                fpsAverage: average(samples.map(\.fps)),
                fpsMinimum: samples.map(\.fps).min() ?? 0,
                hitchCount: hitchCount,
                hitchTimeRatio: duration > 0 ? hitchDuration * 1000 / duration : 0,
                cpuAverage: average(samples.map(\.cpuPercent)),
                cpuPeak: samples.map(\.cpuPercent).max() ?? 0,
                memoryAverageMB: average(samples.map(\.memoryMB)),
                memoryPeakMB: samples.map(\.memoryMB).max() ?? 0,
                threadPeak: samples.map(\.threadCount).max() ?? 0
            )
        }
    }
}

/// CADisplayLink가 target을 강하게 잡는 것을 피하기 위한 프록시.
///
/// CADisplayLink는 target을 강한 참조로 잡는다. PerfMonitor를 직접 target으로 주면 서로를 붙잡아(순환 참조)
/// 화면을 떠나도 해제되지 않는다. 프록시가 대신 잡히고, 프록시는 클로저 안에서 PerfMonitor를 약하게(weak) 잡는다.
/// - NSObject: `#selector`로 호출되는 Objective-C 메서드(`@objc`)를 가지려면 NSObject를 상속해야 한다.
private final class DisplayLinkProxy: NSObject {
    private let handler: @MainActor (CADisplayLink) -> Void

    init(handler: @escaping @MainActor (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @MainActor @objc func tick(_ link: CADisplayLink) {
        handler(link)
    }
}
