import Shared
import UIKit

// 전략: 거르기와 결과 전체의 일치 위치 계산을 백그라운드 Task에서 하고, 새 입력이 오면 이전 Task를 취소해
//   최신 검색어의 결과만 목록에 적용한다. 셀은 계산된 위치로 강조 문자열만 만든다.
// 변경: Stage 0의 메인 스레드 동기 검색과 셀 단위 위치 계산을 백그라운드 Task + 취소로 옮겼다.
final class Stage1ViewController: UIViewController {
    private let context: TopicContext
    private let search = Stage1Search(products: Scenario.products)
    private var rows: [Stage1Search.Row] = []
    /// 진행 중인 검색. 새 입력이 오면 취소하고, 결과를 적용하면 nil로 돌린다. nil이 아니면 아직 적용 전인 검색이 있다는 뜻이다.
    private var searchTask: Task<Void, Never>?
    private var playback: Task<Void, Never>?

    private let searchField = UISearchTextField()
    private let countLabel = UILabel()
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
        if context.isBenchmark { startPlayback() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        playback?.cancel()
        searchTask?.cancel()
    }

    // MARK: - Layout

    private func layout() {
        searchField.placeholder = "상품 검색"
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = .secondaryLabel
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let header = UIStackView(arrangedSubviews: [searchField, countLabel])
        header.axis = .vertical
        header.spacing = 8
        let stack = UIStackView(arrangedSubviews: [header, tableView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateCount()
    }

    private func updateCount() {
        countLabel.text = "\(rows.count)건"
    }

    // MARK: - Search

    @objc private func searchTextChanged() {
        submit(searchField.text ?? "", inputTime: CACurrentMediaTime())
    }

    private func submit(_ query: String, inputTime: CFTimeInterval) {
        if let searchTask {
            // 앞 검색어의 결과는 이제 화면에 나오지 못한다.
            searchTask.cancel()
            context.metrics.record("skippedResults", value: 100, unit: "%")
        }
        // Task { }: 메인 액터에서 만들었으므로 본문은 메인 액터에서 돈다. 무거운 계산은 await한 @concurrent 함수만 백그라운드로 간다.
        searchTask = Task { [weak self, search] in
            guard let output = try? await search.search(query), let self else { return }
            // 계산을 마친 검색의 비용은 적용 여부와 관계없이 남긴다. 버려진 검색을 빼면 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠진다.
            self.context.metrics.record("filterTime", value: output.filterTime, unit: "ms")
            // await에서 돌아온 뒤에는 메인 액터다. 취소(submit)도 메인 액터에서만 일어나므로,
            // 여기서 취소되지 않았다면 이 결과가 최신 검색어의 결과다. 늦게 끝난 옛 결과가 새 결과를 덮지 않는다.
            guard !Task.isCancelled else { return }
            self.apply(output, inputTime: inputTime)
        }
    }

    private func apply(_ output: Stage1Search.Output, inputTime: CFTimeInterval) {
        searchTask = nil
        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        rows = output.rows
        tableView.reloadData()
        updateCount()
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        // 적용된 결과만 평균하므로 건너뛴 검색어의 지연은 빠진다. skippedResults와 함께 읽는다.
        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        context.metrics.record("skippedResults", value: 0, unit: "%")
        context.metrics.record("searchMemory", value: output.memory, unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다. Stage 1은 준비 작업이 없다.
        context.metrics.record("indexBuildTime", value: 0, unit: "ms")
    }

    private func highlightedName(_ row: Stage1Search.Row) -> NSAttributedString {
        let state = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", state) }
        let text = NSMutableAttributedString(
            string: row.product.name,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        let highlight: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).bold,
            .foregroundColor: UIColor.tintColor,
        ]
        for range in row.highlights {
            text.addAttributes(highlight, range: NSRange(range))
        }
        return text
    }

    // MARK: - Benchmark

    private func startPlayback() {
        playback = Task { [weak self] in
            guard let context = self?.context else { return }
            await TypingPlayer.play(context: context) { query in
                self?.searchField.text = query
                self?.submit(query, inputTime: CACurrentMediaTime())
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension Stage1ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.attributedText = highlightedName(rows[indexPath.row])
        cell.contentConfiguration = configuration
        return cell
    }
}

extension UIFont {
    fileprivate var bold: UIFont {
        fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}
