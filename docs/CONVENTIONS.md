# 코드 컨벤션

PerfLab의 모든 Swift 코드(앱 셸, Shared, 주제)가 따르는 규칙이다.
포맷은 도구가 강제하고, 이 문서는 **도구가 잡지 못하는 것**을 정한다.

## 1. 포맷: swift-format

Xcode에 포함된 `swift-format`(first-party)을 쓴다. 설정은 루트의 [`.swift-format`](../.swift-format)이다.

```bash
scripts/perflab format [경로...]   # 자동 정리 (경로 생략 시 레포 전체)
scripts/perflab lint   [경로...]   # 규칙 검사
```

- 들여쓰기 4칸, 한 줄 120자, 여러 줄 컬렉션은 마지막 원소에도 쉼표를 붙인다.
- import는 알파벳 순서이고, `@testable import`는 빈 줄로 구분한다.
- **Stage를 완료할 때 주제 폴더가 lint를 통과해야 한다.** `scripts/perflab advance`가 검사한다.
- 기본 규칙에서 바꾼 것은 `NoAccessLevelOnExtensionDeclaration` 하나다 (끔). `private extension`을 허용한다.

## 2. 이름

| 대상 | 규칙 | 예 |
|---|---|---|
| 타입, 프로토콜 | UpperCamelCase | `ImageCell`, `FeedItem` |
| 함수, 변수, enum case | lowerCamelCase | `decodeImage()`, `isBenchmark` |
| Stage 파일과 타입 | 템플릿 이름을 그대로 쓴다 | `Stage1ViewController`, `Stage1View` |
| Stage 전용 보조 타입 | `Stage<N>` 접두사 | `Stage1ImageCell` |
| 여러 Stage가 공유하는 모델 | 주제 폴더 루트 파일 | `Model.swift`의 `FeedItem` |
| Stage 로직 파일 | 주요 타입 하나에 파일 하나, 파일 이름 = 타입 이름 | `Search/Stage2/Stage2Index.swift` |
| signpost 구간 이름 | lowerCamelCase 동사구 | `"decodeImage"`, `"applySnapshot"` |
| 커스텀 지표 이름 | lowerCamelCase 명사구, 단위는 `unit`에 따로 | `record("decodeTime", value: 3.2, unit: "ms")` |

- 약어는 Swift API Design Guidelines를 따른다 (`url`, `jsonData`, `imageURL`).
- 커스텀 지표 단위는 `ms`, `MB`, `count`, `%` 중에서 쓴다.

## 3. 타입과 접근 제어

- 클래스는 기본으로 `final`을 붙인다.
- 주제 모듈에서 `public`은 `PerfTopic`을 따르는 타입 하나뿐이다. 나머지는 `internal`(생략) 또는 `private`이다.
- 파일 밖에서 쓰지 않는 것은 `private`으로 둔다.
- 강제 언래핑(`!`)과 `try!`는 테스트와 "실패하면 버그"인 불변 조건에만 쓴다. 불변 조건에 쓸 때는 그 이유를 주석으로 남긴다.

## 4. 동시성 (Swift 6 strict concurrency)

- UI 타입은 `@MainActor`다 (`UIViewController`, `View`는 이미 메인 액터에 묶여 있다).
- 경고를 없애려고 `@unchecked Sendable`이나 `nonisolated(unsafe)`를 붙이지 않는다.
  - Stage 2에서 락이나 GCD로 직접 동기화하느라 필요한 경우에만 허용한다.
  - 그때는 **어떤 방식으로 안전을 보장하는지** 주석을 단다.
- Stage 전략으로 쓰는 동시성 도구(`Task`, `async let`, GCD, `Thread`)는 PLAN.md의 해당 Stage 전략과 일치해야 한다.

## 5. 주석

> 원칙: **코드를 읽으면 알 수 있는 것은 쓰지 않는다. 코드만 봐서는 알 수 없는 "왜"를 쓴다.**

