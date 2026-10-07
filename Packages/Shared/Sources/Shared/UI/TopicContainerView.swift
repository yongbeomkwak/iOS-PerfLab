import SwiftUI
import UIKit

/// 주제 상세 화면. Stage / UI 프레임워크 전환과 성능 HUD를 제공한다.
///
/// `benchmark`가 주어지면 해당 조합을 자동으로 측정하고 결과를 접근성 요소로 노출한다.
public struct TopicContainerView: View {
    private let topic: any PerfTopic
    private let benchmark: BenchmarkLaunch?

    @State private var stage: Stage
    @State private var framework: UIFramework
    @State private var showsHUD: Bool
    @State private var monitor = PerfMonitor()
    @State private var customMetrics = CustomMetricRecorder()
    @State private var benchmarkResult: BenchmarkResult?

    public init(topic: any PerfTopic, benchmark: BenchmarkLaunch? = nil) {
        self.topic = topic
        self.benchmark = benchmark
        let metadata = topic.metadata
        _stage = State(initialValue: benchmark?.stage ?? metadata.stages.first ?? .naive)
        _framework = State(initialValue: benchmark?.framework ?? metadata.frameworks.first ?? .swiftui)
        // HUD 갱신 비용이 측정에 섞이지 않도록 자동 측정 중에는 숨긴다.
        _showsHUD = State(initialValue: benchmark == nil)
    }

    public var body: some View {
        content
            .id(ContentID(stage: stage, framework: framework))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if showsHUD {
                    PerfHUDView(monitor: monitor).padding(8)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let benchmarkResult {
                    Label("Benchmark done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .padding(8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier(BenchmarkLaunch.resultIdentifier)
                        .accessibilityValue(benchmarkResult.jsonString())
                }
            }
            .safeAreaInset(edge: .bottom) {
                if benchmark == nil { controls }
            }
            .navigationTitle(topic.metadata.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(showsHUD ? "Hide HUD" : "Show HUD", systemImage: "gauge.with.dots.needle.33percent") {
                    showsHUD.toggle()
                }
            }
            .background {
                WindowReader { window in
                    if let window { monitor.start(in: window) } else { monitor.stop() }
                }
            }
            .onChange(of: ContentID(stage: stage, framework: framework)) {
                monitor.reset()
                customMetrics.reset()
            }
            .task { await runBenchmarkIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        let context = TopicContext(mode: benchmark == nil ? .interactive : .benchmark, metrics: customMetrics)
        switch framework {
        case .swiftui:
            topic.makeSwiftUIView(stage: stage, context: context)
        case .uikit:
            UIKitHost { topic.makeUIViewController(stage: stage, context: context) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Stage", selection: $stage) {
                ForEach(topic.metadata.stages) { Text($0.title).tag($0) }
            }
            Picker("Framework", selection: $framework) {
                ForEach(topic.metadata.frameworks) { Text($0.title).tag($0) }
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(.bar)
    }

    private func runBenchmarkIfNeeded() async {
        guard let benchmark else { return }
        try? await Task.sleep(for: .seconds(benchmark.warmUpSeconds))
        customMetrics.reset()
        monitor.startRecording()
        try? await Task.sleep(for: .seconds(benchmark.durationSeconds))
        guard let metrics = monitor.stopRecording() else { return }

        let result = BenchmarkResult(
            topicID: benchmark.topicID,
            stage: benchmark.stage,
            framework: benchmark.framework,
            date: .now,
            environment: .current(maximumFPS: monitor.maximumFPS),
            metrics: metrics,
            customMetrics: customMetrics.snapshot
        )
        print("[PerfLab] Benchmark result\n\(result.jsonString())")
        benchmarkResult = result
    }
}

private struct ContentID: Hashable {
    let stage: Stage
    let framework: UIFramework
}

/// 화면이 붙은 `UIWindow`를 전달한다. 화면에서 떨어지면 `nil`을 전달한다.
private struct WindowReader: UIViewRepresentable {
    let onChange: (UIWindow?) -> Void

    func makeUIView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: WindowObservingView, context: Context) {}

    final class WindowObservingView: UIView {
        var onChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onChange?(window)
        }
    }
}

/// UIKit Stage 구현을 SwiftUI 화면에 올리기 위한 래퍼.
struct UIKitHost: UIViewControllerRepresentable {
    let make: () -> UIViewController

    func makeUIViewController(context: Context) -> UIViewController { make() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
