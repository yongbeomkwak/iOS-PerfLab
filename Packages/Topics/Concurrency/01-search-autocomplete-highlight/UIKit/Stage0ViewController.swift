import Shared
import UIKit

// 전략: 입력마다 메인 스레드에서 5만 개 이름을 lowercased() + contains로 거르고,
//   셀을 그릴 때 range(of:options:)로 일치 위치를 찾아 강조 문자열을 만든다.
final class Stage0ViewController: UIViewController {
    private let context: TopicContext
    private let search = Stage0Search(products: Scenario.products)
    private var query = ""
    private var results: [Product] = []
    /// Benchmark 재생 작업. 화면을 떠날 때 취소하려고 들고 있는다.
    /// Task: 비동기 작업 하나. 여기서는 메인 액터에서 만들어져 메인 스레드에서 돈다 (S0는 백그라운드 작업이 없다).
    private var playback: Task<Void, Never>?

    /// UISearchTextField: 돋보기 아이콘과 지우기 버튼이 있는 검색용 UITextField.
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
        countLabel.text = "\(results.count)건"
    }

    // MARK: - Search

    // editingChanged: 사용자가 글자를 입력하거나 지울 때마다 보내는 이벤트. 코드로 text를 바꿀 때는 오지 않는다.
    @objc private func searchTextChanged() {
        apply(searchField.text ?? "", inputTime: CACurrentMediaTime())
    }

    /// `inputTime`은 입력이 들어온 시각이다. `resultLatency`를 모든 Stage에서 같은 시작점으로 재기 위해 호출하는 쪽이 넘긴다.
    private func apply(_ query: String, inputTime: CFTimeInterval) {
        let state = PerfSignpost.signposter.beginInterval("filter")
        let results = context.metrics.measure("filterTime") { search.filter(query) }
        PerfSignpost.signposter.endInterval("filter", state)

        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        self.query = query
        self.results = results
        // reloadData: 모든 행 정보를 버리고 다시 묻는다. 셀은 화면에 보이는 행만 만들어진다.
        tableView.reloadData()
        updateCount()
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        // 입력마다 동기로 처리하므로 건너뛰는 결과가 없다.
        context.metrics.record("skippedResults", value: 0, unit: "%")
        context.metrics.record("searchMemory", value: Stage0Search.memory(of: results), unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다. Stage 0은 준비 작업이 없다.
        context.metrics.record("indexBuildTime", value: 0, unit: "ms")
    }

    private func highlightedName(_ name: String) -> NSAttributedString {
        let state = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", state) }
        // NSAttributedString: 문자열 구간마다 글꼴, 색 같은 속성을 붙인 텍스트. 구간은 NSRange(UTF-16)로 지정한다.
        let text = NSMutableAttributedString(
            string: name,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        let highlight: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).bold,
            .foregroundColor: UIColor.tintColor,
        ]
        for range in Stage0Search.highlights(in: name, query: query) {
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
                self?.apply(query, inputTime: CACurrentMediaTime())
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension Stage0ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        // defaultContentConfiguration: 셀의 기본 텍스트, 이미지 배치를 값(struct)으로 설정하는 방식 (iOS 14+).
        var configuration = cell.defaultContentConfiguration()
        configuration.attributedText = highlightedName(results[indexPath.row].name)
        cell.contentConfiguration = configuration
        return cell
    }
}

extension UIFont {
    fileprivate var bold: UIFont {
        fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}
