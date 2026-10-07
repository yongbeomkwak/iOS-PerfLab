---
paths:
  - "Packages/Topics/**"
---

# 주제 구현 규칙

## 공정한 비교

- **모든 Stage는 `Scenario`의 같은 입력과 같은 요구사항을 쓴다.** Stage 안에서 데이터를 따로 만들거나 데이터 규모, 갱신 주기를 바꾸지 않는다.
- **Stage 0은 "자연스러운 순진한 구현"이다.** 일부러 느리게 만들지 않는다. 실무에서 처음 작성할 법한 코드여야 한다.
- **Stage N+1은 Stage N에서 출발한다.** 무엇을 바꿨는지 설명할 수 있어야 하고, 한 Stage에 서로 무관한 최적화를 섞지 않는다.
- **결과(출력)는 모든 Stage에서 같아야 한다.** 화면에 보이는 결과나 계산 결과가 같다는 것을 `Tests/`의 정합성 테스트로 검증한다.
- UIKit과 SwiftUI는 같은 Stage에서 같은 전략을 쓴다. 프레임워크 특성상 불가능하면 PLAN.md에 이유를 적는다.
  SwiftUI Stage에서 `UIViewRepresentable`로 UIKit이나 저수준 API를 감싸는 것은 허용하되, 그 사실을 문서에 명시한다.
- **최적화는 저수준 API에 한정하지 않는다.** 자료구조, 값/참조 타입, 메모리, 동시성, 구조, 렌더링, I/O 중
  병목의 원인에 맞는 축을 고른다 (`docs/GUIDE.md` 3절). 저수준 API는 그 원인이 렌더링이나 시스템 호출에 있을 때 쓴다.

## Benchmark 모드

- `context.isBenchmark == true`이면 사용자 입력 없이 시나리오를 스스로 재생한다 (자동 스크롤, 타이머 갱신 등).
- 재생은 결정적이어야 한다. 시간 기반 랜덤, 네트워크 등 외부 요인을 쓰지 않는다.
- 측정 시간(기본 10초) 동안 부하가 계속 유지되도록 반복 재생한다.

## 코드

- First-party 프레임워크만 쓴다. Topics 패키지에 외부 의존성을 추가하지 않는다.
- 구현을 마친 Stage 파일에서는 `// PERFLAB: NOT_IMPLEMENTED` 마커를 지운다.
- UIKit Stage는 `NotImplementedViewController` 대신 `UIViewController`를 상속하도록 바꾼다.
- 핵심 구간은 `PerfSignpost.signposter`로 표시하고, 주제별 지표는 `context.metrics`로 기록한다.
- Stage 파일 상단에 `// 전략:` 머리말을 쓰고, 첫 Stage 이후에는 `// 변경:`도 쓴다. 형식, 구획 순서, 주석 기준은 `docs/CONVENTIONS.md`의 "Stage 파일 구조"를 따른다.
- 이름(signpost, 커스텀 지표 포함), 접근 제어, 동시성 규칙도 `docs/CONVENTIONS.md`를 따른다. 구현 후 `scripts/perflab format <주제 경로>`를 실행한다.
- 측정하려고 원래 하지 않던 작업을 추가하지 않는다. 그런 지표는 Instruments로 확인한다.
- PLAN.md의 대가 지표 중 커스텀 지표는 **모든 Stage가 기록한다.** 해당 구조가 없는 Stage는 0을 기록한다. 측정 결과에 빠지면 `advance`가 실패한다.
- 여러 Stage가 공유하는 모델과 유틸은 주제 폴더 루트(예: `Model.swift`)에 둔다. 단, 최적화 대상이 되는 로직은 공유하지 않는다.
- `Shared` 패키지 수정이 필요하면 모든 주제에 쓸 수 있는 일반적인 기능인지 먼저 확인하고, 사용자에게 알린다.

## 금지

- `topic.json`의 `status` 직접 수정 (`scripts/perflab advance`만 사용)
- `Package.swift`, `Catalog/TopicCatalog.swift` 수동 등록 (`scripts/perflab new`만 사용)
- 측정하지 않은 수치를 문서에 쓰는 것
