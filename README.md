# iOS-PerfLab

> 실제 앱에서 마주치는 성능 문제를 **Naive → Optimized → Low-level** 단계로 직접 구현하고,
> **측정하고, 기록하는** iOS 성능 실험실 (UIKit / SwiftUI)

<br>

## 왜 시작했나

AI Agent로 iOS 개발을 하다 보면 UI는 빠르게 만들어지지만, **"왜 느린가"와 "어디까지 빠르게 만들 수 있나"** 에 대한 감각은 쌓이지 않는다.

이 프로젝트는 그 빈자리를 채우기 위한 실험실이다.

- 실제 서비스에서 성능이 문제 되는 상황을 **주제**로 정한다.
- 같은 기능을 **단계별로 다시 구현**하면서 무엇이 병목인지 직접 확인한다.
- 느낌이 아니라 **숫자로 비교**한다.
- 끝나면 상황, 해결 방법, 필요한 CS 지식을 **글로 정리**해 아카이빙한다.

<br>

## 진행 방식

하나의 주제는 아래 파이프라인을 **항상 같은 순서로** 지나간다. 각 단계는 정해진 산출물이 있어야 다음으로 넘어갈 수 있다 (`scripts/perflab advance`가 검사).

```
proposed → planned → stage0 → stage1 → stage2 → measured → summarized → archived
 주제 선정   실험 설계   ─────── 단계별 구현 ───────   성능 측정    정리/회고     아카이빙
```

