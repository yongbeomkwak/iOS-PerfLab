# [PerfLab #01] 5만 개 항목 검색 자동완성, 키워드 하이라이트까지 타이핑을 따라가려면? — 검증 기록

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
- 지문: `0123456789ab`   ← 조치를 모두 반영한 뒤 `scripts/perflab fingerprint 01-search-autocomplete-highlight`의 출력. [Summary]에는 쓰지 않는다

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-1 | `파일:라인` | 코드나 주석이 하는 주장 | ✅ 검증됨 / ⚠️ 추정 / ❌ 틀림 | 테스트, 측정, 실험, 문서, 코드 중 무엇으로 확인했나 | ⚠️/❌는 필수: 실험으로 확인함, 주석을 고침, 코드를 지움, "추정"으로 표기함 |

판정은 처음 나온 그대로 둔다 (⚠️를 ✅로 바꾸지 않는다). 무엇이 불확실했고 어떻게 해결했는지가 기록이다.
-->

Stage 0~2는 검증 과정이 생기기 전에 구현됐다. 아래 세 섹션은 measured 상태에서 한 번에 소급 검증한 기록이다 (검증 당시 코드 지문 `b04310a790ed`).

### [Stage 0] 공용 파일과 Stage 0의 사실 주장은 대부분 확인됐고, S0 `searchMemory` 추정이 실제 버퍼의 절반가량만 센다 (2026-10-11)