| 종류 | 쓰는 곳 | 길이 |
|---|---|---|
| `///` 문서 주석 | `public` 선언, 그리고 이름만으로 역할이 드러나지 않는 타입 | 요약 한 줄. 필요할 때만 빈 `///` 다음에 1~3줄 덧붙인다 |
| `//` 일반 주석 | 의도, 제약, 측정상 이유, 직관과 다른 선택 | 1~2줄 |
| Stage 머리말 | Stage 파일 상단 (아래 6절) | 1~3줄 |

- 모든 주석은 한국어로, 평서문으로 끝맺는다 ("~한다").
- 쓰지 않는 것:
  - 코드를 그대로 다시 말하는 주석: `// 셀을 등록한다` + `register(...)`
  - 변경 이력 (git이 기록한다)
  - 주석 처리한 옛 코드
  - TODO (남길 일은 PLAN.md나 LEARNING.md의 "남은 궁금증"에 적는다)
- 성능 때문에 덜 직관적인 코드를 썼다면 **무엇을 피하려는 것인지** 적는다.

```swift
// ✅ 이유를 쓴다
// 셀 재사용 시 이전 이미지의 디코딩 결과가 늦게 도착할 수 있어 id로 한 번 더 확인한다.
guard cell.itemID == item.id else { return }

// ❌ 코드를 반복한다
// id가 같은지 확인한다
guard cell.itemID == item.id else { return }
```

### 역할 주석 (학습용)

이 레포는 학습 기록이기도 해서, "코드가 무엇을 하는가" 대신 **"이 타입이나 API가 무엇이고 여기서 왜 쓰는가"**를 적는 역할 주석을 단다.
처음 보는 사람이 주석만 읽어도 개념을 잡을 수 있게, 짧지만 핵심을 담는다.

| 대상 | 쓰는 내용 | 예 |
|---|---|---|
| 우리가 만든 타입 | 무엇을 책임지는지, 누가 쓰는지 | `/// 주제 모듈이 Scenario에서 데이터를 만들 때 쓴다.` |
| 시스템 타입, API | 무엇인지, 여기서 왜 이것을 골랐는지 | `// CADisplayLink: 화면이 새로 그려질 때마다(vsync) 호출되는 타이머.` |
| 채택한 프로토콜 | 이 타입에 왜 필요한지 | `/// - Sendable: 백그라운드 Task 결과로 넘기기 때문에 필요하다.` |

- 파일 안에서 **처음 등장하는 곳에 한 번만** 쓴다. 1~3줄을 넘기지 않는다.
- 타입의 프로토콜 설명은 타입 문서 주석 끝에 `/// - <프로토콜>: <이유>` 목록으로 모은다.
- `Hashable`, `Identifiable`처럼 이유가 뻔한 프로토콜은 그 이유가 이 타입에 특별할 때만 쓴다.
- Stage 파일에서도 그 Stage가 처음 쓰는 API(`Task`, `AttributedString` 등)에 같은 방식으로 단다.

### MARK

- 형식은 항상 `// MARK: - <이름>`이다. 이름은 영어로 쓴다 (코드 범주를 가리키므로).
- 구획이 2개 이상일 때만 쓴다. 짧은 타입에는 쓰지 않는다.
- 프로토콜 채택은 extension으로 분리하고, 그 위에 프로토콜 이름으로 MARK를 단다.

## 6. Stage 파일 구조

### 폴더

화면 코드와 최적화 대상 로직을 나눈다. 화면 파일은 입력을 받고 결과를 그리고 지표를 남기는 일만 하고, 로직은 역할 폴더 아래 Stage별 폴더에 둔다.

```
<NN-slug>/
├── Model.swift, Scenario.swift, ...   # 모든 Stage 공통 (주제 폴더 루트)
├── <역할>/                            # 예) Search, Decoding, Layout
│   ├── Stage0/Stage0Search.swift
│   ├── Stage1/Stage1Search.swift
│   └── Stage2/Stage2Index.swift, Stage2ResultStack.swift, Stage2Search.swift
├── UIKit/Stage{0,1,2}ViewController.swift
└── SwiftUI/Stage{0,1,2}View.swift
```