| 단계 | 하는 일 | 산출물 |
|---|---|---|
| **proposed** | 실제 앱에서 있을 법한 성능 문제를 주제로 선정 | `topic.json` |
| **planned** | 시나리오(seed 고정 데이터, 부하), 측정 지표, Stage별 전략 설계 | `docs/PLAN.md`, `Scenario.swift` |
| **stage0~2** | 같은 요구사항을 단계별로 UIKit / SwiftUI 구현 | `UIKit/`, `SwiftUI/`, 정합성 테스트 |
| **measured** | Release 빌드로 모든 Stage×Framework 자동 측정 | `results/*.json`, `docs/RESULTS.md` |
| **summarized** | 상황, 해결 방법, CS 지식, 회고를 블로그용 글로 정리 | `docs/SUMMARY.md` |
| **archived** | 아래 [Topics](#topics) 표에 등록 | README |

### 단계별 구현

| 단계 | 이름 | 설명 |
|:---:|---|---|
| **Stage 0** | Naive | 성능을 신경 쓰지 않고 가장 직관적으로 구현한 기준점 (일부러 느리게 만들지 않는다) |
| **Stage 1** | Optimized | 프레임워크 수준에서 할 수 있는 최적화 (재사용, 캐싱, 비동기 처리, diff 등) |
| **Stage 2** | Low-level | CoreGraphics, CoreAnimation, Metal, GCD/Thread, 메모리 레이아웃 등 저수준 API까지 내려간 최적화 |

- 모든 Stage는 같은 `Scenario`(고정 seed) 입력을 쓰고, 결과가 같은지 테스트로 검증한다.
- 가능한 경우 **UIKit / SwiftUI 두 가지 버전**을 모두 구현해 프레임워크별 차이도 비교한다.

### 성능 측정 (필수)

**모든 주제에는 반드시 측정 결과가 들어간다.** 측정은 UI 테스트가 앱을 Stage×Framework 조합별로 실행해 자동으로 수행한다.

| 지표 | 내용 | 수집 방법 |
|---|---|---|
| **FPS / Hitch** | 평균·최저 FPS, hitch 횟수, hitch time ratio (ms/s) | `CADisplayLink` |
| **CPU** | 프로세스 CPU 사용률 (평균 / 최대) | `task_threads` + `thread_info` |
| **메모리** | Physical footprint (평균 / 최대) | `task_info(TASK_VM_INFO)` |
| **스레드** | 최대 스레드 수 | `task_threads` |
| **주제별 지표** | 파싱 시간, 디코딩 시간 등 | `context.metrics` |
| **구간 분석** | Instruments에서 확인할 구간 | `os_signpost` (`PerfSignpost`) |

- 정식 결과는 **실기기 + Release 빌드** 기준이고, 시뮬레이터 수치는 참고용이다.
- 앱 안에서는 **성능 HUD**로 Stage를 바꿀 때마다 실시간 수치를 확인할 수 있다.

### 학습 체크포인트

구현은 AI Agent(Claude)가 맡지만, 각 단계마다 **체크포인트**가 있다.

- 설명을 듣기 전에 먼저 **예측**한다. (병목이 어디일지, 왜 빨라질지, 수치가 어떻게 변할지)
- 구현 뒤에는 핵심 변경을 짚고 **이해를 확인**하며, 궁금한 점을 문답으로 푼다.
- 예측과 답변은 틀려도 그대로 `docs/LEARNING.md`에 남기고, 이를 바탕으로 "예측과 실제"를 회고한다.

<br>

## 앱 구성

```
[ Rendering ]
  ├─ #01 수천 장의 이미지 피드를 끊김 없이 스크롤하려면?
  │      #ImageDecoding #Prefetch #Cache
  ├─ ...
  └─ ...

────────────────────────────────────────────────
 Rendering | Animation | Concurrency | Memory | Data & I/O   ← 대주제 탭
```

- **탭 바**: 대주제(카테고리)
- **리스트**: 각 카테고리에 속한 주제 제목과 키워드 태그
- **상세**: 주제별 실험 화면 (Stage 전환, UIKit / SwiftUI 전환, 실시간 성능 HUD)

| 탭 | 다루는 내용 |
|---|---|
| **Rendering** | 드로잉, 레이어, 오프스크린 렌더링, 이미지 디코딩 |
| **Animation** | 애니메이션 성능, 프레임 드랍, CoreAnimation |
| **Concurrency** | GCD, Swift Concurrency, 스레드, 락, 데이터 경쟁 |
| **Memory** | 메모리 사용량, 캐싱, 값/참조 타입, 메모리 레이아웃 |
| **Data & I/O** | 대량 데이터 처리, 리스트 스크롤, 디스크/네트워크 I/O |

<br>

## 프로젝트 구조

```
PerfLab.xcodeproj         # 얇은 앱 셸 + 자동 측정 UI 테스트
App/                      # 탭 바, 주제 리스트
AppUITests/               # BenchmarkUITests
Packages/
├── Shared/               # 공통 모델, PerfTopic 프로토콜, 성능 HUD, 벤치마크
└── Topics/
    ├── Catalog/          # 앱에 노출되는 주제 목록 (자동 등록)
    └── <Category>/<NN-slug>/
        ├── topic.json    # 메타데이터 + 파이프라인 상태
        ├── Scenario.swift
        ├── UIKit/  Stage0~2
        ├── SwiftUI/ Stage0~2
        ├── Tests/
        ├── docs/         # PLAN · LEARNING · RESULTS · SUMMARY
        └── results/      # 측정 결과 JSON
Templates/Topic/          # 새 주제 템플릿
scripts/perflab           # 파이프라인 CLI
.claude/                  # Claude Code 규칙, /perflab skill, 리뷰 에이전트
```

<br>

## 사용법

```bash
# Claude Code에서 주제 진행 (권장)
/perflab              # 진행 중인 주제를 이어서 진행하거나 새 주제 제안
/perflab new          # 새 주제 제안
/perflab status       # 상태 확인

# CLI 직접 사용
scripts/perflab status
scripts/perflab validate <topic>
scripts/perflab measure <topic> --device "<실기기 이름>"
scripts/perflab table <topic>
```

<br>

## Topics

<!-- perflab:topics:start -->
| # | 카테고리 | 주제 | 키워드 | 프레임워크 | 상태 | 문서 |
|:---:|---|---|---|---|---|---|
| - | - | 아직 주제가 없습니다 | - | - | - | - |
<!-- perflab:topics:end -->

### 후보 주제 (Backlog)

- 수천 개 셀의 이미지 피드를 끊김 없이 스크롤하려면? — `ImageDecoding` `Prefetch` `Cache`
- 채팅 앱에서 메시지가 쏟아질 때 리스트 업데이트 최적화 — `Diffable` `Batch Update` `MainThread`
- 라이브 방송 채팅/하트 애니메이션 대량 렌더링 — `CAEmitterLayer` `CoreAnimation`
- 대용량 JSON 파싱과 메인 스레드 블로킹 — `Codable` `Concurrency` `Memory`
- 그림판 앱에서 실시간 드로잉 지연 줄이기 — `CoreGraphics` `Metal` `Touch`
- 주식 앱의 실시간 차트를 부드럽게 그리려면? — `CoreGraphics` `CALayer` `Thread`

<br>

## 환경

- Xcode 26+, Swift 6 (strict concurrency)
- iOS 17+
- SPM 로컬 패키지 (서드파티 의존성 없음, first-party only)

<br>

## Roadmap

- [x] 프로젝트 기본 구조 셋업 (탭 바 / 리스트 / 상세)
- [x] 공통 성능 HUD (FPS, Hitch, CPU, 메모리, 스레드)
- [x] Stage / UI 프레임워크 전환 공통 컴포넌트
- [x] 자동 측정 파이프라인 (UI 테스트 → 결과 JSON → 결과표)
- [x] 주제 템플릿, 파이프라인 CLI, Claude Code skill
- [ ] #01 첫 주제 진행
