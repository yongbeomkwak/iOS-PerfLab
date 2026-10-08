# [PerfLab #01] 5만 개 항목 검색 자동완성, 키워드 하이라이트까지 타이핑을 따라가려면? — 측정 결과

## 측정 환경

- 기기: iPhone 17 Pro 시뮬레이터 (iPhone18,1, iOS 26.5), Mac에서 실행. **실기기 측정 전이라 모든 수치는 참고용이다.**
- 측정 명령: `scripts/perflab measure 01-search-autocomplete-highlight` (기기를 지정하지 않으면 시뮬레이터)
- 빌드 구성: Release, warm-up 2초, 측정 10초, 조합마다 3회 반복의 중앙값, 빈 화면 baseline 포함
- 결과 원본: `results/iPhone18,1-simulator/stage<N>-<framework>.json`
- 시뮬레이터 화면은 최대 60fps라, 기대 프레임 시간은 16.7ms이고 그 1.5배(25ms)를 넘으면 hitch로 센다.

## 결과

<!-- perflab:results:start -->
### iPhone18,1 (iOS 26.5, Simulator, Release, max 60fps)

측정 10초 × 3회 중앙값. Baseline은 부하 없는 빈 화면(측정 노이즈 바닥)이다.

| 지표 | Baseline | UIKit S0 | UIKit S1 | UIKit S2 | SwiftUI S0 | SwiftUI S1 | SwiftUI S2 | 의미 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| FPS avg | 60.1 | 29.6 | 60.1 | 53.9 | 24.5 | 57.3 | 54.0 | 1초에 메인 스레드가 처리한 프레임 수의 평균. 최대 주사율에 가까울수록 부드럽다 |
| FPS min | 60.0 | 20.0 | 60.0 | 50.0 | 17.4 | 52.0 | 46.6 | 0.5초 구간 중 가장 낮았던 FPS. 순간적으로 가장 심하게 끊긴 정도 |
| Hitch count | 0 | 105 | 0 | 62 | 95 | 16 | 40 | 프레임 간격이 기대 시간의 1.5배를 넘은 횟수. 적을수록 좋다 |
| Hitch ratio (ms/s) | 0.0 | 483.7 | 0.0 | 105.6 | 563.3 | 40.4 | 101.3 | 기대 시간을 넘긴 시간의 합을 초당으로 나눈 값. 5 미만 양호, 10 이상 심각 (Apple 기준) |
| CPU avg (%) | 0.8 | 52.4 | 68.2 | 15.2 | 63.8 | 76.9 | 24.0 | 프로세스 CPU 사용률 평균. 100% = 코어 1개를 다 씀. 일의 양을 보여 준다 |
| CPU peak (%) | 1.1 | 66.1 | 79.2 | 19.5 | 78.4 | 95.3 | 40.8 | 0.5초 구간 중 가장 높았던 CPU 사용률 |
| Memory avg (MB) | 41.4 | 54.1 | 53.8 | 57.6 | 63.1 | 61.8 | 66.8 | 앱이 실제로 쓰는 물리 메모리(physical footprint) 평균. iOS가 앱을 종료시키는 기준과 같다 |
| Memory peak (MB) | 41.5 | 54.8 | 54.6 | 58.4 | 64.8 | 63.0 | 70.2 | 물리 메모리의 최대값 |
| Threads peak | 9 | 10 | 10 | 24 | 11 | 10 | 10 | 프로세스 스레드 수의 최대값 |
| filterTime (ms) | - | 46.06 | 58.24 | 0.73 | 45.99 | 58.51 | 0.35 | 실행 스레드와 관계없이 검색 한 번에 드는 계산량 (구간: 필터링 작업의 시작 → 끝) |
| resultLatency (ms) | - | 46.66 | 58.83 | 2.33 | 48.48 | 60.35 | 5.12 | 결과가 얼마나 늦게 갱신됐나 ("갱신이 늦는다") (구간: 입력 시점 → 그 검색어의 결과를 목록 데이터에 적용한 시점) |
| skippedResults (%) | - | 0.00 | 13.00 | 0.00 | 0.00 | 16.00 | 0.00 | 다음 입력에 밀려 화면에 한 번도 나오지 못한 검색어 비율 |
| searchMemory (MB) | - | 0.13 | 0.33 | 3.79 | 0.14 | 0.31 | 3.79 | 검색을 위해 들고 있는 자료구조의 크기 추정치: 결과 배열 + 미리 계산한 일치 위치 + 인덱스 + 결과 스택 |
| indexBuildTime (ms) | - | 0.00 | 0.00 | 25.15 | 0.00 | 0.00 | 24.46 | 첫 검색 결과 전에 한 번 드는 준비 비용 (구간: 화면을 연 직후 백그라운드 검색 준비 작업의 시작 → 끝) |
| inputDelay (ms) | - | 57.90 | 12.00 | 22.90 | 63.59 | 10.34 | 16.49 | 입력이 화면에 얼마나 늦게 반영됐나 ("글자가 늦게 찍힌다") (구간: 입력 예정 시각 → 그 입력을 처리한 뒤 첫 프레임이 화면에 나갈 시각) |