- 파일 하나에 주요 타입 하나를 두고, 파일 이름은 타입 이름과 같게 한다. 한 Stage의 로직이 여러 타입이면 Stage 폴더 안에서 나눈다.
  작은 중첩 타입(`Output`, `Plan`)은 바깥 타입 파일에 둔다.
- 로직이 타입 하나라도 Stage 폴더를 만든다. Stage 사이의 구조가 같아야 비교하며 읽기 쉽다.
- 로직이 화면 안에서 끝날 만큼 작으면 역할 폴더를 만들지 않는다.
- Stage 폴더 사이에서 로직을 공유하지 않는다 (`.claude/rules/topics.md` "공정한 비교"). 공유하는 것은 모델과 측정 유틸뿐이고, 주제 폴더 루트에 둔다.

### 머리말 (필수, `scripts/perflab advance`가 검사)

```swift
// 전략: <이 Stage가 어떤 방식으로 구현했는지 한 줄>
// 변경: <바로 이전 Stage 대비 무엇을 바꿨는지 한 줄>   ← 첫 Stage(보통 Stage 0)에서는 생략
```

- import 바로 아래, 타입 선언 바로 위에 둔다.
- 블로그(SUMMARY.md)와 리뷰에서 그대로 인용하므로, 이 두 줄만 읽어도 Stage 간 차이를 알 수 있게 쓴다.
- 줄이 넘치면 `//   `(공백 3칸)으로 이어 쓰되, 전체는 3줄 이내로 한다.

### 구획 순서

1. 저장 프로퍼티 (MARK 없음)
2. `init` (MARK 없음)
3. `// MARK: - Lifecycle`: `viewDidLoad`, `body` 등
4. `// MARK: - <주제 고유 구획>`: 예) `Layout`, `Rendering`, `Decoding`
5. `// MARK: - Benchmark`: `context.isBenchmark`일 때 부하를 재생하는 코드
6. extension마다 `// MARK: - <프로토콜 이름>`

### UIKit 예시

```swift
import Shared
import UIKit

// 전략: UICollectionView 셀에서 이미지를 백그라운드 큐에서 디코딩하고 NSCache에 보관한다.
// 변경: Stage 0의 메인 스레드 UIImage(contentsOfFile:) 디코딩을 백그라운드로 옮겼다.
final class Stage1ViewController: UIViewController {
    private let context: TopicContext
    private let items = Scenario.makeItems()

    init(context: TopicContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // ...
        if context.isBenchmark { startAutoScroll() }
    }

    // MARK: - Benchmark

    private func startAutoScroll() {
        // ...
    }
}

// MARK: - UICollectionViewDataSource

extension Stage1ViewController: UICollectionViewDataSource {
    // ...
}
```

### SwiftUI 예시

```swift
import Shared
import SwiftUI

// 전략: LazyVStack과 .task에서 이미지를 비동기로 디코딩한다.
// 변경: Stage 0의 VStack 즉시 생성을 Lazy 컨테이너로 바꿨다.
struct Stage1View: View {
    let context: TopicContext
    private let items = Scenario.makeItems()

    // MARK: - Lifecycle

    var body: some View {
        // ...
    }

    // MARK: - Benchmark

    private func autoScroll(_ proxy: ScrollViewProxy) async {
        // ...
    }
}
```

## 7. 측정 코드

- 구간 측정은 signpost로 한다. 이름 규칙은 2절을 따른다.

  ```swift
  let state = PerfSignpost.signposter.beginInterval("decodeImage")
  defer { PerfSignpost.signposter.endInterval("decodeImage", state) }
  ```

- 주제별 지표는 `context.metrics.measure(_:_:)`나 `context.metrics.record(_:value:unit:)`로 남긴다. **측정하려고 원래 하지 않던 작업을 추가하지 않는다.** 그런 작업이 필요하면 그 지표는 Instruments로 확인한다.
- 측정용 코드에 `#if DEBUG` 분기를 두지 않는다. 측정은 Release 빌드로 한다.
