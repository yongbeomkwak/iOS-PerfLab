import Foundation
import Observation
import QuartzCore
import UIKit

/// 일정 주기로 샘플링한 성능 지표.
public struct PerfSample: Codable, Hashable, Sendable {
    public let fps: Double
    public let cpuPercent: Double
    public let memoryMB: Double
    public let threadCount: Int
}

/// CADisplayLink와 Mach API로 FPS, Hitch, CPU, 메모리, 스레드 수를 실시간 수집한다.
@MainActor
@Observable
public final class PerfMonitor {
    /// 가장 최근 샘플.
    public private(set) var current = PerfSample(fps: 0, cpuPercent: 0, memoryMB: 0, threadCount: 0)
    /// 측정 시작 이후 누적 hitch 횟수.
    public private(set) var hitchCount = 0
    public let maximumFPS = UIScreen.main.maximumFramesPerSecond

    private let sampleInterval: CFTimeInterval
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var windowStart: CFTimeInterval = 0
    private var windowFrames = 0

    private var recording: Recording?

    public init(sampleInterval: CFTimeInterval = 0.5) {
        self.sampleInterval = sampleInterval
    }

    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] link in self?.tick(link) },
                                 selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        reset()
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Stage나 프레임워크를 바꿀 때 누적 값을 초기화한다.
    public func reset() {
        lastTimestamp = nil
        windowFrames = 0
        windowStart = CACurrentMediaTime()
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

        let elapsed = link.timestamp - windowStart
        guard elapsed >= sampleInterval else { return }

        let cpu = SystemMetrics.cpu()
        let sample = PerfSample(
            fps: Double(windowFrames) / elapsed,
            cpuPercent: cpu.usagePercent,
            memoryMB: Double(SystemMetrics.memoryFootprint()) / 1_048_576,
            threadCount: cpu.threadCount
        )
        current = sample
        recording?.samples.append(sample)
        windowFrames = 0
        windowStart = link.timestamp
    }
}

private extension PerfMonitor {
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
            func average(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
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
private final class DisplayLinkProxy: NSObject {
    private let handler: @MainActor (CADisplayLink) -> Void

    init(handler: @escaping @MainActor (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @MainActor @objc func tick(_ link: CADisplayLink) {
        handler(link)
    }
}
