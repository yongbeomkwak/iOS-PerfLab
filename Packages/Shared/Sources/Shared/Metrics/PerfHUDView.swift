import SwiftUI

/// 화면 위에 띄우는 실시간 성능 지표.
public struct PerfHUDView: View {
    let monitor: PerfMonitor

    public init(monitor: PerfMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        let sample = monitor.current
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
            row("FPS", String(format: "%.0f / %d", sample.fps, monitor.maximumFPS), warning: sample.fps < Double(monitor.maximumFPS) * 0.9)
            row("Hitch", "\(monitor.hitchCount)", warning: monitor.hitchCount > 0)
            row("CPU", String(format: "%.0f%%", sample.cpuPercent), warning: sample.cpuPercent > 80)
            row("MEM", String(format: "%.1f MB", sample.memoryMB), warning: false)
            row("THR", "\(sample.threadCount)", warning: false)
        }
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