- 대상: `docs/PLAN.md`, `Model.swift`, `Scenario.swift`, `TypingPlayer.swift`, `Topic.swift`, `Search/Stage0/Stage0Search.swift`, `UIKit/Stage0ViewController.swift`, `SwiftUI/Stage0View.swift`, `Tests/ScenarioTests.swift`, `Tests/ConsistencyTests.swift`, `results/iPhone14,7/stage0-*.json`, `results/iPhone18,1-simulator/stage0-*.json`, Shared의 `PerfMonitor.swift`, `CustomMetricRecorder.swift`, `PerfTopic.swift`, `TopicContainerView.swift`
- 판정: ✅ 20건 · ⚠️ 4건 · ❌ 1건
- 실험 환경: Mac(arm64), Swift 6.2.1, `swiftc -O -swift-version 6`. 스크립트는 `/private/tmp/claude-504/-Users-hamp-Desktop-iOS-PerfLab/599c40c9-2752-4334-91f7-4910c391d91b/scratchpad/verify/` 아래 `a/`(레이아웃, 문자열), `b/`(오버로드), `c/`(동시성), `h/`(주제 소스 사본으로 만든 하니스)에 있다. 주제 테스트는 `scripts/perflab test 01-search-autocomplete-highlight`로 돌려 통과했다 (`Topic01SearchAutocompleteHighlightTests 통과`, exit 0).

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 0-1 | `Model.swift:15-18` | `NSRange`는 UTF-16 코드 단위를 세고, 영문과 완성형 한글은 한 글자가 UTF-16 하나라 오프셋이 글자 수와 같다 | ✅ 검증됨 | 문서: `NSString.h:6` "All lengths, character indexes, and ranges are expressed in terms of UTF–16 code units". 실험(`h/`): 5만 개 이름 전부 `name.count == name.utf16.count` | - |
| 0-2 | `Model.swift:22-24` | Swift 배열 힙 버퍼의 헤더는 32바이트다 | ✅ 검증됨 | 실험(`a/`): `[Range<Int>]`, `[UInt16]`, `[Int]` 모두 객체 주소에서 첫 원소까지 32바이트 | - |
| 0-3 | `Scenario.swift:9-22, 30, 58-69`, PLAN 시나리오 | `static let products`는 한 번만 생성된다. 단어 목록이 비어 있지 않아 `randomElement`가 nil이 아니다. 입력 스크립트는 62단계이고 결과 수는 213~22,238개다 | ✅ 검증됨 | 실험: `static let` 초기화 1회(`a/`), 스크립트 62단계, 최소 "미니 선" 213건, 최대 "a" 22,238건, "하하" 11,490건(`h/`). 테스트: `ScenarioTests.swift:scenarioIsDeterministic`, `productsHaveExpectedShape`, `typingScriptNarrowsAndWidens` | - |
| 0-4 | `Scenario.swift:26-27` | 이 범위에서는 `lowercased()`가 UTF-16 길이를 바꾸지 않는다 | ✅ 검증됨 | 테스트: `ScenarioTests.swift:lowercasingKeepsUTF16Length`. 실험(`h/`)에서도 5만 개 모두 같음 | - |
| 0-5 | `TypingPlayer.swift:7-9, 12-27` | k번째 입력을 `시작 + k × 100ms`에 넣고, 늦어도 건너뛰지 않는다 | ✅ 검증됨 | 코드: `TypingPlayer.swift:19-32` (`step`은 입력마다 1씩만 늘고 건너뛰는 분기가 없다). 실험(`a/`): 간격 계산식 결과 0.1초 | - |
| 0-6 | `TypingPlayer.swift:15` | `CACurrentMediaTime`은 display link의 timestamp와 같은 시계다 | ✅ 검증됨 | 문서: `CADisplayLink.h:53-56` "Mach host time converted to seconds", `CABase.h:124-125` "calling mach_absolute_time () and converting the units to seconds" | - |
| 0-7 | `TypingPlayer.swift:28-30` | 늦었을 때 `Task.yield()`로 한 번 양보하면 메인 스레드의 다른 작업이 끼어들 수 있다 | ✅ 검증됨 | 실험(`c/`, macOS 런루프): 메인 액터에서 10ms 바쁜 작업 + `Task.yield()`를 50번 반복하는 동안 다른 메인 액터 작업 54회, 5ms 타이머 50회, `beforeWaiting` 옵저버 89회가 실행됐다. iOS의 display link로 직접 확인한 것은 아니다 | - |
| 0-8 | `TypingPlayer.swift:10, 33-36`, PLAN `inputDelay` | `inputDelay`의 끝점은 "그 입력을 처리한 뒤 첫 프레임이 화면에 나갈 시각"이다 | ⚠️ 추정 | 시작점(예정 시각)과 단위는 코드로 확인된다. 끝점은 `PerfMonitor.swift:144`가 다음 tick의 `targetTimestamp`를 넘기는 값인데, 두 가지를 확인하지 못했다. (1) SwiftUI는 `setQuery`가 돌아온 뒤 `onChange`에서 거르므로, 그 처리와 CA 커밋이 다음 tick보다 앞선다는 보장. (2) 메인 스레드가 막혀 콜백이 늦게 올 때 `targetTimestamp`가 실제 표시 시각과 같은지. 확인 방법: `apply` 끝과 tick에 signpost를 남겨 Instruments에서 순서를 보거나, tick에서 `CACurrentMediaTime() - link.targetTimestamp`를 기록해 S0에서 양수(이미 지난 시각)가 나오는지 본다 | 실험(시뮬레이터 `exp/` E6, 입력 40회, onChange에서 60ms 사용): (1) onChange가 끝나기 전에 tick이 온 경우 0회 → 확인함. (2) tick의 `targetTimestamp`가 이미 과거인 경우 19회, 최대 57ms → **틀린 것으로 확인.** Shared `PerfMonitor.nextPresentation`을 추가해 지난 시각은 다음 프레임 경계로 올린다 (커밋 f519e5d, 단위 테스트 2건). PLAN `inputDelay` 설명 보완. 실기기 재측정 |
| 0-9 | `Stage0Search.swift:9` | `lowercased()`는 15바이트(UTF-8)를 넘으면 힙 메모리를 할당한다 (한글은 글자당 3바이트) | ✅ 검증됨 | 실험(`a/`): 15바이트("Orbit Ultra Pro", "가나다라마")는 small 문자열이고 malloc 증가 0. 16바이트 이상은 malloc 64바이트 증가. 시나리오 이름 5만 개는 전부 15바이트를 넘어(`h/`) 매번 할당한다 | - |
| 0-10 | `Stage0Search.swift:10` | `contains`는 Foundation이 제공하고, 유니코드 글자 경계를 따지며 비교해서 단순 바이트 비교보다 느리다 | ✅ 검증됨 | 실험(`b/`): `swiftc -dump-ast`(iOS 17 타깃)에서 `Foundation.(file).StringProtocol extension.contains`로 해석됨. 실험(`h/`): `"e\u{301}".contains("e")`가 false(글자 경계 인식). 5만 개에 대해 Foundation `contains`만 48.3ms, UTF-8 바이트 직접 비교는 배열 복사를 포함해 5.1ms | - |
| 0-11 | `Stage0Search.swift:14-17` | `range(of:options:range:)`는 `String.Index` 범위를 돌려주고, UTF-16 오프셋은 `distance`로 다시 세어 얻는다. 결과는 이름 안의 모든 일치 위치다 | ✅ 검증됨 | 실험(`a/`): 반환 타입 `Range<String.Index>`, "하하상회 하하 Speaker"에서 "SPEAKER"가 8..<15. 테스트: `ConsistencyTests.swift:stage0MatchesReference`(62단계 전부 기준 구현과 일치). 기준 구현은 `ranges(of:)`를 쓰는 다른 경로다 (`ConsistencyTests.swift:98-106`) | - |
| 0-12 | `Stage0Search.swift:31` | `MemoryLayout.stride`는 원소 하나가 차지하는 바이트 수이고, `String`은 내부 포인터 크기만 센다 | ✅ 검증됨 | 실험(`a/`): `Product` stride 24, `String` stride 16. 16바이트를 넘는 이름의 본문은 따로 할당된다(0-9) | - |
| 0-13 | `Stage0Search.swift:29-32`, PLAN `searchMemory` | `결과 수 × stride`가 결과 배열의 크기이고, 빠지는 것은 할당기 오버헤드뿐이다 | ❌ 틀림 | 실험(`h/`): `filter`는 `append`로 버퍼를 키워서 "하하" 결과가 count 11,490에 capacity 21,844다. 추정치 0.263MB, `malloc_size` 0.500MB로 약 1.9배 차이. S1의 `map` 결과는 추정 0.887MB에 실제 0.896MB로 거의 정확해서, S0만 절반가량 작게 잡힌다 | `Stage0Search.memory`와 `Stage2ResultStack.bytes`를 `count`가 아닌 `capacity` 기준으로 고침. PLAN `searchMemory` 계산법 수정. 실기기 재측정 |
| 0-14 | `Stage0ViewController.swift:4-5`, `Stage0View.swift:4-5` | 전략 머리말: 메인 스레드에서 `lowercased()` + `contains`로 거르고 셀(행)을 그릴 때 `range(of:options:)`로 강조한다 | ✅ 검증됨 | 코드: `Stage0ViewController.swift:85, 116`, `Stage0View.swift:54, 75`, `Stage0Search.swift:11, 20` | - |
| 0-15 | `Stage0ViewController.swift:12` | 재생 Task는 메인 액터에서 만들어져 메인 스레드에서 돈다 | ✅ 검증됨 | 실험(`c/`): `@MainActor` 메서드 안에서 만든 `Task { }`의 본문이 메인 스레드에서 실행됨 (`Task body on main: true`) | - |
| 0-16 | `Stage0ViewController.swift:77` | `editingChanged`는 코드로 `text`를 바꿀 때는 오지 않는다 | ✅ 검증됨 | 측정: 이벤트가 왔다면 UIKit 재생에서 입력마다 `submit`이 두 번 불려 앞의 것이 항상 취소되고 `skippedResults`가 50% 이상이어야 한다. `results/iPhone14,7/stage2-uikit.json`은 0, `results/iPhone18,1-simulator/stage1-uikit.json`은 13이다. SDK 헤더(`UIControl.h:32`)에는 설명이 없다 | - |
| 0-17 | `Stage0ViewController.swift:91` | `reloadData`는 모든 행 정보를 버리고 다시 묻고, 셀은 보이는 행만 만든다 | ✅ 검증됨 | 문서: `UITableView.h:437` "Reloads everything from scratch. Redisplays visible rows." | - |
| 0-18 | `Stage0ViewController.swift:82-101`, `Stage0View.swift:42-67` | 커스텀 지표를 PLAN 정의대로 기록한다. 측정 시작 때 지표가 초기화되므로 준비 비용 0을 매번 다시 남긴다 | ✅ 검증됨 | 코드: `filterTime`은 `search.filter`만 감싼다. `resultLatency`는 입력 시각부터 목록 데이터 적용 뒤까지. 초기화는 `TopicContainerView.swift:107`. 측정(iPhone14,7): `resultLatency − filterTime`이 UIKit 0.44ms, SwiftUI 3.58ms로 구간 정의와 맞는다 | - |
| 0-19 | `Stage0ViewController.swift:107, 144, 152-155` | `NSAttributedString` 구간은 UTF-16 `NSRange`다. `defaultContentConfiguration`은 iOS 14+다. `UIFont(descriptor:size: 0)`은 descriptor의 크기를 유지한다 | ✅ 검증됨 | 문서: `NSString.h:6`, `UITableViewCell.h:105` `API_AVAILABLE(ios(14.0))`, `UIFont.h:70` "If fontSize is greater than 0.0, it has precedence over UIFontDescriptorSizeAttribute". 실험(`a/`): `NSRange(0..<2)`가 `{0, 2}` | - |
| 0-20 | `Stage0ViewController.swift:15` | `UISearchTextField`는 돋보기 아이콘과 지우기 버튼이 있다 | ⚠️ 추정 | `UISearchTextField.h`에는 토큰 설명만 있고 아이콘, 지우기 버튼 언급이 없다. 확인 방법: 시뮬레이터에서 화면을 띄워 보거나 `clearButtonMode` 기본값을 출력한다 | 실험(`exp/` E7): `clearButtonMode` = whileEditing, `leftView` = UIImageView(항상 표시) 확인. 아이콘의 모양은 확인하지 않아 주석을 "왼쪽 아이콘과 지우기 버튼"으로 고침 |
| 0-21 | `Stage0View.swift:11` | 입력창의 `query`로 강조하면 결과가 바뀌기 전 갱신에서 옛 결과를 새 검색어로 강조하게 된다 | ⚠️ 추정 | `query`가 바뀐 뒤 `onChange`가 `results`를 바꾸기 전에 행 클로저가 실제로 다시 평가되는지 확인하지 못했다. 확인 방법: `appliedQuery`를 `query`로 바꾼 뒤 `highlightedName` 호출 수를 세거나 signpost `highlight` 개수를 비교한다 | 실험(`exp/` E2): 행이 `query`를 읽게 하면 행 평가 51회 중 18회가 옛 결과 + 새 검색어였다 → 확인함. 코드 유지 |
| 0-22 | `Stage0View.swift:26` | `List`는 보이는 행만 만드는 지연 목록이고, id를 이전과 비교해 바뀐 행을 찾는다 | ⚠️ 추정 | SDK의 `.swiftinterface`에는 문서 주석이 없어 확인하지 못했다. 확인 방법: 행 클로저에 카운터를 두어 결과 2만 건일 때 호출 수가 화면 행 수 수준인지 본다. id 비교 비용은 Instruments SwiftUI 템플릿으로 본다 | 실험(`exp/` E1): 결과 200 / 2,000 / 20,000개 모두 행 클로저 호출 31회 → "보이는 행만 만든다" 확인함. "id를 비교해 바뀐 행을 찾는다"는 확인하지 못해 `Stage0View`와 `Model.swift` 주석에서 뺌 |
| 0-23 | `Stage0View.swift:42` | `onChange`는 입력보다 늦게 실행되므로 입력 시각은 값이 바뀌는 순간에 잡는다 | ✅ 검증됨 | 측정(iPhone14,7): SwiftUI S0의 `resultLatency − filterTime`이 3.58ms로, 입력 시점에 바로 거르는 UIKit의 0.44ms보다 크다. 바인딩 set과 `onChange` 사이에 시간이 있다 | - |
| 0-24 | `Stage0View.swift:73, 76-79` | `AttributedString`은 iOS 15+이고 자기 인덱스만 받아서, UTF-16 오프셋을 `String.Index`를 거쳐 바꾼다 | ✅ 검증됨 | 문서: Foundation `.swiftinterface:907` `@available(... iOS 15 ...)`. 실험(`a/`): `String.Index(utf16Offset:in:)` → `Range(_:in: text)`로 "하하상회 하하 Speaker"의 5..<7이 "하하"로 나온다 | - |
| 0-25 | PLAN 가설 1, S0 전략 | 입력마다 메인 스레드가 거르기에 묶여 입력 표시와 그리기가 밀린다 | ✅ 검증됨 | 측정(iPhone14,7, UIKit / SwiftUI): `filterTime` 65.50 / 69.32ms, `inputDelay` 85.87 / 161.30ms, hitch 533.7 / 800.6ms/s, FPS avg 27.3 / 11.6. 실험(`h/`, Mac): S0 방식 한 번 77.5ms 중 `lowercased()` 29.9ms, `contains` 48.3ms | - |

#### 불필요하거나 설명되지 않는 코드
- `Stage0ViewController.swift:125` `[weak self]`: 이유가 적혀 있지 않다. `viewDidDisappear`가 `playback`을 취소하므로 강한 참조여도 순환은 취소 때 끊긴다. 반대로 `viewDidDisappear` 없이 해제되면, 약한 참조인 지금은 재생 루프가 끝나지 않고 `inputDelay`만 계속 기록한다. S1, S2의 같은 코드도 해당한다.