> ⚠ 시뮬레이터 수치는 참고용입니다.
<!-- perflab:results:end -->

## 예측 vs 실제

| 항목 | 사용자 예측 | 실제 (시뮬레이터, 참고용) | 차이 원인 |
|---|---|---|---|
| [Plan] 병목 | "글자가 늦게 찍힌다, 갱신이 늦는다, 검색과 후보 리스트 싱크가 순간적으로 안 맞는다" | S0 `inputDelay` UIKit 57.9ms / SwiftUI 63.6ms, hitch 483.7 / 563.3ms/s | 예측대로다. 메인 스레드가 입력마다 약 46ms 거르기를 하느라 글자 표시와 그리기가 함께 밀렸다 |
| [Stage 0] 메인에서 거르면 | "i가 찍히는 main thread 작업이 뒤로 밀려 행이 발생" / "CPU 사용률이 올라갈 것" | FPS avg 29.6 / 24.5, CPU avg 52.4% / 63.8% | 행(멈춤)은 맞다. CPU는 코어 하나를 절반쯤 쓰는 수준이고, 핵심은 CPU 양보다 메인 스레드를 막는다는 점이다 |
| [Stage 1] `resultLatency` | 줄어들 것 | UIKit 46.7 → 58.8ms, SwiftUI 48.5 → 60.4ms (↑) | 계산량은 그대로이고, 결과 전체의 위치를 미리 구하는 일과 백그라운드 경합이 더해졌다. 일을 옮겼을 뿐 줄이지 않았다 |
| [Stage 1] 대가 | CPU | CPU avg 52.4 → 68.2% / 63.8 → 76.9% (↑), `skippedResults` 13% / 16% | 맞다. 결과 전체의 위치 계산과 취소된 검색 비용이 더해졌다. 따라잡지 못한 검색어는 화면에 나오지 못했다 |
| [Measure] S2 `resultLatency`, UIKit vs SwiftUI | UIKit이 짧을 것 | UIKit 2.33ms, SwiftUI 5.12ms | 맞다. 다만 이 지표는 결과를 `@State`에 넣는 순간까지라 SwiftUI `List`의 비교 비용은 들어 있지 않다. 차이는 SwiftUI가 바인딩 변경을 `onChange`로 다음 갱신에서 넘겨주는 데서 온다 |
| [Measure] Memory peak S0 → S2 | S2로 갈수록 높아짐, 추정치와 비교는 모르겠음 | UIKit 54.8 → 54.6 → 58.4MB, SwiftUI 64.8 → 63.0 → 70.2MB | S2에서 오른 것은 맞다. S1은 S0과 같았다. S1 → S2 증가는 UIKit 3.8MB로 `searchMemory` 차이(3.46MB)와 비슷하고, SwiftUI는 7.2MB로 두 배쯤이다 |
| [Measure] Threads peak | S0이 가장 적고 S1, S2는 비슷 | 중앙값 S0 10 / 11, S1 10 / 10, S2 24 / 10 | S1과 S2 SwiftUI는 S0과 같은 수준이다. UIKit S2의 24는 3회 중 2회가 튄 값이고, baseline도 한 번 21까지 튀어 측정 잡음으로 본다 (아래 분석) |

## 대가

PLAN.md의 대가 지표로 각 Stage가 얻은 것과 잃은 것을 비교한다. 수치는 UIKit / SwiftUI 순서다.

