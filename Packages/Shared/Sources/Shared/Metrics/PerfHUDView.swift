import SwiftUI

/// 화면 위에 띄우는 실시간 성능 지표. 사용자가 직접 조작할 때만 보이고, 자동 측정 중에는 숨긴다.
///
/// `monitor.current`를 읽기만 하므로 `@Observable` 덕분에 샘플이 바뀔 때(0.5초마다)만 다시 그려진다.
public struct PerfHUDView: View {
    let monitor: PerfMonitor

    public init(monitor: PerfMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        let sample = monitor.current
        // Grid: 행과 열을 맞춰 배치하는 SwiftUI 컨테이너 (iOS 16+). 지표 이름과 값을 표처럼 정렬한다.
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
            row(
                "FPS", String(format: "%.0f / %d", sample.fps, monitor.maximumFPS),
                warning: sample.fps < Double(monitor.maximumFPS) * 0.9)
            row("Hitch", "\(monitor.hitchCount)", warning: monitor.hitchCount > 0)
            row("CPU", String(format: "%.0f%%", sample.cpuPercent), warning: sample.cpuPercent > 80)
            row("MEM", String(format: "%.1f MB", sample.memoryMB), warning: false)
            row("THR", "\(sample.threadCount)", warning: false)
        }
        // monospacedDigit: 숫자 폭을 같게 해서 값이 바뀔 때 글자가 좌우로 흔들리지 않게 한다.
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .allowsHitTesting(false)
        .accessibilityIdentifier("perflab.hud")
    }

    private func row(_ title: String, _ value: String, warning: Bool) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).foregroundStyle(warning ? .red : .primary)
        }
    }
}
