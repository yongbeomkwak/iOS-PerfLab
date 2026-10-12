# [PerfLab #02] 수만 개 종목을 실시간으로 갱신하는 시세 대시보드, 모델 타입과 메모리 배치가 얼마나 차이를 만들까? — 검증 기록

코드와 글이 하는 주장이 근거로 확인됐는지를 남긴다. 구현한 쪽과 분리된 에이전트가 판정하고, 구현한 쪽이 조치를 채운다.

- 코드: `code-verifier`가 Stage 구현 직후에 검증한다. 검증 뒤 코드가 바뀌면 다시 검증한다.
- 글: `summary-reviewer`가 SUMMARY.md 초안을 검토한다.
- `scripts/perflab advance`는 이 기록을 검사한다. Stage마다 기록이 있어야 하고, 조치하지 않은 ⚠️/❌가 없어야 하고, 마지막 지문이 지금 코드와 같아야 한다.

<!--
기록 형식 (헤딩의 [태그], 표의 `판정`·`조치` 열, `지문:` 줄은 검증 스크립트가 확인한다)

### [Stage 0] 한 줄 요약 (YYYY-MM-DD)
### [Stage 1] ...
### [Stage 2] ...
### [Summary] ...

- 대상: 읽은 파일
- 판정: ✅ a건 · ⚠️ b건 · ❌ c건
- 지문: `0123456789ab`   ← 조치를 모두 반영한 뒤 `scripts/perflab fingerprint 02-realtime-quote-dashboard`의 출력. [Summary]에는 쓰지 않는다

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-1 | `파일:라인` | 코드나 주석이 하는 주장 | ✅ 검증됨 / ⚠️ 추정 / ❌ 틀림 | 테스트, 측정, 실험, 문서, 코드 중 무엇으로 확인했나 | ⚠️/❌는 필수: 실험으로 확인함, 주석을 고침, 코드를 지움, "추정"으로 표기함 |

판정은 처음 나온 그대로 둔다 (⚠️를 ✅로 바꾸지 않는다). 무엇이 불확실했고 어떻게 해결했는지가 기록이다.
-->

### [Stage 0] 시세 모델(struct 배열 + sorted)과 측정 장치(TickPlayer, CommitObserver) 검증 (2026-10-12)