- **조치:** `playback`의 `[weak self]`는 유지하고 이유를 주석으로 적음 (끝나지 않는 루프라 취소를 놓치면 화면이 해제되지 않는다). S1, S2도 같다.

#### 사용자에게 짚어 줄 것
- **0-13**: `filter`가 돌려준 배열은 원소 수만큼만 메모리를 쓰지 않는다. `append`로 자라는 배열은 용량을 약 2배씩 늘려서 "하하" 결과는 실제 버퍼가 추정의 1.9배였다. `map`은 개수를 미리 알아 딱 맞게 잡는다. 같은 `count × stride` 식이라도 배열을 만든 방법에 따라 정확도가 달라진다.
- **0-10**: `import Foundation`이 있으면 `String.contains(String)`은 표준 라이브러리가 아니라 Foundation 구현으로 연결된다. 5만 개 기준으로 바이트 비교보다 약 9배 느렸고, 이것이 S2에서 UTF-16 배열 비교로 바꾼 효과의 출처다.

### [Stage 1] 동시성 주장은 실험으로 확인됐지만, `filterTime`과 `searchMemory` 평균은 빨리 끝난 검색만 담는다 (2026-10-11)

- 대상: `docs/PLAN.md`, `Search/Stage1/Stage1Search.swift`, `UIKit/Stage1ViewController.swift`, `SwiftUI/Stage1View.swift`, `Tests/ConsistencyTests.swift`, `results/iPhone14,7/stage1-*.json`, `results/iPhone18,1-simulator/stage1-*.json`, `Packages/Topics/Package.swift`, 변경 대조용으로 Stage 0 파일
- 판정: ✅ 11건 · ⚠️ 2건 · ❌ 2건

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 1-1 | `Stage1Search.swift:5, 66` | Stage 0과 같은 거르기와 위치 계산을 한다 | ✅ 검증됨 | 실험: `Stage0Search.swift:15-27`과 `Stage1Search.swift:67-79`의 `diff`가 비어 있다. 거르기 식도 같다(`:54`). 테스트: `ConsistencyTests.swift:stage1MatchesReference` | - |
| 1-2 | `Stage1Search.swift:7`, `Model.swift:6` | 상수만 담은 struct라 `Sendable`이 자동으로 인정된다 | ✅ 검증됨 | 테스트: Swift 6 모드(`project.pbxproj` `SWIFT_VERSION = 6.0`, `Package.swift` tools 6.0)에서 테스트 타깃이 빌드되고 통과했다. 하니스(`h/`)도 `-swift-version 6`으로 오류 없이 빌드됨 | - |
| 1-3 | `Stage1Search.swift:29` | 취소되면 `CancellationError`를 던지고 중간에 멈춘다 | ✅ 검증됨 | 테스트: `ConsistencyTests.swift:stage1StopsWhenCancelled`. 실험(`c/`): 계산 도중 20ms 뒤에 취소해도 `try? await`가 nil로 돌아왔다 | - |
| 1-4 | `Stage1Search.swift:31-32` | `@concurrent` 함수는 부른 쪽이 메인 액터여도 메인이 아닌 스레드에서 실행된다 | ✅ 검증됨 | 실험(`c/`): `@concurrent func on main: false`. 단, 지금 설정에서는 속성이 없어도 결과가 같다 (아래 "불필요하거나 설명되지 않는 코드") | - |
| 1-5 | `Stage1Search.swift:49-51` | 취소 확인은 플래그 하나를 읽는 정도의 비용이고, `filter`와 `map`은 rethrows라 클로저가 던지면 멈춘다 | ✅ 검증됨 | 실험(`h/`, Mac): `Task.checkCancellation()` 22.7ns/회, 5만 회에 1.13ms로 S1 검색 한 번(평균 89.5ms)의 약 1%. 문자 그대로 플래그 하나는 아니고 현재 Task 조회를 포함한다. rethrows는 1-3 테스트로 확인 | - |
| 1-6 | `Stage1Search.swift:23, 40-42` | `memory`는 결과 배열 + 행마다의 일치 위치 배열(헤더 포함) 크기 추정치다 | ✅ 검증됨 | 실험(`a/`): `Row` stride 32, `Range<Int>` stride 16, 헤더 32. 실험(`h/`): "하하" 11,490행에서 추정 0.887MB, `malloc_size` 합 0.896MB (1% 차이) | - |
| 1-7 | `Stage1ViewController.swift:4-6`, `Stage1View.swift:4-6` | 전략과 변경: 거르기와 결과 전체의 위치 계산을 백그라운드 Task로 옮기고, 새 입력이 오면 이전 Task를 취소한다. 셀은 계산된 위치만 쓴다 | ✅ 검증됨 | 코드: `Stage1Search.swift:33-63`, `Stage1ViewController.swift:82-96, 126`, `Stage1View.swift:54-66, 88`. S0과 대조해 머리말에 없는 로직 변경은 없다 (SwiftUI의 `appliedQuery` 제거는 행이 위치를 들고 다니게 된 결과다) | - |
| 1-8 | `Stage1ViewController.swift:87`, `Stage1View.swift:58` | `Task { }` 본문은 메인 액터에서 돌고, `@concurrent` 함수만 백그라운드로 간다 | ✅ 검증됨 | 실험(`c/`): `Task body on main: true`, `@concurrent func on main: false`, `after await back on main: true` | - |
| 1-9 | `Stage1ViewController.swift:92-93`, `Stage1View.swift:63` | 취소는 메인 액터의 `submit`에서만 일어나므로, 돌아온 뒤 취소되지 않았다면 최신 검색어의 결과다 | ✅ 검증됨 | 코드: `searchTask`는 `apply`에서만 nil이 되고(`:100`), `submit`은 nil이 아니면 항상 취소한다(`:82-85`). 취소되지 않은 Task는 많아야 하나다. 메인 복귀는 1-8 실험. 이 순서 보장을 직접 검사하는 테스트는 없다 | - |
| 1-10 | `Stage1ViewController.swift:90`, `Stage1View.swift:61` | `filterTime`을 취소 확인보다 먼저 기록하므로, 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠지지 않는다 | ❌ 틀림 | 코드: 계산 도중 취소된 검색은 `checkCancellation`이 던져 `try?`가 nil이 되고 `:89`에서 돌아가므로 기록 줄에 닿지 않는다. 실험(`c/`): 도중 취소 뒤 기록 횟수 0. 기록되는 것은 계산을 끝낸 뒤 메인 복귀 사이에 취소된 좁은 경우뿐이다. 측정(iPhone14,7 UIKit): S1 65.28ms가 S0 65.50ms와 같은데, Mac(`h/`)에서 전 단계를 다 돌리면 S1이 S0의 1.41배(89.50 / 63.45ms)다. `skippedResults` 52%인 실기기에서는 느린 검색이 평균에서 빠졌다 (Mac에서 빠른 절반만 평균하면 59.85ms) | 주석을 사실대로 고침 (UIKit/SwiftUI S1, S2 네 곳): 계산을 끝낸 검색만 기록되고, 도중 취소된 검색은 평균에서 빠진다. PLAN 측정 지표에 같은 내용 추가 |
| 1-11 | `Stage1ViewController.swift:82-85, 107-112`, `Stage1View.swift:54-56, 75-80` | `resultLatency`는 적용된 결과만 평균한다. `skippedResults`는 밀려난 검색어에 100, 적용된 검색어에 0을 남긴다. `indexBuildTime`은 0이다 | ✅ 검증됨 | 코드: 100은 진행 중인 Task가 있을 때 `submit`에서, 0은 `apply`에서 한 번씩 남는다. 검색어마다 둘 중 하나만 기록된다. PLAN의 측정 위치, 의미와 같다 | - |
| 1-12 | `Stage1ViewController.swift:110`, `Stage1View.swift:78`, PLAN `searchMemory` | S1의 `searchMemory` 평균이 S0, S2와 같은 검색어 집합의 크기를 나타낸다 (대가 비교의 전제) | ❌ 틀림 | 기록 위치는 PLAN대로 "적용할 때"다. 그러나 결과가 큰 검색어일수록 오래 걸려 밀려난다. 측정: 같은 코드, 같은 데이터인데 iPhone14,7은 0.139 / 0.142MB, 시뮬레이터는 0.332 / 0.315MB다. 실험(`h/`): 62단계 전부의 평균은 0.449MB(S0의 3.45배)이고, 빠른 절반만 평균하면 0.135MB로 실기기 값과 같다. 실기기의 "S0 0.13 → S1 0.14"는 대가를 약 3배 작게 보여 준다 | 취소가 있는 한 구조적으로 피할 수 없어 코드는 두고 한계를 문서에 밝힘: PLAN 측정 지표에 "살아남은 검색만의 평균" 명시, RESULTS 대가 표와 분석에서 S1 `searchMemory`를 S0과 직접 비교하지 않고 이 실험값(Mac 전 단계 0.449MB, 참고용)을 함께 적음 |
| 1-13 | `Stage1View.swift:13-14` | `.task(id: query)`도 이전 작업을 자동으로 취소하지만, 화면이 나타날 때 빈 검색어로 한 번 돌고 밀려난 검색어를 셀 시점이 없다 | ⚠️ 추정 | SDK `.swiftinterface`에 문서 주석이 없어 확인하지 못했다. 확인 방법: `.task(id:)`로 바꾼 작은 화면에서 본문 진입과 `Task.isCancelled`를 출력해 본다 | 실험(`exp/` E3): 나타날 때 빈 id로 한 번 시작하고, id가 바뀔 때마다 이전 작업이 취소됨 → 확인함. 코드 유지 |
| 1-14 | `Stage1View.swift:106-110` | `@State`에 Task를 바로 두면 body를 다시 계산할 수 있고, 참조 타입 안의 프로퍼티는 SwiftUI가 관찰하지 않는다 | ⚠️ 추정 | `searchTask`는 `body` 평가 중에 읽히지 않는다 (`onDisappear` 클로저 안에서만 읽음). body에서 읽지 않는 `@State`를 바꿀 때 body가 다시 계산되는지 확인하지 못했다. 확인 방법: 상자를 없애고 `@State var searchTask: Task<Void, Never>?`로 바꾼 뒤 `Self._printChanges()`로 재계산 여부를 본다. 재계산되지 않으면 상자는 필요 없다 | 실험(`exp/` E4): body가 읽지 않는 `@State`를 20번 바꿔도 body 재계산 0회 → **주석이 틀렸고 상자는 불필요.** `SearchTaskBox`를 지우고 `@State private var searchTask: Task<Void, Never>?`로 바꿈 |
| 1-15 | PLAN S1 기대 효과와 대가 | `inputDelay`가 크게 줄고 입력이 밀리지 않는다. CPU는 오히려 늘 수 있다 | ✅ 검증됨 | 측정(iPhone14,7, UIKit / SwiftUI): `inputDelay` 85.87 → 31.81ms / 161.30 → 27.91ms, hitch 533.7 → 0 / 800.6 → 0ms/s, CPU avg 71.2 → 86.6% / 90.9 → 87.3%. 원인은 거르기가 메인 스레드를 떠난 것이다(1-8) | - |

