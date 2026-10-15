import Shared
import UIKit

// 전략: 종목 필드를 필드별 연속 배열(Struct of Arrays)에 두고, 틱마다 id 순번 배열을 다시 채워 제자리에서 등락률 순으로 정렬하고,
//   배열을 훑어 집계한 뒤 reloadData()로 보이는 셀만 다시 그린다.
// 변경: S1의 class 객체를 필드별 배열로 바꿨다. 화면 코드는 S1과 같다.
final class Stage2ViewController: UIViewController {
    private let context: TopicContext
    private let store = Stage2QuoteStore(seeds: Scenario.seeds)
    /// 틱 재생 작업. 화면을 떠날 때 취소하려고 들고 있는다.
    /// Task: 비동기 작업 하나. 여기서는 메인 액터에서 만들어져 메인 스레드에서 돈다 (모든 Stage에 백그라운드 작업이 없다).
    private var playback: Task<Void, Never>?

    private let summaryLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(context: TopicContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layout()
    }

    /// SwiftUI `.task`처럼 화면이 나타날 때마다 재생을 시작하고, 사라지면 멈춘다.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPlayback()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        playback?.cancel()
        playback = nil
    }

    // MARK: - Layout

    private func layout() {
        summaryLabel.font = .preferredFont(forTextStyle: .footnote)
        summaryLabel.textColor = .secondaryLabel
        tableView.dataSource = self
        // SwiftUI 행과 같은 고정 높이를 쓴다. 기본값(UITableViewAutomaticDimension)이면 셀 내용으로 높이를 정한다 (UITableView.h).
        tableView.rowHeight = QuoteStyle.rowHeight
        tableView.register(QuoteCell.self, forCellReuseIdentifier: QuoteCell.reuseIdentifier)

        let stack = UIStackView(arrangedSubviews: [summaryLabel, tableView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        summaryLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor).isActive = true
        updateSummary()
    }

    // MARK: - Rendering

    private func reload() {
        // reloadData: 모든 행 정보를 버리고 다시 묻는다. 셀은 화면에 보이는 행만 다시 구성된다.
        tableView.reloadData()
        updateSummary()
    }

    private func updateSummary() {
        let summary = store.summary
        summaryLabel.text = "상승 \(summary.rising) · 하락 \(summary.falling) · 보합 \(summary.unchanged)"
    }

    // MARK: - Benchmark

    /// 틱은 Benchmark와 Interactive 모드 모두 재생한다 (PLAN.md 시나리오).
    private func startPlayback() {
        // 사라지지 않고 다시 나타나는 경우(뒤로 가기 제스처를 하다 취소)에 루프 두 개가 한 모델을 고치지 않게 한다.
        playback?.cancel()
        // 재생은 취소될 때까지 끝나지 않는 루프다. 화면을 강하게 잡으면 취소를 놓쳤을 때 화면이 해제되지 않으므로 약하게 잡는다.
        playback = Task { [weak self] in
            guard let store = self?.store, let context = self?.context else { return }
            await TickPlayer.play(store: store, context: context) { self?.reload() }
        }
    }
}

// MARK: - UITableViewDataSource

extension Stage2ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 등록한 셀 타입이므로 QuoteCell로 바꾸는 데 실패하면 버그다.
        let cell =
            tableView.dequeueReusableCell(withIdentifier: QuoteCell.reuseIdentifier, for: indexPath) as! QuoteCell
        cell.configure(rank: indexPath.row, row: store.row(at: indexPath.row))
        return cell
    }
}