- 대상: `docs/PLAN.md`, `Scenario.swift`, `Model.swift`, `QuoteStore.swift`, `TickPlayer.swift`, `CommitObserver.swift`, `QuoteCell.swift`, `QuoteRowView.swift`, `Topic.swift`, `Store/Stage0/Stage0Quote.swift`, `Store/Stage0/Stage0QuoteStore.swift`, `UIKit/Stage0ViewController.swift`, `SwiftUI/Stage0View.swift`, `Tests/ConsistencyTests.swift`, `Tests/ScenarioTests.swift`. 참고: Shared의 `CustomMetricRecorder.swift`, `PerfMonitor.swift`
- 판정: ✅ 23건 · ⚠️ 10건 · ❌ 3건
- 지문: `ebd274908630`

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-1 | `Store/Stage0/Stage0Quote.swift:1`, `docs/PLAN.md` | 필드가 12개(정수 2, 문자열 3, 실수 7)이고 한 개가 120바이트다 | ✅ 검증됨 | 실험: 같은 필드 구성의 struct에서 `stride 120 size 120`. 필드 수는 코드로 확인 | - |
| 0-2 | `Scenario.swift`, `Tests/ScenarioTests.swift` | String은 UTF-8 15바이트 이하면 값 안에, 넘으면 힙에 둔다. 한글은 5글자까지 값 안, 6글자부터 힙 | ✅ 검증됨 | 실험: `unsafeBitCast(String, to: (UInt64, UInt64))`의 상위 바이트. "한빛반도체"(15B)는 small, "한빛전자 우"(16B), "하나로반도체"(18B)는 힙. 종목 코드와 업종 리터럴은 small | - |
| 0-3 | `Model.swift` | seed의 문자열을 그대로 넘겨받아 Stage마다 문자열 저장 공간이 따로 생기지 않는다 | ✅ 검증됨 | 실험: 힙 문자열 복사 뒤 `utf8.withContiguousStorageIfAvailable`의 주소가 같았다. `Stage0Quote.init`은 대입만 한다 | - |
| 0-4 | `Model.swift:5` | Sendable은 테스트에서 Scenario 데이터를 여러 테스트가 함께 읽을 수 있게 하려고 붙인다 | ❌ 틀림 | 실험: internal struct는 Sendable을 붙이지 않아도 `-swift-version 6`에서 `static let`을 `Task.detached`로 읽을 수 있었다(암시적 Sendable). 에러가 나는 것은 public 타입뿐이었다 | 명시적 `Sendable`과 틀린 이유 주석을 `Model.swift`의 모든 타입에서 지움 |
| 0-5 | `Store/Stage0/Stage0QuoteStore.swift` | 배열 원소의 프로퍼티는 복사 없이 제자리에서 바뀐다 | ✅ 검증됨 | 실험(`-O`): 40틱 갱신 뒤에도 `quotes` 버퍼 주소가 같았다 | - |
| 0-6 | `Store/Stage0/Stage0QuoteStore.swift` | `sorted(by:)`는 원본을 두고 정렬한 새 배열을 돌려주며 원소가 새 배열로 복사된다 | ✅ 검증됨 | 문서: SDK `Swift.swiftinterface`의 `var result = ContiguousArray(self); try result.sort(by:); return Array(result)` | - |
| 0-7 | `docs/PLAN.md`, `Stage0QuoteStore.swift` | `sortTime`은 5만 개를 등락률 순으로 줄 세우는 시간이다 | ✅ 검증됨 | 코드: 구간에 정렬 외에 새 버퍼 복사(+힙 문자열 retain)와 이전 `ranked` 해제가 들어간다. 실험(Mac `-O`): 해제 0.14~0.29ms, 정렬 전체 약 8.5ms | - |
| 0-8 | `docs/PLAN.md` | S0도 정렬하면서 힙 문자열의 참조 카운트를 올리고 내린다 (추정) | ⚠️ 추정 | 실험(Mac `-O`, 40회): 종목명이 모두 small일 때와 모두 힙일 때 정렬 시간 차이가 없었고, 이전 배열 해제만 0.14ms → 0.26~0.29ms. 실기기 Time Profiler로 확정해야 한다 | PLAN에 "추정"을 유지하고 이 Mac 실험값과 측정 단계에서 실기기 Time Profiler로 `swift_retain`/`swift_release` 비율을 볼 계획을 적음. PLAN에 `sortTime`의 구성(복사, 해제 포함)도 적음 |
| 0-9 | `docs/PLAN.md` | Mac에서 Stage 0 방식의 참고값은 틱당 약 10ms다 | ✅ 검증됨 | 실험: Stage0 로직 스크립트(`-O`, 5만 개, 갱신 5천, 40틱)에서 update 0.31 + sort 9.31 + summary 0.28 ≈ 9.9ms | - |
| 0-10 | `TickPlayer.swift` | k번째 틱을 `시작 + k×interval`에 적용하고 늦어도 건너뛰지 않는다. 시간 지표는 PLAN 정의대로 ms. `modelMemory`는 화면 갱신 요청 전에 남긴다 | ✅ 검증됨 | 코드: interval 계산, deadline, `step % batches.count`, `measure`의 ms 기록, tickTime 범위, modelMemory 위치 | - |
| 0-11 | `TickPlayer.swift` | 늦었으면 `Task.yield()`로 한 번 양보해 메인 스레드의 다른 작업이 끼어들게 한다 | ✅ 검증됨 | 실험(macOS): `@MainActor` Task에서 10ms 일하고 yield하기를 반복하자 매번 `beforeWaiting` 관찰자가 불렸다. iOS 런루프에서는 돌려 보지 않았다 | - |
| 0-12 | `TickPlayer.swift` | `CACurrentMediaTime`은 display link timestamp와 같은 시계다 | ✅ 검증됨 | 문서: `CABase.h`, `CADisplayLink.h` (둘 다 mach host time) | - |
| 0-13 | `TickPlayer.swift`, `docs/PLAN.md` | `tickLatency` = 틱 예정 시각부터 적용 뒤 첫 프레임 시각까지 | ✅ 검증됨 | 코드: applyTick 뒤 `afterNextFrame` 등록, `presented - deadline`. `PerfMonitor.nextPresentation` | - |
| 0-14 | `CommitObserver.swift`, `docs/PLAN.md` | order가 작은 관찰자부터 불리고, `CFIndex.max`면 Core Animation 커밋보다 늦게 불린다 | ✅ 검증됨 | 실험(macOS): order 10, 2_000_001, `CFIndex.max` 순으로 불렸다. CA 관찰자는 `CA::Transaction::observer_callback`, `order = 2000000`, beforeWaiting\|exit. iOS 값은 출력해 보지 않았다 | - |
| 0-15 | `docs/PLAN.md`, `SwiftUI/Stage0View.swift` | 틱마다 `cellForRowAt` 13번과 `QuoteRowView.body` 13~14번이 reloadTime 구간 안에서 불린다. `List`는 보이는 행만 만든다 | ⚠️ 추정 | 작성자의 임시 출력 실험이고 출력 코드가 지워져 재현하지 않았다. Instruments에서 signpost로 확인할 수 있다 | PLAN에 실험 절차(출력 위치, `simctl launch --console-pty`)와 결과, 코드 검증에서 재현되지 않았다는 점을 적음. 측정 단계에서 실기기 Instruments로 다시 확인하기로 함 |
| 0-16 | `CommitObserver.swift:6-8` | 화면 갱신이 beforeWaiting에 처리된다는 것은 "(추정)", SwiftUI 갱신이 들어오는지는 "Stage 0에서 Instruments로 확인한다" | ❌ 틀림 | PLAN은 이미 "임시 출력으로 확인함"이라고 적어 주석과 다르다. CA 커밋이 beforeWaiting에 걸리는 것은 0-14에서 확인됐다 | 주석을 고침: CA 관찰자의 order(macOS 출력, iOS 미확인)와 Stage 0 임시 출력 확인을 근거로 적음 |
| 0-17 | `CommitObserver.swift` | 메인 스레드가 아니면 `MainActor.assumeIsolated`가 앱을 멈춘다 | ✅ 검증됨 | 문서: `_Concurrency.swiftinterface`의 `fatalError("Incorrect actor executor assumption…")`. 관찰자는 메인 런루프에 걸려 있다 | - |
| 0-18 | `CommitObserver.swift` | `commonModes`에 걸면 스크롤 중(tracking 모드)에도 불린다 | ⚠️ 추정 | `CFRunLoop.h`에는 선언만 있다. UITrackingRunLoopMode가 common 모드에 들어 있는지 확인하지 않았다 | 주석에 "추정"을 붙임 |
| 0-19 | `UIKit/Stage0ViewController.swift` | 재생 Task는 메인 액터에서 만들어져 메인 스레드에서 돈다 | ✅ 검증됨 | 코드: `TickPlayer`가 `@MainActor`, Task는 `@MainActor` VC 메서드에서 만든다 | - |
| 0-20 | `UIKit/Stage0ViewController.swift` | `.task`처럼 나타날 때마다 재생을 시작하고 사라지면 멈춘다. 약하게 잡으면 취소를 놓쳐도 화면이 해제된다 | ⚠️ 추정 | 코드: `startPlayback()`이 기존 Task를 취소하지 않고 덮어써, `viewDidDisappear` 없이 `viewWillAppear`가 다시 불리면 루프 두 개가 같은 store를 고친다. 프레임워크 간 store 수명도 다르다 | `startPlayback()`이 기존 Task를 먼저 취소하도록 고침. SwiftUI도 `.task`가 다시 돌 때 기존 store를 유지하도록 고쳐 두 프레임워크의 모델 수명을 맞춤 |
| 0-21 | `UIKit/Stage0ViewController.swift` | 행 높이를 고정하면 테이블이 5만 행의 높이를 하나씩 묻지 않는다 | ⚠️ 추정 | 문서: `UITableView.h`에서 `rowHeight`, `estimatedRowHeight` 기본값은 `UITableViewAutomaticDimension`. delegate가 없어 높이를 묻는 메서드도 없다 | 주석을 문서 근거로 고침: SwiftUI 행과 같은 고정 높이를 쓰고, 기본값이면 셀 내용으로 높이를 정한다. "묻지 않는다" 주장은 지움 |
| 0-22 | `UIKit/Stage0ViewController.swift` | `reloadData`는 모두 다시 묻고, 보이는 행만 다시 구성한다 | ✅ 검증됨 | 문서: `UITableView.h` "Reloads everything from scratch. Redisplays visible rows." | - |
| 0-23 | `UIKit/Stage0ViewController.swift:4-5`, `SwiftUI/Stage0View.swift:4-5` | `// 전략:` "sorted(by:)로 등락률 순 새 배열을 만들어 훑어서 집계한 뒤" | ❌ 틀림 | 코드: 집계는 정렬한 `ranked`가 아니라 id 순서 `quotes`를 훑는다 | 두 머리말을 "id 순서 배열을 훑어 집계한 뒤"로 고침 |
| 0-24 | `SwiftUI/Stage0View.swift` | `@State`의 초깃값 식은 뷰 값이 만들어질 때마다 다시 계산된다 | ✅ 검증됨 | 문서: `State.init(wrappedValue:)`는 autoclosure가 아니다 | - |
| 0-25 | `SwiftUI/Stage0View.swift` | `ForEach(상수 범위)`는 행이 위치로 구분된다. 모델이 class라 SwiftUI는 변화를 모른다 | ✅ 검증됨 | 문서: `@_semantics("swiftui.requires_constant_range") init(_ data: Range<Int>, …)`. 코드: store는 Observable이 아니다 | - |
| 0-26 | `QuoteRowView.swift` | `keyframeAnimator`는 trigger가 바뀔 때마다 재생한다. 바뀌지 않은 행은 trigger를 -1로 고정해 재생하지 않는다 | ⚠️ 추정 | swiftinterface에 문서 주석이 없다. 직전 틱에 바뀐 행은 trigger가 `tick` → -1로 바뀌므로 그 행은 한 번 재생된다 | Apple 문서로 확인함: "Plays the given keyframes when the given trigger value changes", 재생 중 `content`는 매 프레임 갱신. 주석을 고침: -1에 머무는 행은 재생하지 않고, 직전 틱에 바뀐 행은 한 번 더 재생되지만 색이 없다 |
| 0-27 | `QuoteRowView.swift` | SwiftUI가 `keyframes` 함수를 렌더 스레드에서도 불러 격리 검사에 걸렸다. 그래서 `nonisolated`로 둔다 | ⚠️ 추정 | 문서: `content`는 `@Sendable`, `keyframes`는 아니다. 메인 밖에서 불린다는 것은 재현하지 않았다 | 시뮬레이터 크래시 리포트(2026-10-12 11:06)로 확인함: `ViewGraphDisplayLink.displayLinkTimer(isAsyncThread:)` → `updateOutputsAsync` → `QuoteRowView.body`의 클로저 → `dispatch_assert_queue_fail`. 주석의 "렌더 스레드"를 "메인이 아닌 SwiftUI 스레드"로 고치고 근거를 적음 |
| 0-28 | `QuoteCell.swift` | `allowUserInteraction`이면 애니메이션 중에도 스크롤과 터치를 받는다 | ⚠️ 추정 | 문서: `UIView.h` "turn on user interaction while animating". 애니메이션 중인 뷰의 터치에 대한 옵션이라 스크롤과는 무관할 수 있다 | 주석을 `UIView.h` 설명대로 고침 (애니메이션 중인 뷰가 터치를 받음). 스크롤 주장은 지움 |
| 0-29 | `QuoteCell.swift`, `QuoteRowView.swift` | 바뀐 방향 색으로 칠했다가 0.3초 동안 지운다. UIKit과 SwiftUI는 같은 크기와 색을 쓴다 | ✅ 검증됨 | 코드: `flash`와 `QuoteStyle` | - |
| 0-30 | `QuoteStore.swift` | `@State`에 큰 배열을 가진 값을 두면 고칠 때마다 배열이 통째로 복사될 수 있다 | ⚠️ 추정 | 확인하지 않았다 | 확인하지 않은 주장을 주석에서 지움. class로 묶는 이유는 "화면과 TickPlayer가 같은 모델을 함께 고친다"만 남김 |
| 0-31 | `QuoteStore.swift` | `count`는 항상 `Scenario.quoteCount`다. `rankedIDs`는 정합성 테스트에서만 쓴다 | ✅ 검증됨 | 테스트: `stage0MatchesReference`. 코드: 화면에서 `rankedIDs`를 쓰지 않는다 | - |
| 0-32 | `Stage0QuoteStore.swift`, `docs/PLAN.md` | `modelMemory`는 두 배열의 `capacity × stride`다 | ✅ 검증됨 | 코드: PLAN 계산법과 같다. 실험: capacity 50107 (원소 5만 개) | - |
| 0-33 | `Store/Stage0/Stage0Quote.swift:3-4` | 모든 Stage가 같은 필드를 같은 규칙으로 갱신한다 | ⚠️ 추정 | 코드: `open`, `high`, `low`, `volume`은 읽는 곳이 없고 테스트 기준 구현도 가격만 추적한다. S1, S2는 아직 없다 | 주석을 고침: "S1, S2도 같은 규칙으로 구현한다. 화면에 나오지 않아 정합성 테스트는 비교하지 않는다" |
| 0-34 | `Model.swift`, `Stage0Quote.swift`, `Stage0QuoteStore.swift` | 깜빡임은 이번 틱에 바뀐 종목만 직전 가격과 비교한 방향으로 나온다. `updatedTick` 0은 아직 안 들어옴이다 | ✅ 검증됨 | 테스트: `stage0MoveReflectsLatestTickOnly`. 코드: `tick += 1`이 먼저라 0이 대입되지 않는다 | - |
| 0-35 | `docs/PLAN.md`, `Tests/` | 배치를 순서대로 적용하며 매 틱 기준 구현과 비교한다. 시나리오는 결정적이다 | ✅ 검증됨 | 테스트: `scripts/perflab test` 통과. 동점 처리가 기준 구현에도 있다 | - |
| 0-36 | `docs/PLAN.md` | n·log₂n ≈ 80만, 120Hz 예산 8.3ms, 5천/5만 = 10%, 10초에 40틱 | ✅ 검증됨 | 산술 | - |