#### 불필요하거나 설명되지 않는 코드
- `Stage1Search.swift:33` `@concurrent` (S2의 `Stage2Index.swift:20`, `Stage2Search.swift:15` 포함): 지금 설정에서는 없애도 동작이 같다. 실험(`c/`)에서 속성 없는 nonisolated async 함수도 메인 밖에서 실행됐다 (`plain nonisolated async func on main: false`). `Package.swift`와 `project.pbxproj`에 `NonisolatedNonsendingByDefault` 설정이 없다. 이 기능을 켜면 속성 없는 함수는 메인에서 돈다(`-enable-upcoming-feature`로 확인: `true`). 주석은 "이 속성 덕분에 백그라운드로 간다"로 읽히지만, 실제 역할은 그 설정이 켜져도 동작을 지키는 것이다.
- `Stage1ViewController.swift:88` `[weak self, search]`: `weak`의 이유가 적혀 있지 않다. Task는 검색 한 번이면 끝나므로 강한 참조여도 누수는 없다. 화면이 사라진 뒤 결과를 적용하지 않으려는 의도라면 `viewDidDisappear`의 `searchTask?.cancel()`이 이미 그 일을 한다.

- **조치:** `@concurrent`는 유지하고 주석을 실제 역할로 고침 (지금은 없어도 동작이 같고, 기본값이 바뀌어도 백그라운드 실행을 지키려는 선언). `searchTask`의 `[weak self]`는 지움 (검색 한 번이면 끝나는 Task).

#### 사용자에게 짚어 줄 것
- **1-10, 1-12 (생존 편향)**: 취소가 있는 Stage에서는 평균에 들어가는 표본이 "끝까지 살아남은 검색"으로 바뀐다. 실기기 S1의 `filterTime` 65.3ms와 `searchMemory` 0.14MB는 100ms 안에 끝난 검색어만의 값이다. "S1은 계산량이 S0과 같다"와 "메모리가 거의 안 늘었다"는 이 표로는 말할 수 없고, 전 단계를 다 돌리면 계산은 1.4배, 메모리 추정은 3.4배다 (Mac 실험).
- **1-4 (`@concurrent`의 실제 역할)**: Swift 6.2 기본 설정에서 nonisolated async 함수는 원래 메인 액터를 떠난다. `@concurrent`는 지금 동작을 바꾸는 속성이 아니라, 기본값이 "호출한 액터에서 실행"으로 바뀌어도 백그라운드 실행을 유지한다는 선언이다.

### [Stage 2] 인덱스, 증분 검색, 스택의 주장은 테스트와 실험으로 확인됐고, 변경 머리말에 위치 계산 알고리즘 교체가 빠져 있다 (2026-10-11)

