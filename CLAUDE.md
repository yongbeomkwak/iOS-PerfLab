# iOS-PerfLab

실제 앱에서 마주치는 성능 문제를 **Naive → Optimized → Low-level** 단계로 구현하고, 측정하고, 기록하는 iOS 성능 실험실.
구현은 Claude가 맡고, 사용자는 각 단계의 **체크포인트**에서 예측하고, 질문하고, 이해를 확인하며 학습한다.

## 가장 중요한 원칙

1. **모든 주제는 같은 파이프라인을 따른다.** 주제 작업은 반드시 `/perflab` skill로 진행한다.
2. **상태 전환은 `scripts/perflab advance`로만 한다.** `topic.json`의 `status`를 직접 수정하지 않는다.
3. **체크포인트를 건너뛰지 않는다.** 사용자 답을 받기 전에는 다음 작업으로 넘어가지 않는다.
4. **측정 없는 결론은 없다.** 수치는 `results/*.json`에서만 인용하고, 추정치를 사실처럼 쓰지 않는다.
5. **First-party only.** 서드파티 라이브러리를 추가하지 않는다. UI는 시스템 컴포넌트를 쓴다.

## 파이프라인

```
proposed → planned → stage0 → stage1 → stage2 → measured → summarized → archived
```

| 상태 | 완료 조건 (`scripts/perflab validate`가 검사) |
|---|---|
| proposed | `topic.json` 작성, Package.swift / TopicCatalog 등록 |
| planned | `docs/PLAN.md`, `Scenario.swift`에 TODO 없음, LEARNING `[Plan]` |
| stageN | Stage N의 UIKit/SwiftUI 파일에 `PERFLAB: NOT_IMPLEMENTED` 없음, LEARNING `[Stage N]` |
| measured | 한 기기에서 모든 Stage×Framework 결과 JSON, RESULTS.md 완성, LEARNING `[Measure]` |
| summarized | `docs/SUMMARY.md`에 TODO 없음 |
| archived | README Topics 표에 등록 |

## 구조

```
PerfLab.xcodeproj        # 얇은 앱 셸 (탭/리스트) + PerfLabUITests (자동 측정)
App/                     # 앱 소스 (폴더 동기화 그룹)
AppUITests/              # BenchmarkUITests: launch argument로 주제/Stage/Framework 지정 후 측정
Packages/
  Shared/                # 공통 모델, PerfTopic 프로토콜, PerfMonitor/HUD, 벤치마크, NotImplemented
  Topics/
    Package.swift        # 주제 모듈 목록 (scripts/perflab new가 자동 등록)
    Catalog/             # TopicCatalog: 앱에 노출되는 주제 목록 (자동 등록)
    <Category>/<NN-slug>/
      topic.json         # 메타데이터 + status
      Topic.swift        # PerfTopic 구현 (Stage → 화면 매핑)
      Scenario.swift     # 모든 Stage가 공유하는 입력 (seed 고정)
      UIKit/Stage{0,1,2}ViewController.swift
      SwiftUI/Stage{0,1,2}View.swift
      Tests/             # 시나리오 결정성, Stage 간 결과 정합성
      docs/              # PLAN, LEARNING, RESULTS, SUMMARY
      results/<device>/stage<N>-<framework>.json
Templates/Topic/         # 새 주제 템플릿
scripts/perflab          # 파이프라인 CLI
```

## 명령어

```bash
scripts/perflab status                 # 전체 주제 상태와 다음 단계
scripts/perflab new --category <rendering|animation|concurrency|memory|dataIO> \
  --slug <kebab-case> --title "<제목>" --summary "<한 줄 설명>" --tags A,B
scripts/perflab validate <topic>       # 현재 상태 조건 검사
scripts/perflab advance <topic>        # 다음 상태 조건 검사 후 전환
scripts/perflab test <topic>           # 주제 단위 테스트 (시뮬레이터)
scripts/perflab measure <topic> [--device "<실기기 이름>"]   # Release 자동 측정
scripts/perflab table <topic>          # RESULTS.md 결과표 생성
scripts/perflab readme                 # README Topics 표 갱신
scripts/perflab devices                # 측정 가능한 기기 목록

# 앱 빌드 확인
xcodebuild -project PerfLab.xcodeproj -scheme PerfLab \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' build
```

## 기술 기준

- iOS 17+, Swift 6 (strict concurrency), SPM 로컬 패키지
- 측정은 Release 빌드 기준이며, 실기기가 정식 결과이고 시뮬레이터는 참고용이다.
- 공통 지표: FPS(avg/min), Hitch(count, ms/s), CPU(avg/peak), Memory(avg/peak), Threads(peak)
- 주제별 지표는 `context.metrics.record(_:value:unit:)` / `context.metrics.measure(_:_:)`로 기록한다.
- 구간 분석은 `PerfSignpost.signposter`로 남겨 Instruments에서 확인한다.

## 언어

- 문서, 커밋 메시지 본문, 사용자와의 대화는 한국어로 쓴다.
- 코드 식별자와 주석은 주변 코드 스타일을 따른다 (주석은 한국어).