불필요하거나 설명되지 않는 코드에 대한 조치:

- `Model.swift`의 명시적 `Sendable`: 지움 (0-4).
- `CommitObserver`의 `[weak self]`: "invalidate를 놓쳐도 관찰자가 이 객체를 붙잡아 두지 않게" 하려는 방어용이라는 이유를 주석으로 적음.
- UIKit 재생 Task가 취소를 놓치는 경우: `startPlayback()`에서 기존 Task를 먼저 취소함 (0-20).
- 프레임워크 간 store 수명 차이: SwiftUI도 store를 유지해 맞춤 (0-20).
- `Stage0Quote`의 `open/high/low/volume`: PLAN 가설 4의 이유대로 남김. 테스트가 비교하지 않는다는 점을 주석에 적음 (0-33).

#### 재검증 1: 조치 후 바뀐 부분 (2026-10-12)

- 대상: `Model.swift`, `CommitObserver.swift`, `QuoteRowView.swift`, `QuoteCell.swift`, `QuoteStore.swift`, `Store/Stage0/Stage0Quote.swift`, `UIKit/Stage0ViewController.swift`, `SwiftUI/Stage0View.swift`, `docs/PLAN.md`. 대조: `TickPlayer.swift`, `Tests/ConsistencyTests.swift`
- 판정: ✅ 11건 · ⚠️ 5건 · ❌ 0건 (검증 시점 지문 `83a47dfa4b59`)

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-37 | `Model.swift` | (0-4 조치) 명시적 `Sendable`을 지워도 된다. internal 타입이라 암시적으로 Sendable이다 | ✅ 검증됨 | 테스트: Swift 6 모드 빌드와 `scripts/perflab test` 통과 | - |
| 0-38 | `CommitObserver.swift:6-8` | (0-16 조치) CA 커밋 관찰자는 `beforeWaiting`에 order 2000000(macOS, iOS 미확인). 셀 구성과 행 갱신이 구간에 들어오는 것은 임시 출력으로 확인 | ✅ 검증됨 | 실험: 0-14의 macOS 런루프 출력과 같다. 표현이 PLAN과 맞는다 | - |
| 0-39 | `CommitObserver.swift` | invalidate를 놓쳐도 관찰자가 이 객체를 붙잡아 두지 않게 약하게 잡는다 | ✅ 검증됨 | 코드: 관찰자 블록이 self를 캡처하고 런루프가 관찰자를 든다 | - |
| 0-40 | `CommitObserver.swift` | (0-18 조치) `commonModes`에 스크롤 중 모드도 들어 있는 것으로 알려져 있다 (추정) | ⚠️ 추정 | 주석의 "(추정)"이 근거 수준과 맞다. 사실 확인은 하지 않았다 | "추정"으로 표기해 둠. 이 지표는 Benchmark 모드(스크롤 없음)에서 재므로 측정 결과에는 영향이 없다 |
| 0-41 | `QuoteRowView.swift` | (0-26 조치) trigger가 바뀌면 재생하고(Apple 문서), 재생 중에는 content를 매 프레임 부른다. 직전 틱에 바뀐 행은 한 번 더 재생되지만 색이 없다 | ⚠️ 추정 | swiftinterface에 문서 주석이 없어 이번에 확인하지 못했다 | Apple 문서 원문을 확인함 (developer.apple.com, `keyframeAnimator(initialValue:trigger:content:keyframes:)`): "Plays the given keyframes when the given trigger value changes", "the `content` closure will be updated on every frame while animating" |
| 0-42 | `QuoteRowView.swift` | (0-27 조치) 메인 액터로 추론된 클로저가 `displayLinkTimer(isAsyncThread:)` → `updateOutputsAsync`에서 불려 멈췄다. 이 매개변수는 `@Sendable`이 아니다 | ⚠️ 추정 | 뒷부분은 swiftinterface로 확인. 크래시 스택은 재현하지 않았다 | 시뮬레이터 크래시 리포트(2026-10-12 11:06)의 크래시 스레드 스택을 위에서 아래로 옮겨 둠: `_dispatch_assert_queue_fail` ← `swift_task_isCurrentExecutor` ← `closure #3 in QuoteRowView.body.getter` ← `View.keyframeAnimator` ← `KeyframeTimeline.init` ← `AnimatorAttribute.updateValue` ← `ViewGraph.updateOutputsAsync` ← `ViewGraphDisplayLink.displayLinkTimer(_:)`. 재현 방법: `nonisolated`를 빼고 시뮬레이터에서 실행 |
| 0-43 | `QuoteCell.swift` | (0-28 조치) `allowUserInteraction`이면 애니메이션 중인 뷰도 터치를 받는다 | ✅ 검증됨 | 문서: `UIView.h:74` | - |
| 0-44 | `QuoteStore.swift` | (0-30 조치) 모델 그릇은 class, Stage마다 다른 것은 종목을 담는 방식 | ✅ 검증됨 | 코드 | - |
| 0-45 | `Store/Stage0/Stage0Quote.swift` | (0-33 조치) 화면에 쓰지 않는 필드는 정합성 테스트가 비교하지 않는다 | ✅ 검증됨 | 코드: `Reference`는 가격만 추적한다 | - |
| 0-46 | `UIKit/Stage0ViewController.swift`, `SwiftUI/Stage0View.swift` | (0-23 조치) `// 전략:` "id 순서 배열을 훑어 집계" | ✅ 검증됨 | 코드: `for quote in quotes` | - |
| 0-47 | `UIKit/Stage0ViewController.swift` | (0-21 조치) 고정 높이, 기본값이면 셀 내용으로 높이를 정한다 | ✅ 검증됨 | 문서: `UITableView.h:363, 766` | - |
| 0-48 | `UIKit/Stage0ViewController.swift`, `TickPlayer.swift:29-35` | (0-20 조치) 다시 나타날 때 기존 재생을 취소해 루프 두 개가 한 모델을 고치지 않게 한다 | ⚠️ 추정 | 코드: 옛 루프가 `Task.yield()`에서 멈춰 있을 때 취소되면 재개 뒤 취소를 확인하지 않고 틱을 한 번 더 적용한다. `Task.sleep`은 예외로 바로 끝난다 | `TickPlayer`에서 `Task.yield()` 뒤에 `Task.isCancelled`를 확인해 바로 끝나도록 고침 |
| 0-49 | `SwiftUI/Stage0View.swift` | 화면이 처음 나타날 때 한 번 만들고 다시 나타나도 유지한다 | ✅ 검증됨 | 코드: `self.store ?? …`. 프레임워크 간 차이가 없어졌다 | - |
| 0-50 | `docs/PLAN.md` | 임시 출력으로 확인했다 (방법과 결과) | ⚠️ 추정 | 방법은 구체적이지만 출력 코드가 지워져 재현하지 않았다. 문서가 근거 수준을 스스로 밝히고 있다 | PLAN에 "재현되지 않았다, 측정 단계에서 실기기 Instruments로 다시 확인한다"를 적어 둠 (측정 단계 할 일) |
| 0-51 | `docs/PLAN.md` | Mac 실험에서 힙/값 안 종목명의 정렬 시간이 비슷했고 해제만 늘었다 | ✅ 검증됨 | 실험: 0-8 출력과 같다 | - |
| 0-52 | `docs/PLAN.md` | `sortTime`에는 복사와 이전 결과 해제가 함께 들어간다 | ✅ 검증됨 | 0-6, 0-7 | - |