- 대상: `docs/PLAN.md`, `Search/Stage2/Stage2Index.swift`, `Search/Stage2/Stage2ResultStack.swift`, `Search/Stage2/Stage2Search.swift`, `UIKit/Stage2ViewController.swift`, `SwiftUI/Stage2View.swift`, `Tests/ConsistencyTests.swift`, `results/iPhone14,7/stage2-*.json`, `results/iPhone18,1-simulator/stage2-*.json`, 변경 대조용으로 Stage 1 파일
- 판정: ✅ 16건 · ⚠️ 3건 · ❌ 2건

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| 2-1 | `Stage2Index.swift:6-8, 25` | S0, S1은 입력마다 5만 개 이름을 소문자로 새로 만든다. 소문자 UTF-16 배열의 위치는 원래 이름의 위치와 같고 `NSRange`와 같은 단위다 | ✅ 검증됨 | 코드: `Stage0Search.swift:11`, `Stage1Search.swift:54`. 테스트: `ScenarioTests.swift:lowercasingKeepsUTF16Length`, `ConsistencyTests.swift:stage2MatchesReference`. 문서: `NSString.h:6` | - |
| 2-2 | `Stage2Index.swift:14, 27-28` | 인덱스 크기는 이름마다 `참조 + 헤더 32 + UTF-16 단위 × 2바이트`다 | ✅ 검증됨 | 실험(`a/`): `[UInt16]` stride 8, `UInt16` stride 2, 헤더 32. 실험(`h/`): 추정 3.655MB, `malloc_size` 합 4.004MB. 9% 차이는 malloc의 16바이트 올림이고 PLAN이 밝힌 "할당기 오버헤드"에 해당한다 | - |
| 2-3 | `Stage2Index.swift:19`, `Stage2ViewController.swift:43` | 인덱스 생성은 `@concurrent`라 메인 밖에서 돌고, 화면이 먼저 그려진다. warm-up 중에 끝난다 | ✅ 검증됨 | 실험(`c/`): `@concurrent` 함수는 메인 밖에서 실행(1-4와 같은 실험). 측정: `indexBuildTime` iPhone14,7 42.75 / 37.54ms, 시뮬레이터 25.15 / 24.46ms로 warm-up 2초보다 훨씬 짧다 | - |
| 2-4 | `Stage2Index.swift:40` | 첫 코드 단위가 다르면 나머지를 비교하지 않고, 대부분의 위치가 여기서 걸러진다 | ✅ 검증됨 | 실험(`h/`): 스크립트의 서로 다른 검색어 전부로 5만 개 이름의 모든 시작 위치 25,546,465곳을 세면 첫 코드 단위가 같은 곳은 474,547곳(1.9%)이다. 98.1%가 첫 비교에서 걸러진다 | - |
| 2-5 | `Stage2Index.swift:49`, `Stage2ViewController.swift:5, 148` | 일치 위치는 결과 전체가 아니라 셀을 만들 때만 구한다 | ✅ 검증됨 | 코드: `highlights(at:query:)`는 `highlightedName`에서만 불리고, 이것은 `cellForRowAt`에서만 불린다(`:177`). `Stage2Search.swift`에는 위치 계산이 없다. UIKit이 보이는 행만 셀을 만드는 것은 0-17 문서 | - |
| 2-6 | `Stage2View.swift:5` | SwiftUI도 일치 위치를 보이는 행만 구한다 | ⚠️ 추정 | `List`가 보이는 행의 클로저만 평가한다는 전제(0-22)에 달려 있고 확인하지 못했다. 확인 방법: `highlightedName(at:)` 호출 수를 세어 결과 2만 건일 때 화면 행 수 수준인지 본다 | 실험(`exp/` E1): 0-22와 같은 실험으로 확인함. 코드 유지 |
| 2-7 | `Stage2ResultStack.swift:1-5, 29-37, 41-47` | 아래 항목의 검색어는 항상 위 항목의 검색어에 포함된다. 글자를 더하면 위 항목 결과 안에서만 거르고, 지우면 꺼내고 같은 검색어는 다시 쓴다. 건너뛴 검색어가 있어도 결과가 같다 | ✅ 검증됨 | 테스트: `ConsistencyTests.swift:stage2MatchesReference`(62단계 순서대로), `stage2SkippingQueriesKeepsResults`. 코드: `push`는 `apply`에서만 불리고, 그 사이 다른 `plan`이 끼면 해당 Task는 취소되어 `apply`에 닿지 않는다. 실험(`h/`): 62단계 경로가 full 8, narrow 23, reuse 23, 빈 검색어 8로 PLAN과 같다 | - |
| 2-8 | `Stage2ResultStack.swift:5, 26, 49-52` | 스택은 값 타입이라 잠금이 필요 없다. 크기는 항목마다 배열 두 개의 헤더 + 원소 수 × stride다 | ✅ 검증됨 | 코드: 스택은 화면의 프로퍼티이고 백그라운드로는 `Plan`(Sendable)만 넘어간다. 실험(`h/`): "a" 항목(22,238건)에서 추정 0.170MB, `malloc_size` 0.188MB. `filter` 결과라 용량이 count보다 10% 크다(0-13과 같은 원인, 영향은 작다). 항목 튜플 자체(16바이트)와 `entries` 버퍼는 세지 않는다 | - |
| 2-9 | `Stage2Search.swift:10, 14, 17` | 스택 결과를 다시 쓰면 거의 0이다. 취소되면 `CancellationError`를 던진다. 경로를 signpost에 남긴다 | ✅ 검증됨 | 코드: `.reuse`는 배열을 그대로 돌려준다(`:23-24`). 테스트: `ConsistencyTests.swift:stage2StopsWhenCancelled`(full 경로). 실험(`h/`, Mac): 62단계 평균 `filterTime` 0.471ms. `.reuse` 경로는 취소를 확인하지 않지만 화면이 `Task.isCancelled`로 거른다 | - |
| 2-10 | `Stage2ViewController.swift:6-7`, `Stage2View.swift:6-7` | 변경 머리말이 Stage 1에서 바뀐 것을 모두 적었다 | ❌ 틀림 | 코드에 있지만 머리말에 없는 변경: 일치 위치를 구하는 방법이 `range(of:options: .caseInsensitive)` + `utf16.distance`(`Stage1Search.swift:72-74`)에서 UTF-16 배열 직접 비교(`Stage2Index.swift:35-58`)로 바뀌었다. 머리말은 계산 시점(지연)만 적었다. PLAN의 핵심 개념 "UTF-16 오프셋 직접 계산"이 이 변경이다. 그 밖에 SwiftUI `List`의 id가 `Row.id`에서 위치 값으로 바뀌었다 | UIKit/SwiftUI S2의 `// 변경:`에 일치 위치 계산 방식 교체(`range(of:)` + `String.Index` → UTF-16 배열 직접 비교)를 추가. SwiftUI에는 행 id가 위치 값으로 바뀐 것도 적음 |
| 2-11 | `Stage2ViewController.swift:4-7`, `Stage2View.swift:4-7` | 전략과 변경에 적힌 내용이 코드에 있다: 인덱스, 증분 검색과 스택, 지연 계산, 검색어 소문자 변환 1회, 결과가 위치 배열, S1의 백그라운드 + 취소 유지 | ✅ 검증됨 | 코드: `Stage2ViewController.swift:44, 100, 102, 103-113, 121`, `Stage2Search.swift:22-29`, `Stage2View.swift:65-77` | - |
| 2-12 | `Stage2ViewController.swift:99, 101, 109-110`, `Stage2View.swift:64, 66, 74` | 검색어 소문자 변환은 입력마다 한 번이다. 스택은 메인 액터만 바꾼다. 취소되지 않았다면 최신 검색어의 결과다 | ✅ 검증됨 | 코드: `:100`에서 한 번 변환, `stack`은 `submit`과 `apply`(둘 다 메인 액터)에서만 바뀐다. 순서 보장은 1-9와 같은 구조다 | - |
| 2-13 | `Stage2ViewController.swift:104`, `Stage2View.swift:69` | `Task.value`는 작업이 끝날 때까지 기다리고, 이미 끝났으면 바로 돌려준다 | ✅ 검증됨 | 실험(`c/`): 끝난 Task의 `value`를 다시 읽는 데 39.6µs | - |
| 2-14 | `Stage2ViewController.swift:107`, `Stage2View.swift:72` | `filterTime`을 취소 확인보다 먼저 기록하므로 오래 걸려 밀리기 쉬운 검색어가 평균에서 빠지지 않는다 | ❌ 틀림 | 1-10과 같은 구조다. 계산 도중 취소되면 `Stage2Search.swift:40`이 던져 `:106`에서 돌아가고 기록되지 않는다. 다만 측정된 S2는 `skippedResults`가 네 결과 모두 0이라 이번 수치에는 영향이 없다 | 1-10과 함께 주석을 고침 |
| 2-15 | `Stage2ViewController.swift:130`, `Stage2View.swift:93` | 현재 결과는 스택 맨 위 항목과 같은 배열을 공유하므로 스택 크기에 이미 들어 있다 | ✅ 검증됨 | 실험(`h/`): reuse 경로 23번 모두 반환된 배열의 버퍼 주소가 스택 항목과 같다. 코드: full, narrow는 `apply`에서 같은 배열 값을 `push`하고 `positions`에 넣는다(`:118, 121`). 빈 검색어는 결과와 스택이 모두 비어 있다 | - |
| 2-16 | `Stage2ViewController.swift:127-133`, `Stage2View.swift:90-96`, `Stage2Index.swift:22, 31` | 커스텀 지표를 PLAN 정의대로 기록한다: `searchMemory` = 인덱스 + 스택, `indexBuildTime` = 생성 시작 → 끝, `filterTime`은 경로가 섞인 평균 | ✅ 검증됨 | 코드: 위 줄. 측정: `searchMemory` 3.793MB(iPhone14,7)가 실험(`h/`)의 62단계 평균 3.783MB(인덱스 3.655MB + 스택)와 맞는다 | - |
| 2-17 | `Stage2ViewController.swift:147`, `Stage2View.swift:31` | 인덱스의 위치를 `NSRange`로 바로 쓴다. 위치 값이 서로 달라 행의 id로 쓸 수 있다 | ✅ 검증됨 | 테스트: `stage2MatchesReference`(위치가 기준 구현과 일치). 코드: `positions`는 `names.indices` 또는 그 부분집합을 `filter`한 것이라 중복이 없다 | - |
| 2-18 | `Stage2View.swift:84` | 행이 읽는 인덱스를 결과(`@State`)보다 먼저 넣어야 다시 그릴 때 함께 보인다 | ⚠️ 추정 | 두 대입은 같은 동기 함수 안에 있다. `@State` 대입이 그 자리에서 body를 다시 부르지 않는다면 순서는 상관없다. 순서가 필요하다는 근거를 확인하지 못했다. 확인 방법: 두 줄의 순서를 바꾸고 첫 결과의 강조가 그대로 나오는지 본다 | 실험(`exp/` E5): 상자 값과 `@State`의 대입 순서를 바꿔도 행이 본 값이 같다 → 순서는 필요 없음. "먼저 넣어야 한다"는 주석을 지우고 실제 동작(상자 값은 화면을 다시 그리지 않고, 결과가 바뀔 때 함께 읽힌다)으로 고침 |
| 2-19 | `Stage2View.swift:17, 122-125` | 검색 상태를 `@State`에 바로 두면 body를 다시 계산할 수 있어 참조 타입 상자에 둔다 | ⚠️ 추정 | 1-14와 같다. 상자의 프로퍼티 중 `index`만 `body` 평가 중(행 클로저)에 읽힌다. 확인 방법: `Self._printChanges()`로 상자 없이 재계산이 늘어나는지 본다 | 실험(`exp/` E4): 읽지 않는 `@State`는 body를 다시 계산하지 않는다 → 주석의 이유가 틀림. 상자를 두는 실제 이유(인덱스 생성을 `lazy`로 한 번만 시작하려면 참조 타입이 필요, 근거 2-20)로 주석을 다시 씀 |
| 2-20 | `Stage2View.swift:133` | `@State`의 초기값은 뷰가 다시 만들어질 때마다 평가된다 | ✅ 검증됨 | 문서: SwiftUICore `.swiftinterface:15939` `public init(wrappedValue value: Value)`는 autoclosure가 아니다. autoclosure 버전은 `Value : Observable`일 때만이고 `SearchState`는 해당하지 않는다. 따라서 `SearchState()`는 뷰 init마다 실행된다 | - |
| 2-21 | PLAN S2 기대 효과와 대가 | `filterTime`과 CPU가 크게 줄고 `resultLatency`도 준다. 대가는 인덱스와 스택 메모리, 인덱스 생성 시간이다 | ✅ 검증됨 | 측정(iPhone14,7, UIKit / SwiftUI, S1 → S2): `filterTime` 65.28 → 1.69ms / 64.59 → 0.85ms, CPU avg 86.6 → 29.9% / 87.3 → 37.1%, `resultLatency` 65.59 → 5.12ms / 66.05 → 8.44ms, `searchMemory` 3.79MB, Memory peak 35.0 → 41.2MB / 35.8 → 50.9MB. S1 쪽 값은 1-10, 1-12의 편향이 있어 실제 차이는 더 크다. 원인 경로: 0-10(Foundation `contains` 제거), 2-4, 2-7 | - |

