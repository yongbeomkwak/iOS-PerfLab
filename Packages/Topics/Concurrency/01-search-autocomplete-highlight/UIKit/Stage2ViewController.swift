import Shared
import UIKit

// 전략: 소문자 UTF-16 인덱스를 미리 만들고, 앞 검색어의 결과 안에서만 거르며(지우면 결과 스택을 되돌림),
//   일치 위치는 보이는 셀만 구한다. 백그라운드 Task + 취소는 Stage 1과 같다.
// 변경: Stage 1의 5만 개 lowercased() + contains를 인덱스 + 증분 검색으로, 결과 전체 위치 계산을 셀 단위 지연 계산으로 바꿨다.
//   검색어 소문자 변환은 입력당 한 번으로, 결과는 상품 위치(Int) 배열로 바뀌었다.
final class Stage2ViewController: UIViewController {
    private let context: TopicContext
    private let products = Scenario.products
    /// 인덱스 생성 작업. 화면이 열릴 때 시작하고, 검색은 이 작업의 결과(`value`)를 기다려 받는다.
    private var indexTask: Task<Stage2Index, Never>?
    /// 화면에 적용한 결과를 만든 인덱스. 셀이 일치 위치를 구할 때 쓴다.
    private var index: Stage2Index?
    private var stack = Stage2ResultStack()
    /// 일치한 상품의 위치 (`products`의 인덱스).
    private var positions: [Int] = []
    /// 결과와 함께 바뀌는 소문자 UTF-16 검색어. 셀의 일치 위치 계산에 쓴다.
    private var appliedQuery: [UInt16] = []
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
        let products = products
        // 인덱스 생성은 @concurrent 함수라 메인 스레드 밖에서 돈다. 그동안 화면은 먼저 그려진다.
        indexTask = Task { await Stage2Index.build(from: products) }
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
        countLabel.text = "\(positions.count)건"
    }

    // MARK: - Search

    @objc private func searchTextChanged() {
        submit(searchField.text ?? "", inputTime: CACurrentMediaTime())
    }

    private func submit(_ query: String, inputTime: CFTimeInterval) {
        guard let indexTask else { return }
        if let searchTask {
            searchTask.cancel()
            context.metrics.record("skippedResults", value: 100, unit: "%")
        }
        // 검색어의 소문자 변환은 5만 번이 아니라 입력마다 한 번이다.
        let key = Array(query.lowercased().utf16)
        // 스택 정리와 시작 범위 결정은 메인 액터에서 한다. 스택은 메인 액터만 바꾸므로 잠금 없이 안전하다.
        let plan = stack.plan(for: key)
        searchTask = Task { [weak self] in
            // Task.value: 작업이 끝날 때까지 기다려 결과를 받는다. 이미 끝났으면 바로 돌려준다.
            let index = await indexTask.value
            guard let output = try? await Stage2Search.search(key, plan: plan, index: index), let self else { return }
            // 계산을 마친 검색의 비용은 적용 여부와 관계없이 남긴다. 버려진 검색을 빼면 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠진다.
            self.context.metrics.record("filterTime", value: output.filterTime, unit: "ms")
            // await에서 돌아온 뒤에는 메인 액터다. 취소(submit)도 메인 액터에서만 일어나므로,
            // 여기서 취소되지 않았다면 이 결과가 최신 검색어의 결과다. 늦게 끝난 옛 결과가 새 결과를 덮지 않는다.
            guard !Task.isCancelled else { return }
            self.apply(output, index: index, inputTime: inputTime)
        }
    }

    private func apply(_ output: Stage2Search.Output, index: Stage2Index, inputTime: CFTimeInterval) {
        searchTask = nil
        stack.push(query: output.query, positions: output.positions)
        let applyState = PerfSignpost.signposter.beginInterval("applyResults")
        self.index = index
        positions = output.positions
        appliedQuery = output.query
        tableView.reloadData()
        updateCount()
        PerfSignpost.signposter.endInterval("applyResults", applyState)

        // 적용된 결과만 평균하므로 건너뛴 검색어의 지연은 빠진다. skippedResults와 함께 읽는다.
        context.metrics.record("resultLatency", value: (CACurrentMediaTime() - inputTime) * 1000, unit: "ms")
        context.metrics.record("skippedResults", value: 0, unit: "%")
        // 현재 결과는 스택 맨 위 항목과 같은 배열(copy-on-write로 공유)이라 스택 크기에 이미 들어 있다.
        context.metrics.record("searchMemory", value: Double(index.bytes + stack.bytes) / 1_048_576, unit: "MB")
        // 측정 시작 때 지표가 초기화되므로 준비 비용은 결과를 적용할 때마다 다시 남긴다.
        context.metrics.record("indexBuildTime", value: index.buildTime, unit: "ms")
    }

    private func highlightedName(at position: Int) -> NSAttributedString {
        let state = PerfSignpost.signposter.beginInterval("highlight")
        defer { PerfSignpost.signposter.endInterval("highlight", state) }
        let text = NSMutableAttributedString(
            string: products[position].name,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        let highlight: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).bold,
            .foregroundColor: UIColor.tintColor,
        ]
        // 인덱스의 위치가 원래 이름의 UTF-16 위치와 같아서 NSRange로 바로 쓴다 (String.Index를 거치지 않는다).
        for range in index?.highlights(at: position, query: appliedQuery) ?? [] {
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

extension Stage2ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        positions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.attributedText = highlightedName(at: positions[indexPath.row])
        cell.contentConfiguration = configuration
        return cell
    }
}

extension UIFont {
    fileprivate var bold: UIFont {
        fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}