#### 재검증 2: 0-48 조치 (2026-10-12)

- 대상: `TickPlayer.swift`
- 판정: ✅ 2건 · ⚠️ 0건 · ❌ 0건 (검증 시점 지문 `ebd274908630`)

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-53 | `TickPlayer.swift:33` | `Task.yield`는 취소돼도 예외를 던지지 않는다(`Task.sleep`과 다르다) | ✅ 검증됨 | 문서: `_Concurrency.swiftinterface`의 `yield() async`(throws 없음), `sleep(for:) async throws`. 실험: 취소한 Task에서 `Task.sleep`은 `CancellationError`를 던졌다 | - |
| 0-54 | `TickPlayer.swift:33-34` | 양보하는 동안 취소됐는지 한 번 더 보면 취소된 루프는 틱을 더 적용하지 않는다 | ✅ 검증됨 | 실험(`-swift-version 6`): 바로 취소한 `@MainActor` Task에서 yield 뒤 `Task.isCancelled`가 true였고 뒤 작업은 돌지 않았다. 코드: 검사가 `applyTick` 앞에 있다 | - |

### [Stage 1] Quote를 final class로 바꾼 모델(Stage1Quote, Stage1QuoteStore)과 화면 검증 (2026-10-12)

- 대상: `docs/PLAN.md`, `Scenario.swift`, `Model.swift`, `QuoteStore.swift`, `TickPlayer.swift`, `CommitObserver.swift`, `Topic.swift`, `Store/Stage1/Stage1Quote.swift`, `Store/Stage1/Stage1QuoteStore.swift`, `UIKit/Stage1ViewController.swift`, `SwiftUI/Stage1View.swift`, `Tests/ConsistencyTests.swift`. 대조: `Store/Stage0/*`, `UIKit/Stage0ViewController.swift`, `SwiftUI/Stage0View.swift`
- 판정: ✅ 15건 · ⚠️ 3건 · ❌ 1건
- 지문: `63feed0af598`

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 1-1 | `Store/Stage1/Stage1Quote.swift:3-4` | final이면 하위 클래스가 재정의할 수 없어 컴파일러가 동적 디스패치 없이 접근할 수 있다 | ✅ 검증됨 | 실험: 단일 파일 `-O` 어셈블리에서 final은 간접 호출 0개, final을 빼면 24개. 단 `-wmo`에서는 final이 없어도 0개(internal 클래스라 추론). 이 앱의 Release는 `SWIFT_COMPILATION_MODE = wholemodule` | 판정과 별개로, 주석이 "final 덕분에 빨라진다"로 읽히지 않게 WMO에서는 추론된다는 점과 의도 표시 역할을 덧붙임 |
| 1-2 | `Store/Stage1/Stage1Quote.swift:1` | S0과 필드, 갱신 규칙이 같고 타입만 참조 타입이다 | ✅ 검증됨 | 코드: 필드 12개, init, `changeRate`, 갱신 6줄. 테스트: `stage1MatchesReference`, `stage1MoveReflectsLatestTickOnly` | - |
| 1-3 | `Store/Stage1/Stage1QuoteStore.swift:3-4` | 머리말: 배열 칸이 120B 값에서 8B 참조가 되고 종목마다 힙 객체가 생긴다 | ✅ 검증됨 | 실험: class 참조 stride 8. 코드: S0 대비 바뀐 것은 모두 class 전환에서 나온다 | - |
| 1-4 | `Store/Stage1/Stage1QuoteStore.swift` | 새 배열로 복사되는 것은 참조이고 `ranked`는 `quotes`와 같은 객체를 가리킨다 | ✅ 검증됨 | 실험(`-O`, 5만 개): `ranked.allSatisfy { $0 === quotes[$0.id] }` true | - |
| 1-5 | `Store/Stage1/Stage1QuoteStore.swift` | `malloc_size`는 할당기가 실제로 내준 크기(올림 포함), `passUnretained`는 참조 카운트를 바꾸지 않는다 | ✅ 검증됨 | 문서: `malloc/malloc.h`, `Swift.swiftinterface`. 실험: retain count 2 → 2, Swift 객체 주소의 `malloc_size` 160 | - |
| 1-6 | `Store/Stage1/Stage1QuoteStore.swift` | 객체는 화면이 살아 있는 동안 그대로라 한 번만 센다 | ✅ 검증됨 | 코드: `quotes`는 init에서만 대입 | - |
| 1-7 | `Stage1QuoteStore.swift`, `docs/PLAN.md` | `modelMemory` = 참조 배열 두 개의 `capacity × stride` + 객체마다 `malloc_size` | ✅ 검증됨 | 코드: PLAN 계산법과 같다. 테스트: 하한 확인 | - |
| 1-8 | `Stage1QuoteStore.swift` | 꺼낸 객체를 고치면 배열이 가리키는 그 객체가 바뀐다 | ✅ 검증됨 | 테스트: `stage1MatchesReference` | - |
| 1-9 | `Tests/ConsistencyTests.swift` | 객체는 필드 120B에 헤더 16B가 붙는다 | ✅ 검증됨 | 실험: `class_getInstanceSize` 136. Mac `malloc_size` 160 | - |
| 1-10 | `UIKit/Stage1ViewController.swift`, `SwiftUI/Stage1View.swift` | 머리말이 코드와 같다. 화면 코드는 S0과 같다 | ✅ 검증됨 | 코드: S0과 diff하면 머리말, 타입 이름, store 타입만 다르다 | - |
| 1-11 | `SwiftUI/Stage1View.swift` (S0에도 같은 코드) | `ForEach(상수 범위)`는 범위가 바뀌지 않는다고 약속하는 형태다 | ⚠️ 추정 | 실험: Release 빌드에서 `ForEach(0..<Scenario.quoteCount)`에 "non-constant range: argument must be an integer literal" 경고. 이 경고가 있을 때의 동작은 확인하지 않았다 | S0, S1 SwiftUI 화면에서 리터럴 `0..<50_000`으로 바꾸고 이유를 주석에 적음. 두 값이 같은지는 `ScenarioTests.listRangeMatchesQuoteCount`로 확인. Release 빌드(시뮬레이터)에서 이 경고가 사라진 것을 확인함 |
| 1-12 | `docs/PLAN.md` S1 대가 | class의 `var` 접근에 `swift_beginAccess` 동적 검사가 붙어 S1의 대가가 된다 | ❌ 틀림 | 실험: Release(iOS) 목적 파일을 `objdump`로 읽음. 정렬 특수화 함수에는 `swift_beginAccess`가 없다. `applyUpdates`의 1곳은 store의 `quotes` 접근이고 S0에도 2곳 있다. 단일 파일 `-O`에서는 비교마다 불렸다(컴파일 모드에 따라 사라지는 비용) | PLAN에서 배타성 검사 대가를 지우고, 목적 파일에서 확인된 실제 ARC 위치(반영의 retain/release, 복사의 retain)로 바꿈 |
| 1-13 | `docs/PLAN.md` S1 대가 | 참조를 복사할 때 참조 카운트를 늘리고 줄인다 | ✅ 검증됨 | 실험(Release 목적 파일): `Array._copyContents`에 `swift_retain`. `applyUpdates`는 종목마다 retain/release (S0에는 없다). `row(at:)`에도 있다 | - |
| 1-14 | `docs/PLAN.md` S1 전략 | 정렬은 120B 값 대신 8B 참조를 옮긴다 | ✅ 검증됨 | 실험(Release 목적 파일): 특수화된 `_merge`는 `memmove`로 옮기고 retain/release가 없다 | - |
| 1-15 | `docs/PLAN.md` | `seeds.map`으로 만든 5만 개는 힙에서 id 순서로 거의 붙어 놓인다 | ⚠️ 추정 | 실험(Mac `-O`): 이웃 id 객체의 주소 차이가 49,999쌍 중 49,506쌍에서 160B. iOS 할당기에서는 확인하지 않았다 | PLAN에 Mac 실험 결과와 "iOS에서는 확인하지 않았다"를 적고 "(추정)"을 유지함 |
| 1-16 | `docs/PLAN.md` | 정렬 비교는 순서가 메모리 순서와 무관해 할당 배치 영향을 덜 받는다 | ⚠️ 추정 | 정렬은 id 순서에서 시작해 처음 run 구간은 이웃 객체를 차례로 읽고, 병합부터 무작위 접근이 된다. 영향 크기는 재지 않았다 | PLAN 문장을 "처음 짧은 구간은 이웃을 차례로, 병합부터 메모리 순서와 무관 (추정, 크기는 재지 않음)"으로 고침 |
| 1-17 | `docs/PLAN.md` S1 대가 | 종목마다 힙 객체 하나(헤더 + 할당 단위 올림) | ✅ 검증됨 | 실험: 인스턴스 136B, Mac `malloc_size` 160B | - |
| 1-18 | `Tests/ConsistencyTests.swift` | S1이 매 틱 기준 구현과 같은 결과를 낸다 | ✅ 검증됨 | 테스트 통과 | - |
| 1-19 | `SwiftUI/Stage1View.swift`, `UIKit/Stage1ViewController.swift` | store 수명, tick으로 다시 그림, 메인에서 도는 Task, 약한 참조와 기존 Task 취소 | ✅ 검증됨 | 코드: S0과 같고 0-19, 0-20, 0-24, 0-25에서 확인 | - |