#### 불필요하거나 설명되지 않는 코드
- `Stage2ViewController.swift:94` `guard let indexTask else { return }`: 도달할 수 없다. `indexTask`는 `viewDidLoad`(`:44`)에서 입력이 가능해지기 전에 항상 대입된다. `Stage2View.swift:59`도 `.task`에서 `buildIndex`를 부른 뒤에야 재생이 시작된다. 이 분기에 닿는다면 그 입력은 검색 없이 버려지고 지표에도 남지 않는다.
- `Stage2Index.swift:36`의 `name.count >= query.count`: 없어도 결과가 같다. 이름이 더 짧으면 `:39`의 반복 조건이 처음부터 거짓이라 nil을 돌려준다 (실험 `h/`: 길이 1 이름에 길이 3 검색어 → nil, 반복 상한 -2).
- `Stage2ViewController.swift:103` `[weak self]`: 1번 Stage와 같이 이유가 적혀 있지 않다.
- `@concurrent` 두 곳(`Stage2Index.swift:20`, `Stage2Search.swift:15`): Stage 1 항목 참고.

- **조치:** 도달할 수 없는 `guard let indexTask`를 없앰. UIKit은 `indexTask`를 `let` 프로퍼티로, SwiftUI는 상자의 `lazy var`로 바꿔 옵셔널이 아니게 함. `firstMatch`의 길이 비교를 지우고 이유를 주석으로 적음. `searchTask`의 `[weak self]`를 지움. `@concurrent` 주석은 Stage 1을 가리키게 고침.

#### 사용자에게 짚어 줄 것
- **2-4**: 직접 짠 부분 문자열 검색이 빠른 이유가 숫자로 확인됐다. 시작 위치의 98.1%가 첫 코드 단위 비교 한 번으로 끝난다. 반대로 한 글자만 반복되는 데이터라면 이 가정이 깨진다.
- **2-10**: S2의 하이라이트는 "언제 계산하나"(지연)뿐 아니라 "어떻게 계산하나"(`String.Index` → UTF-16 배열)도 바뀌었다. 머리말에는 앞의 것만 있어서, S1과 S2의 `highlight` signpost를 비교할 때 두 변경의 효과가 섞여 있다는 점을 놓치기 쉽다.

### [재검증] 조치한 코드와 주석은 실험으로 확인됐고, 재측정과 RESULTS 반영이 아직 남아 있다 (2026-10-11)