| Stage | 대가 | 지표 | S0 대비 | 얻은 것 |
|---|---|---|---|---|
| S1 | 계산량은 그대로이고 결과 전체 위치를 미리 계산 | `CPU` avg | 52.4 → 68.2% / 63.8 → 76.9% | 메인 스레드 분리: `inputDelay` 57.9 → 12.0ms / 63.6 → 10.3ms, hitch 483.7 → 0.0 / 563.3 → 40.4ms/s |
| S1 | 검색 한 번이 더 오래 걸림 | `filterTime` | 46.1 → 58.2ms / 46.0 → 58.5ms | |
| S1 | 결과가 입력보다 늦게 따라옴 | `resultLatency` | 46.7 → 58.8ms / 48.5 → 60.4ms | |
| S1 | 화면에 한 번도 나오지 못한 검색어 | `skippedResults` | 0 → 13% / 0 → 16% | |
| S1 | 미리 계산한 일치 위치 | `searchMemory` | 0.13 → 0.33MB / 0.14 → 0.31MB | |
| S2 | 인덱스 + 결과 스택 | `searchMemory` | 0.13 → 3.79MB / 0.14 → 3.79MB | 계산량 감소: `filterTime` 0.73 / 0.35ms, `resultLatency` 2.33 / 5.12ms, CPU avg 15.2 / 24.0%, `skippedResults` 0% |
| S2 | 실제 메모리 증가 | `Memory` peak | 54.8 → 58.4MB / 64.8 → 70.2MB | |
| S2 | 화면을 연 뒤 첫 검색 전 준비 시간 | `indexBuildTime` | 0 → 25.2ms / 0 → 24.5ms | |
| S2 | 코드 복잡도 (정성) | - | 검색 타입 1개 → 3개 (`Stage2Index`, `Stage2ResultStack`, `Stage2Search`), 스택 불변식 관리 | |
| S2 | (계획에 없던 대가) S1보다 hitch 증가 | `Hitch` ratio | S1 0.0 → 105.6ms/s, 40.4 → 101.3ms/s | 원인 미확정. 아래 분석의 가설 참고 |

## 분석

**S0: 메인 스레드가 막힌다.** 입력이 100ms마다 오고, 메인 스레드는 입력마다 5만 개 이름을 `lowercased()`로 새로 만들어 `contains`로 비교한다 (`filterTime` 약 46ms).
그동안 프레임을 그리지 못해 hitch ratio가 483.7 / 563.3ms/s, FPS가 절반 아래(29.6 / 24.5)로 떨어진다.
1초에 입력 10번 × 약 48ms씩 밀린 프레임이 쌓인 값이라, hitch ratio가 입력 간격보다 큰 것이 자연스럽다.

**S1: 메인은 비었지만 일은 줄지 않았다.** 같은 계산을 백그라운드로 옮기자 UIKit hitch가 0, `inputDelay`가 12.0ms로 내려갔다.
대신 `filterTime`(58ms)과 `resultLatency`(59ms)는 오히려 늘었고 CPU도 올랐다. 결과 전체의 위치를 미리 구하는 일이 더해졌고, 메인 스레드와 코어를 나눠 썼기 때문이다.
`resultLatency`는 적용된 결과만 평균하므로, 13~16%의 검색어가 화면에 나오지 못한 사실(`skippedResults`)과 함께 읽어야 한다.
SwiftUI S1의 hitch 40.4ms/s는 결과를 적용할 때 `List`가 최대 2만 개 id를 비교하는 비용이 메인 스레드에 남아 있기 때문으로 보인다 (Instruments로 확인하지는 않았다).

**S2: 일 자체를 줄였다.** 인덱스로 이름 변환이 사라지고 비교가 숫자 배열 비교가 되면서 `filterTime`이 0.73 / 0.35ms가 됐다. CPU는 15.2 / 24.0%로 S0의 1/3 이하다.
- `filterTime` 평균은 경로가 섞인 값이다. 스크립트 62단계 중 23단계(지우기)는 스택의 결과를 다시 쓰는 reuse라 계산이 없다.
  같은 일끼리 비교하면, Mac에서 5만 개 전체를 훑는 경우 S1 방식 40~63ms가 0.6ms였다 (LEARNING [Stage 2]의 마이크로 측정, 정식 아님).