#### 재검증 1: ForEach 리터럴 범위, final 주석, PLAN의 S1 대가 문장 (2026-10-12)

- 대상: `SwiftUI/Stage0View.swift`, `SwiftUI/Stage1View.swift`, `Tests/ScenarioTests.swift`, `Store/Stage1/Stage1Quote.swift`, `docs/PLAN.md`
- 판정: ✅ 6건 · ⚠️ 1건 · ❌ 0건 (검증 시점 지문 `f425e4af40f3`)

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 1-20 | `SwiftUI/Stage0View.swift`, `SwiftUI/Stage1View.swift` | 컴파일러는 정수 리터럴만 상수 범위로 인정하고 아니면 Release에서 경고한다. 리터럴로 바꾸면 경고가 없어진다 | ✅ 검증됨 | 실험: 조치 전후 Release(`generic/platform=iOS`) 빌드 비교 | - |
| 1-21 | 같은 파일, `Tests/ScenarioTests.swift` | 리터럴 `50_000`과 `Scenario.quoteCount`가 같다는 것은 `listRangeMatchesQuoteCount`가 확인한다 | ⚠️ 추정 | 테스트는 `quoteCount == 50_000`만 본다. 뷰의 리터럴만 바꾸면 계속 통과한다 | 주석을 실제 범위로 좁힘: "`quoteCount`를 바꾸면 테스트가 깨져 리터럴도 고치게 한다. 리터럴만 바꾸는 실수는 잡지 못한다" (뷰 두 곳과 테스트 문서 주석) |
| 1-22 | `SwiftUI/Stage0View.swift`, `SwiftUI/Stage1View.swift` | 범위만 리터럴로 바꿨고 두 Stage의 화면 코드는 여전히 같다 | ✅ 검증됨 | 코드 diff, 테스트 통과 | - |
| 1-23 | `Store/Stage1/Stage1Quote.swift` | Release는 전체 모듈 최적화라 internal 클래스는 final로 추론된다. final은 의도 표시다 | ✅ 검증됨 | 실험 1-1, `SWIFT_COMPILATION_MODE = wholemodule` | - |
| 1-24 | `docs/PLAN.md` | S1 객체 배치(Mac 실험, iOS 미확인), 정렬의 접근 순서(추정) | ✅ 검증됨 | 1-15 수치를 옮겼고 확인하지 않은 부분을 표기했다 | - |
| 1-25 | `docs/PLAN.md` | S1에서 늘어나는 ARC는 반영의 retain/release와 복사의 retain. `_merge`는 `memmove` | ✅ 검증됨 | 실험 1-13, 1-14 | - |
| 1-26 | `docs/PLAN.md` | 배타성 검사 대가를 지웠다. 남은 언급은 Release 정렬 코드에서 사라졌다는 사실뿐 | ✅ 검증됨 | `grep`, 실험 1-12 | - |

#### 재검증 2: 1-21 조치 (2026-10-12)

- 대상: `SwiftUI/Stage0View.swift`, `SwiftUI/Stage1View.swift`, `Tests/ScenarioTests.swift` (주석만 바뀐 부분)
- 판정: ✅ 1건 · ⚠️ 0건 · ❌ 0건 (검증 시점 지문 `63feed0af598`)

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 1-27 | `SwiftUI/Stage0View.swift`, `SwiftUI/Stage1View.swift`, `Tests/ScenarioTests.swift` | `quoteCount`를 바꾸면 테스트가 깨져 리터럴도 고치게 한다. 리터럴만 바꾸는 실수는 잡지 못한다 | ✅ 검증됨 | 코드: 테스트 본문은 `#expect(Scenario.quoteCount == 50_000)` 하나이고 뷰 리터럴은 읽지 않는다 | - |