- 대상: `scratchpad/verify/changes.diff`, 현재의 `Model.swift`, `Search/Stage0/Stage0Search.swift`, `Search/Stage1/Stage1Search.swift`, `Search/Stage2/Stage2Index.swift`, `Search/Stage2/Stage2ResultStack.swift`, `UIKit/Stage{0,1,2}ViewController.swift`, `SwiftUI/Stage{0,1,2}View.swift`, `docs/PLAN.md`(측정 지표), `docs/VERIFICATION.md`(조치 열), `docs/RESULTS.md`, `results/*/stage*.json`, Shared `Metrics/PerfMonitor.swift`와 `Tests/SharedTests/SharedTests.swift`(커밋 f519e5d), `scratchpad/verify/exp-simulator.swift`
- 판정: ✅ 21건 · ⚠️ 3건 · ❌ 1건
- 실험 환경: Mac(arm64), Swift 6.2.1. `h2/`는 바뀐 주제 소스 사본으로 다시 만든 하니스, `c/`는 앞선 검증의 동시성 실험, `d/`는 타입 검사, `sim/`은 `exp-simulator.swift`를 그대로 빌드해 iPhone 17 시뮬레이터(iOS 26.1)에서 직접 다시 돌린 것이다 (E1~E7 출력 확보). 테스트는 `scripts/perflab test 01-search-autocomplete-highlight` 통과(exit 0), `xcodebuild test -scheme Shared` 통과(6건, `PerfMonitorTests` 2건 포함).

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| R-1 | `Stage0Search.swift:31-34` | `filter` 결과는 capacity가 count보다 최대 2배쯤 크고("하하": count 11,490, capacity 21,844), capacity × stride가 결과 배열 크기다 (0-13 조치) | ✅ 검증됨 | 실험(`h/`): "하하" count 11,490, capacity 21,844. 실험(`h2/`): 62단계 평균 추정 0.212MB, `malloc_size` 0.212MB로 일치. 0-13은 코드에서 해결됐다 | - |
| R-2 | `Stage2ResultStack.swift:26, 49-53` | 스택 크기를 capacity 기준으로 세고, Stage 0과 같은 기준이다 | ✅ 검증됨 | 실험(`h2/`): "a" 항목 추정 196,656바이트, `malloc_size` 196,656바이트로 일치. 스크립트를 두 바퀴 돈 뒤 빈 검색어에서 `stack.bytes`가 0으로 돌아와 push와 pop의 계산이 대칭이다 | - |
| R-3 | PLAN 측정 지표 `searchMemory` | 개수에 맞춰 만든 배열(S1의 `map` 결과, S2 인덱스)은 원소 수로 세어도 된다 | ✅ 검증됨 | 실험(`h2/`): S1 62단계 평균 추정 0.449MB, `malloc_size` 0.458MB (2% 차이). 행마다의 일치 위치 배열은 `append`로 만들지만 3개 이상인 행이 "a"에서 22,238행 중 504행뿐이라 영향이 작다. 인덱스는 앞선 2-2(9% 차이, malloc 올림) 그대로 | - |
| R-4 | VERIFICATION 0-8, 0-13 조치 "실기기 재측정" | 바뀐 계산식과 끝점으로 다시 측정했다 | ⚠️ 추정 | 아직 수행되지 않았다. `results/iPhone14,7/*.json`의 날짜는 2026-10-11T11:40~11:43Z로 변경 이전이고 `git status`에 results와 RESULTS.md 변경이 없다. 지금 results의 S0 `searchMemory` 0.134 / 0.136MB는 count 기준 값이고, 현재 코드로는 Mac 62단계 평균이 0.212MB다(`h2/`). S2도 3.793 → 약 3.87MB로 달라진다. S0 `inputDelay`도 옛 끝점 값이다. 확인 방법: `scripts/perflab measure`로 다시 재고 `scripts/perflab table`로 표를 갱신한다 | 지문을 기록한 직후 같은 코드로 실기기를 재측정함 (`results/iPhone14,7/`, 2026-10-11). RESULTS.md 수치를 새 결과로 다시 씀 |
| R-5 | `Stage1Search.swift:31-34` | 지금 설정에서는 `@concurrent`가 없어도 메인 밖에서 돌고, `NonisolatedNonsendingByDefault`를 켜도 백그라운드 실행을 지키려고 명시한다 | ✅ 검증됨 | 실험(`c/`): 속성 없는 nonisolated async 함수 `on main: false`, 기능을 켜면 `true`, `@concurrent`는 두 경우 모두 `false`. 저장소에 해당 설정 없음 | - |
| R-6 | `Stage2Index.swift:19` | 인덱스 생성은 메인이 아닌 공용 스레드 풀에서 실행된다 (`@concurrent` 설명은 Stage 1 참고) | ✅ 검증됨 | R-5와 같은 실험. 가리키는 주석이 `Stage1Search.swift:31-34`에 있다 | - |
| R-7 | `Stage2Index.swift:36-39` | 이름이 검색어보다 짧으면 상한이 음수라 한 번도 돌지 않으므로 길이 비교 guard가 필요 없다 | ✅ 검증됨 | 실험(`h2/`): 길이 1과 길이 0 이름에 길이 3 검색어 → nil, 정상 경우는 그대로 찾는다. 테스트: `ConsistencyTests.swift:stage2MatchesReference`, `stage2SkippingQueriesKeepsResults` 통과 (지울 때 `plan`이 더 짧은 검색어로 이 경로를 탄다) | - |
| R-8 | `Stage0View.swift:26`, `Model.swift:5` | `List`는 결과가 2만 개여도 행 클로저를 화면에 보이는 만큼만 부른다. `List`는 `id`로 행을 구분한다 | ✅ 검증됨 | 실험(`sim/` E1, 직접 재실행): 결과 200 / 2,000 / 20,000개 모두 행 클로저 호출 31회. 확인하지 못한 "id 비교" 문장은 두 파일에서 빠졌다. 0-22, 2-6 해결 | - |
| R-9 | `Stage0View.swift:11` (0-21 조치) | 행이 입력창의 `query`를 읽으면 옛 결과를 새 검색어로 강조하는 평가가 생긴다 | ✅ 검증됨 | 실험(`sim/` E2, 직접 재실행): 행 평가 51회 중 18회가 옛 결과 + 새 검색어였다. `appliedQuery`는 필요하다 | - |
| R-10 | `Stage1View.swift:13-17` | `searchTask`는 body가 읽지 않는 상태라 바꿔도 화면을 다시 그리지 않는다. `.task(id:)`는 나타날 때 빈 검색어로 한 번 돌고 id가 바뀌면 이전 작업을 취소한다. `SearchTaskBox`는 필요 없다 | ✅ 검증됨 | 실험(`sim/` E4, E3, 직접 재실행): body가 읽지 않는 `@State` Task를 20번 바꿔도 body 재계산 0회, 읽는 상태는 1회. `.task(id:)`는 빈 id로 시작 → 취소 → "a" 시작 → 취소 → "ab" 완료. 1-13, 1-14 해결. 상자를 없앤 뒤의 취소와 `skippedResults` 계수는 화면 테스트가 없어 재측정 값(SwiftUI S1이 UIKit S1과 비슷한지)으로 확인된다 | - |
| R-11 | `Stage1ViewController.swift:90-91`, `Stage1View.swift:63-64`, `Stage2ViewController.swift:105-106`, `Stage2View.swift:74-75` | 계산을 끝낸 검색만 `filterTime`에 기록되고, 도중 취소된 검색은 평균에서 빠진다 | ✅ 검증됨 | 실험(`c/`): 계산 도중 취소하면 `try? await` 뒤의 기록 횟수 0. 1-10, 2-14의 틀린 주석이 네 곳 모두 사실대로 바뀌었다 | - |
| R-12 | PLAN 측정 지표 (새 항목) | 취소가 있는 Stage의 `filterTime`, `resultLatency`, `searchMemory` 평균은 살아남은 검색만 담고, `skippedResults`가 높으면 실제보다 작게 나온다 | ✅ 검증됨 | 코드: 기록 위치가 `try?` 뒤와 `apply` 안이다. 실험(앞선 `h/`): 빠른 절반만 평균하면 `filterTime` 89.50 → 59.85ms, `searchMemory` 0.449 → 0.135MB | - |
| R-13 | `Stage1ViewController.swift:88-96`, `Stage2ViewController.swift:101-112` | 검색 Task의 `[weak self]`를 지워도 된다 (검색 한 번이면 끝나는 Task) | ✅ 검증됨 | 코드: Task 본문은 `search` 한 번과 `apply` 한 번으로 끝나고 반복이 없다. 화면이 사라지면 `viewDidDisappear`가 취소한다. 강한 참조는 그 한 번 동안만 유지된다 | - |
| R-14 | `Stage0ViewController.swift:125`, `Stage1ViewController.swift:136`, `Stage2ViewController.swift:156` | 재생은 취소될 때까지 끝나지 않는 루프라, 화면을 강하게 잡으면 취소를 놓쳤을 때 화면이 해제되지 않는다 | ✅ 검증됨 | 코드: `TypingPlayer.swift:18`의 `while !Task.isCancelled`는 취소 외에 끝나는 길이 없다. `playback`이 그 Task를 들고 있어 강한 참조면 순환이 풀리지 않는다 | - |
| R-15 | `Stage0ViewController.swift:15` | `UISearchTextField`는 왼쪽 아이콘과 지우기 버튼이 기본으로 붙어 있다 | ✅ 검증됨 | 실험(`sim/` E7, 직접 재실행): `clearButtonMode` 1(whileEditing), `leftView` UIImageView, `leftViewMode` 3(always). 0-20 해결 | - |
| R-16 | `Stage2ViewController.swift:12-14` | 인덱스 생성은 화면 객체가 만들어질 때 시작하고 메인 스레드 밖에서 돈다. 옵셔널과 `guard let indexTask`는 필요 없다 | ✅ 검증됨 | 코드: `let` 프로퍼티 초기값이라 `init`에서 한 번 만들어지고 항상 값이 있다. 메인 밖 실행은 R-5 실험. 주제 모듈이 빌드되고 테스트가 통과했다. `indexBuildTime`은 `build` 안에서 재므로 시작 시점이 `viewDidLoad`에서 `init`으로 당겨져도 정의가 같다 | - |
| R-17 | `Stage2View.swift:42-43, 127-135` | `indexTask`는 처음 읽는 순간 시작되고, 상자가 다시 만들어져도 처음 상자에서 한 번만 시작된다 | ✅ 검증됨 | 코드: `lazy var`는 첫 접근에서만 초기화된다. `.task`와 `submit`만 읽고, 버려지는 상자는 아무도 읽지 않는다. `@State` 초기값이 매번 평가되는 것은 앞선 2-20(문서) | - |
| R-18 | `Stage2View.swift:127` | 인덱스 생성을 `lazy`로 한 번만 시작하려면 참조 타입이어야 한다 | ⚠️ 추정 | 실험(`d/lazy.swift`): `lazy var`를 가진 struct를 `@State`에 두고 body에서 읽는 코드가 타입 검사를 통과한다. "struct로는 안 된다"는 컴파일 수준에서는 사실이 아니다. struct일 때 읽을 때마다 `@State`에 다시 쓰여 재계산이나 중복 시작이 생기는지는 확인하지 못했다. 확인 방법: 시뮬레이터에서 struct 버전의 초기화 횟수와 body 재계산 횟수를 센다. 또는 주석을 "struct면 lazy 읽기가 `@State` 쓰기가 된다" 수준으로 낮춘다 | "참조 타입이어야 한다"는 단정을 주석에서 뺌. 상자를 쓰는 이유는 확인된 사실(상자 프로퍼티는 관찰되지 않음, lazy는 처음 읽을 때 한 번 시작)만 적음 → 재검증 2의 Q-1, Q-2 |
| R-19 | `Stage2View.swift:87` | 인덱스는 `@State`가 아니라서 넣어도 화면을 다시 그리지 않고, 결과(`@State`)가 바뀌어 행을 다시 그릴 때 함께 읽힌다 | ✅ 검증됨 | 실험(`sim/` E4, E5, 직접 재실행): 상자 프로퍼티 변경은 body 재계산 0회, `@State` 변경은 1회. 대입 순서를 바꿔도 행이 본 상자 값이 같다 (`item1:box1`, `item2:box2`). 2-18, 2-19 해결 | - |
| R-20 | `Stage2ViewController.swift:6-8`, `Stage2View.swift:6-8` | 변경 머리말: 일치 위치는 `range(of:)` + `String.Index` 변환 대신 UTF-16 배열 직접 비교로 구한다. SwiftUI는 행의 id도 위치 값이다 | ✅ 검증됨 | 코드: `Stage1Search.swift:74-76`과 `Stage2Index.swift:35-59`, `Stage2View.swift:33`. 2-10 해결 | - |
| R-21 | `PerfMonitor.swift:101-113, 159-164` | 예정 시각이 지났으면 지금 이후의 첫 프레임 경계로 올리고, 제때 온 콜백은 그대로 둔다 | ✅ 검증됨 | 테스트: `SharedTests.swift:keepsTargetWhenCallbackIsOnTime`, `movesStaleTargetToNextFrameBoundary` 통과. 실험(`h2/`): 57ms 늦으면 `10 + 4프레임`(10.0667), 제때면 10.0 그대로. 프레임 길이는 `targetTimestamp − timestamp`로 넘긴다 | - |
| R-22 | `PerfMonitor.swift:103-104`, 커밋 f519e5d | 메인 스레드가 막혀 콜백이 늦으면 `targetTimestamp`가 이미 과거다 (시뮬레이터에서 60ms씩 막으면 40회 중 19회, 최대 57ms) | ✅ 검증됨 | 실험(`sim/` E6, 직접 재실행): 40회 중 15회, 최대 55.8ms 과거. 횟수와 최댓값은 실행마다 달라지고 주석의 숫자는 한 번의 실행 값이다. 현상은 재현된다 | - |
| R-23 | `PerfMonitor.swift:93-95`, PLAN `inputDelay`, VERIFICATION 0-8 조치 | 입력을 처리한 뒤의 첫 콜백에서 불리고, 넘기는 시각이 그 변경이 화면에 나갈 수 있는 가장 이른 프레임이다 | ⚠️ 추정 | 시뮬레이터에서는 확인됐다 (`sim/` E6: `onChange`가 끝나기 전에 tick이 온 경우 40회 중 0회). 남은 것: (1) 실기기에서는 확인하지 않았다. (2) E6은 `Text` 하나짜리 화면이라 `List` 갱신이 낀 실제 화면과 다르다. (3) 늦은 콜백은 "지금 이후 첫 경계"로 올리는데, 경계 직전에 불리면 그 프레임에 실제로 실릴 수 없어 한 프레임 미만으로 짧게 잡힐 수 있다 (`h2/`: now 10.0166 → 10.0167). 확인 방법: 실기기에서 Instruments의 Hitches 또는 Display 트랙과 `inputDelay` 끝점을 대조한다. 또는 PLAN에 "하한 추정"으로 적는다 | 확인할 수 없는 부분이라 한계로 밝힘: PLAN `inputDelay` 설명에 "경계 직전 콜백은 한 프레임 미만 짧게 잡힐 수 있음", "onChange 순서는 시뮬레이터에서만 확인"을 추가 |
| R-24 | 변경 전체 | 변경이 기존 ✅ 항목을 깨뜨리지 않았다 | ✅ 검증됨 | 테스트: 주제 테스트 통과(기준 구현 일치, 취소, 건너뛰기), Shared 테스트 6건 통과. 실험(`h2/`): 바뀐 소스로 62단계 경로와 결과가 그대로 돈다. 화면 코드는 단위 테스트 범위 밖이다 | - |
| R-25 | VERIFICATION 1-12 조치 | RESULTS 대가 표와 분석에서 S1 `searchMemory`를 S0과 직접 비교하지 않고 실험값(Mac 전 단계 0.449MB)을 함께 적었다 | ❌ 틀림 | `docs/RESULTS.md`는 `git status`상 변경이 없고 "0.449"가 없다. 대가 표 89행은 여전히 "`searchMemory` 0.13 → 0.14MB / 0.14 → 0.14MB"로 직접 비교한다. 96행의 "살아남은 검색어만의 평균" 문장은 조치 이전부터 있던 것이다. PLAN 쪽 명시는 반영됐다(R-12) | 재측정 뒤 RESULTS.md 대가 표와 분석을 다시 쓰면서 반영함: S1 `searchMemory`를 S0과 직접 비교하지 않고 Mac 전 단계 실험값 0.449MB(참고용)를 함께 적음 |