- 효과의 대부분은 인덱스(이름 변환 제거, UTF-16 비교)에서 나왔다. 검색어 소문자 변환을 루프 밖으로 뺀 효과는 긴 검색어에서만 약 13%였다.
- 대가로 메모리가 늘었다. UIKit의 `Memory` 증가(3.8MB)는 `searchMemory` 추정 차이(3.46MB)와 비슷해, 이름 5만 개의 UTF-16 사본과 배열 헤더가 증가분의 대부분이다.
  SwiftUI는 7.2MB로 추정치의 약 두 배다. `List`와 `AttributedString` 쪽 메모리일 수 있지만 Allocations로 확인하지 않았다.

**S2의 hitch가 S1보다 늘었다.** CPU는 줄었는데 hitch ratio가 0.0 → 105.6ms/s(UIKit), 40.4 → 101.3ms/s(SwiftUI)로 늘었다. 원인은 확정하지 못했고 가설은 두 가지다.
- (a) **낮은 부하에서 메인 스레드가 느려진다.** Time Profiler에서 셀 수는 비슷한데(highlight signpost 2,184 vs 2,436) 같은 셀 생성 코드가 고르게 약 3배 느렸다.
  전체 CPU 사용이 낮으면 코어 클럭이 낮게 머물거나 효율 코어에서 실행될 수 있다. Mac에 CPU 부하를 걸자 UIKit hitch가 줄었다 (89 → 39ms/s, 진단용).
- (b) **입력 갱신과 목록 갱신이 한 프레임에 몰린다.** S2는 결과가 입력 2~5ms 뒤에 도착해, 입력창 갱신과 목록 갱신이 같은 프레임에 들어간다.
  S1은 약 60ms 뒤라 둘이 다른 프레임으로 나뉘었다. CPU 부하를 걸어도 그대로였던 SwiftUI에 더 맞는 설명이다.
- 실기기 측정과 Instruments(CPU 코어 배치, Animation Hitches)로 확인한 뒤 결론을 낸다.

**Threads peak은 이 측정에서 신뢰하기 어렵다.** 3회 값이 baseline [8, 9, 21], UIKit S0 [23, 10, 10], UIKit S1 [10, 30, 9], UIKit S2 [25, 10, 24]처럼 Stage와 상관없이 한 번씩 튄다.
튀지 않은 값은 모든 조합에서 9~13개다. 백그라운드 Task를 쓰는 S1, S2도 S0보다 스레드가 늘지 않았다. Swift Concurrency가 코어 수만큼의 공용 스레드 풀에서 작업을 돌리기 때문이다.

**편차 경고.** 측정 도구가 Threads peak(baseline, UIKit S0, UIKit S1), FPS min(S0 두 조합), Hitch count(SwiftUI S1)에 편차 경고를 냈다.
FPS min과 Hitch count는 S0처럼 프레임이 크게 흔들리는 조합에서 자연스러운 편차다. 결론에는 중앙값이 안정적인 FPS avg, hitch ratio, CPU, Memory를 주로 썼다.

## Instruments 관찰

시뮬레이터 Release 빌드를 `xctrace`의 Time Profiler로 10초씩 기록한 결과다 (참고용).

- **S0 UIKit:** 메인 스레드 시간의 약 25%가 `lowercased()`, 약 45%가 `contains`(Foundation `StringProtocol.contains`), 약 14%가 CA commit이었다.
- **S1 vs S2 UIKit:** 메인 스레드 샘플(1ms 단위)이 S1 748 → S2 1,342개였다. `cellForRowAt`이 91 → 314샘플인데, 지연 하이라이트 계산(`Stage2Index.highlights`)은 1샘플뿐이었다.
  `UIFont.bold` getter(8 → 35), UIKit 내부 프레임처럼 S1과 같은 코드가 고르게 약 3배 느렸다. signpost 개수(applyResults 184 vs 200, highlight 2,184 vs 2,436)는 비슷해 일의 양은 같았다.
- 실기기에서 확인할 것: Animation Hitches로 S2 hitch가 입력 프레임에 몰리는지, CPU 코어 배치(성능/효율 코어), SwiftUI S2의 Allocations.
