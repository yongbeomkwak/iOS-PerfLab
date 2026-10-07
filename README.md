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

하나의 주제는 아래 순서로 진행한다.

```
1. 주제 선정  →  2. 단계별 구현  →  3. 성능 측정  →  4. 회고 / 정리  →  5. 아카이빙
```

### 1. 주제 선정

실제 앱에서 있을 법한 상황을 바탕으로 최적화가 필요한 주제를 고른다.

> 예) 주식 앱에서 초당 수십 번 갱신되는 실시간 차트를 어떻게 부드럽게 그릴까?

### 2. 단계별 구현

같은 요구사항을 최소 3단계로 나눠 구현하고, 앱 안에서 단계를 바꿔가며 비교할 수 있게 만든다.

| 단계 | 이름 | 설명 |
|:---:|---|---|
| **Stage 0** | Naive | 성능을 신경 쓰지 않고 가장 직관적으로 구현한 기준점 |
| **Stage 1** | Optimized | 프레임워크 수준에서 할 수 있는 최적화 (재사용, 캐싱, 비동기 처리, diff 등) |
| **Stage 2** | Low-level | CoreGraphics, CoreAnimation, Metal, GCD/Thread, 메모리 레이아웃 등 저수준 API까지 내려간 최적화 |

> 주제에 따라 Stage는 더 늘어날 수 있다.

가능한 경우 **UIKit / SwiftUI 두 가지 버전**을 모두 구현해 프레임워크별 차이도 비교한다.

### 3. 성능 측정 (필수)

**모든 주제에는 반드시 측정 결과가 들어간다.** 단계 간 비교는 같은 조건(기기, 데이터 양, 실행 시간)에서 진행한다.

| 지표 | 내용 | 측정 방법 (예시) |
|---|---|---|
| **FPS / Hitch** | 프레임 드랍, 끊김 비율 | `CADisplayLink`, Instruments(Animation Hitches) |
| **실행 시간** | 특정 구간의 처리 시간 | `os_signpost`, `ContinuousClock`, `XCTClockMetric` |
| **CPU** | CPU 사용률, 메인 스레드 점유 | `thread_info`, Instruments(Time Profiler) |
| **메모리** | Physical footprint, 할당 횟수 | `task_info`, Instruments(Allocations, Leaks), `XCTMemoryMetric` |
| **스레드** | 스레드 개수, 작업이 실행된 스레드 | `task_threads`, Instruments(System Trace) |
| **에너지** | 전력 소비 경향 | Instruments(Energy Log), `XCTCPUMetric` |

앱 안에서는 실시간 지표를 보여주는 **공통 성능 HUD**를 띄워, 단계를 바꿀 때마다 바로 수치 변화를 확인할 수 있게 한다.

### 4. 회고 / 정리

주제가 끝나면 아래 템플릿으로 정리한다. 이 문서는 그대로 블로그 포스팅의 초안이 된다.

```markdown
# [PerfLab #NN] 주제 제목

## 상황
- 어떤 앱에서, 어떤 요구사항 때문에 문제가 생기는가

## 문제 정의
- 무엇이 느린가 / 무엇이 병목인가 (측정 근거 포함)

## 단계별 구현
- Stage 0 · Naive : 구현 방식, 문제점
- Stage 1 · Optimized : 무엇을 바꿨고 왜 빨라졌는가
- Stage 2 · Low-level : 어떤 저수준 API를 사용했는가

## 측정 결과
- 단계별 지표 비교표 / 그래프 / Instruments 캡처

## 필요한 CS 지식
- 렌더링 파이프라인, 스레드 모델, 메모리 구조 등

## 트레이드오프 & 회고
- 복잡도 대비 성능 이득, 실무에서 어느 단계까지 적용할 것인가

## 참고 자료
```

### 5. 아카이빙

정리된 주제는 아래 [Topics](#topics) 표에 계속 쌓아 나간다.

<br>

## 앱 구성

```
[ Rendering ]
  ├─ 빠른 주식차트를 어떻게 구현할까?
  │    #CoreGraphics #Thread #CALayer
  ├─ ...
  └─ ...

────────────────────────────────────
 Render | Anim | Concur | Memory | IO    ← 대주제 탭
```

- **탭 바** : 대주제(카테고리)
- **리스트** : 각 카테고리에 속한 주제 제목과 키워드 태그
- **상세** : 주제별 실험 화면
  - Stage 전환 (Naive / Optimized / Low-level)
  - UIKit / SwiftUI 전환
  - 실시간 성능 HUD

### 카테고리 (초안)

| 탭 | 다루는 내용 |
|---|---|
| **Rendering** | 드로잉, 레이어, 오프스크린 렌더링, 이미지 디코딩 |
| **Animation** | 애니메이션 성능, 프레임 드랍, CoreAnimation |
| **Concurrency** | GCD, Swift Concurrency, 스레드, 락, 데이터 경쟁 |
| **Memory** | 메모리 사용량, 캐싱, 값/참조 타입, 메모리 레이아웃 |
| **Data & I/O** | 대량 데이터 처리, 리스트 스크롤, 디스크/네트워크 I/O |

> 카테고리는 주제가 쌓이면서 조정될 수 있다.

<br>

## Topics

| # | 카테고리 | 주제 | 키워드 | UIKit | SwiftUI | 정리 |
|:---:|---|---|---|:---:|:---:|:---:|
| 01 | Rendering | 빠른 주식차트를 어떻게 구현할까? | `CoreGraphics` `Thread` `CALayer` | ⬜ | ⬜ | ⬜ |

### 후보 주제 (Backlog)

- 수천 개 셀의 이미지 피드를 끊김 없이 스크롤하려면? — `ImageDecoding` `Prefetch` `Cache`
- 채팅 앱에서 메시지가 쏟아질 때 리스트 업데이트 최적화 — `Diffable` `Batch Update` `MainThread`
- 라이브 방송 채팅/하트 애니메이션 대량 렌더링 — `CAEmitterLayer` `CoreAnimation`
- 대용량 JSON 파싱과 메인 스레드 블로킹 — `Codable` `Concurrency` `Memory`
- 그림판 앱에서 실시간 드로잉 지연 줄이기 — `CoreGraphics` `Metal` `Touch`

<br>

## 환경

- Xcode / Swift 최신 버전
- iOS (최소 지원 버전은 프로젝트 셋업 시 결정)
- 측정은 **실기기 기준** (시뮬레이터 수치는 참고용)

<br>

## Roadmap

- [ ] 프로젝트 기본 구조 셋업 (탭 바 / 리스트 / 상세)
- [ ] 공통 성능 HUD (FPS, CPU, 메모리, 스레드)
- [ ] Stage / UI 프레임워크 전환 공통 컴포넌트
- [ ] #01 빠른 주식차트를 어떻게 구현할까?
- [ ] 주제 정리 문서 템플릿 확정