#### 불필요하거나 설명되지 않는 코드
- `Stage1ViewController.swift:88` `[search]`: `[weak self]`를 지우면서 남은 캡처다. 이제 Task가 `self`를 강하게 잡으므로 `search`를 따로 캡처하지 않아도 동작이 같다. `Stage1View.swift:61`의 `[search]`도 이유가 적혀 있지 않다.
- `Stage2ViewController.swift:11, 14`: `indexTask`의 초기값이 `Scenario.products`를 Task 안에서 읽는다. 바로 위 `products` 프로퍼티가 먼저 초기화되어 5만 개 생성이 메인 스레드에서 끝난 뒤라 지금은 문제가 없다. 두 줄의 순서에 기대는 점이 적혀 있지 않다 (순서가 바뀌면 첫 생성이 어느 스레드에서 도는지는 확인하지 않았다).

#### 사용자에게 짚어 줄 것
- **R-10, R-19 (`@State`와 재계산)**: SwiftUI는 body가 읽은 상태만 의존성으로 잡는다. body가 읽지 않는 `@State`는 20번 바꿔도 body가 한 번도 다시 계산되지 않았다. "다시 그리지 않게 하려고 참조 타입 상자에 넣는다"는 흔한 설명은 이 경우 필요 없는 우회였다.
- **R-4, R-25 (코드는 고쳤지만 숫자는 그대로)**: 계산식과 끝점이 바뀌었는데 results와 RESULTS.md는 옛 코드의 값이다. S0 `searchMemory`는 0.13MB가 아니라 약 0.21MB(Mac 기준)가 되고, S0 `inputDelay`도 달라진다. 재측정 전에는 표의 이 두 지표를 현재 코드의 값으로 인용할 수 없다.

- **조치 (판정 밖 항목):** `[search]` 캡처를 UIKit/SwiftUI S1에서 지움 (재검증 2의 Q-3).
  `Stage2ViewController`의 `indexTask`는 `self.products`가 아니라 `Scenario.products`(static let)를 직접 읽으므로 프로퍼티 선언 순서에 기대지 않는다. 코드는 그대로 둠.

### [재검증 2] 바뀐 세 곳(SearchState 주석, `[search]` 캡처 제거, PLAN `inputDelay` 한계)은 모두 근거와 맞는다 (2026-10-11)

- 대상: `SwiftUI/Stage2View.swift`(125-137행), `UIKit/Stage1ViewController.swift`(88-97행), `SwiftUI/Stage1View.swift`(61-69행), `docs/PLAN.md`(측정 지표 77-78행)
- 판정: ✅ 4건 · ⚠️ 0건 · ❌ 0건
- 확인: `scripts/perflab test 01-search-autocomplete-highlight` 통과(exit 0), `scripts/perflab lint` 통과. 실험 근거는 재검증 때 직접 돌린 `sim/`(E4, E6), `c/`, `h2/`의 출력을 다시 쓴다.

| # | 위치 | 주장 | 판정 | 근거 | 조치 |
|---|---|---|---|---|---|
| Q-1 | `Stage2View.swift:127-128` | 참조 타입 안의 프로퍼티는 SwiftUI가 관찰하지 않아 바꿔도 화면 갱신이 일어나지 않는다. 진행 중인 검색, 스택, 적용한 인덱스를 그래서 상자에 모았다 | ✅ 검증됨 | 실험(`sim/` E4): body가 읽는 값이어도 상자 프로퍼티를 바꾸면 body 재계산 0회, `@State`를 바꾸면 1회. R-18에서 근거가 없던 "참조 타입이어야 한다"는 단정이 빠졌다 | - |
| Q-2 | `Stage2View.swift:129-130, 134` | `indexTask`는 처음 읽을 때 한 번만 시작된다. `@State` 초기값은 뷰가 다시 만들어질 때마다 평가되므로 Task를 초기값으로 바로 두지 않는다 | ✅ 검증됨 | 코드: `lazy var`라 첫 접근(`:43` 또는 `submit`)에서만 만들어지고, 버려지는 상자는 읽히지 않는다. 문서: SwiftUICore `.swiftinterface`의 `State.init(wrappedValue value: Value)`가 autoclosure가 아니다 (2-20) | - |
| Q-3 | `Stage1ViewController.swift:88-89`, `Stage1View.swift:61-62` | `[search]` 캡처를 지워도 동작이 같다 | ✅ 검증됨 | 코드: Task 본문은 메인 액터에서 `self.search`를 읽어 `@concurrent` 함수에 넘긴다. `Stage1Search`는 `Sendable`이고 `let`이라 캡처한 사본과 값이 같다. 테스트: 주제 모듈이 Swift 6 모드로 빌드되고 테스트가 통과했다. 실험(`c/`): Task 본문은 메인, `@concurrent` 함수는 메인 밖에서 실행 | - |
| Q-4 | `docs/PLAN.md:77-78` | `inputDelay` 끝점의 한계: 콜백이 프레임 경계 직전에 불리면 한 프레임 미만으로 짧게 잡힐 수 있고, SwiftUI에서 `onChange`가 그 콜백보다 앞선다는 것은 시뮬레이터에서만 확인했다 | ✅ 검증됨 | 실험(`h2/`): 예정 시각 10.0, 지금 10.0166이면 10.0167을 돌려준다 (0.07ms 뒤의 경계). 실험(`sim/` E6): 시뮬레이터에서 40회 중 0회. 실기기 실험은 없다. R-23의 세 한계 중 "E6은 `Text` 하나짜리 화면이라 `List` 갱신이 낀 화면과 다르다"는 문장에 없지만, 적힌 두 가지는 사실과 같다 | - |

#### 불필요하거나 설명되지 않는 코드
- 없음 (R의 `[search]` 지적은 해소됐다. `Stage2ViewController.swift:11, 14`의 프로퍼티 순서 의존은 이번 변경 범위가 아니라 그대로다.)

#### 사용자에게 짚어 줄 것
- **Q-1**: 주석의 이유가 "struct로는 안 된다"에서 "관찰되지 않는 곳에 두려고"로 바뀌었다. 앞의 것은 컴파일러가 반박했고, 뒤의 것은 실험(상자 변경 0회, `@State` 변경 1회)이 뒷받침한다. 같은 코드라도 주석이 대는 이유가 확인 가능한 것이어야 한다.

- 지문: `b0bdde8606c4`
