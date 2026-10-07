# iOS-PerfLab

실제 앱에서 마주치는 성능 문제를 **Naive → Optimized → Advanced** 단계로 구현하고, 측정하고, 기록하는 iOS 성능 실험실.
구현은 Claude가 맡고, 사용자는 각 단계의 **체크포인트**에서 예측하고, 질문하고, 이해를 확인하며 학습한다.

- 사람용 진행 가이드: `docs/GUIDE.md` (파이프라인, 역할, 측정 해석)
- 코드 컨벤션: `docs/CONVENTIONS.md` — **Swift 코드를 쓰기 전에 읽는다.**
- 커밋과 브랜치 컨벤션: `docs/COMMITS.md` — **커밋 메시지를 쓰기 전에 읽는다.** 설정 변경은 `설정:` 구획에 무엇/왜를 남긴다.

## 가장 중요한 원칙

1. **모든 주제는 같은 파이프라인을 따른다.** 주제 작업은 반드시 `/perflab` skill로 진행한다.
2. **상태 전환은 `scripts/perflab advance`로만 한다.** `topic.json`의 `status`를 직접 수정하지 않는다.
3. **체크포인트를 건너뛰지 않는다.** 사용자 답을 받기 전에는 다음 작업으로 넘어가지 않는다.
4. **측정 없는 결론은 없다.** 수치는 `results/*.json`에서만 인용하고, 추정치를 사실처럼 쓰지 않는다.
5. **First-party only.** 서드파티 라이브러리를 추가하지 않는다. UI는 시스템 컴포넌트를 쓴다.
6. **코드를 바꾸면 `scripts/perflab format`과 `scripts/perflab lint`를 통과시킨다.**
7. **최적화는 저수준 API만이 아니다.** 자료구조, 값/참조 타입(`class` ↔ `struct`), 메모리, 동시성, 구조 개선 등 CS 지식 전반을 쓴다 (`docs/GUIDE.md` 3절).
8. **작업마다 브랜치를 딴다.** 주제는 `topic/<NN>-<slug>`, 그 밖은 `<type>/<kebab-case>`. `main`에 직접 커밋하지 않고, 작업이 끝나면 사용자 확인 후 `--no-ff`로 머지한다 (`docs/COMMITS.md` 4절).

## 파이프라인

```
proposed → planned → stage0 → stage1 → stage2 → measured → summarized → archived
```

| 상태 | 완료 조건 (`scripts/perflab validate`가 검사) |
|---|---|
| proposed | `topic.json` 작성, Package.swift / TopicCatalog 등록 |
| planned | `docs/PLAN.md`, `Scenario.swift`에 TODO 없음, LEARNING `[Plan]` |
| stageN | Stage N의 UIKit/SwiftUI 파일에 `PERFLAB: NOT_IMPLEMENTED` 없음, `// 전략:`(+ 첫 Stage 이후 `// 변경:`) 머리말, 주제 폴더 lint 통과, LEARNING `[Stage N]` |
| measured | 한 기기에서 모든 Stage×Framework + baseline 결과 JSON, RESULTS.md 완성, LEARNING `[Measure]` |
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
Config/Info.plist        # 생성 Info.plist에 합쳐지는 키 (120Hz display link)
docs/                    # GUIDE(사람용 진행 가이드), CONVENTIONS(코드 컨벤션), COMMITS(커밋과 브랜치 컨벤션)
.gitmessage              # 커밋 메시지 템플릿
.swift-format            # swift-format 설정
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
scripts/perflab measure <topic> [--device "<실기기 이름>"] [--repeat 3]   # Release 자동 측정 (baseline 포함, 중앙값)
scripts/perflab table <topic>          # RESULTS.md 결과표 생성
scripts/perflab readme                 # README Topics 표 갱신
scripts/perflab devices                # 측정 가능한 기기 목록
scripts/perflab build                  # 앱 빌드 (SDK가 지원하는 iPhone 17 Pro 시뮬레이터 자동 선택)
scripts/perflab format [경로...]       # swift-format 자동 정리
scripts/perflab lint [경로...]         # swift-format 검사
```

## 기술 기준

- iOS 17+, Swift 6 (strict concurrency), SPM 로컬 패키지
- 측정은 Release 빌드 기준이며, 실기기가 정식 결과이고 시뮬레이터는 참고용이다.
- 공통 지표: FPS(avg/min), Hitch(count, ms/s), CPU(avg/peak), Memory(avg/peak), Threads(peak)
  - 측정은 조합마다 기본 3회 반복해 중앙값을 쓰고, 빈 화면 baseline(노이즈 바닥)을 함께 측정한다.
  - FPS/Hitch는 메인 스레드 프레임 처리 기준이다. 렌더 서버 hitch는 Instruments로 확인한다 (`docs/GUIDE.md` 5절).
- 주제별 지표는 `context.metrics.record(_:value:unit:)` / `context.metrics.measure(_:_:)`로 기록한다.
- 구간 분석은 `PerfSignpost.signposter`로 남겨 Instruments에서 확인한다.

## 언어

- 문서, 커밋 메시지(제목과 본문), 사용자와의 대화는 한국어로 쓴다. 커밋 type과 scope만 영어다.
- 코드 식별자는 영어, 주석은 한국어로 쓴다. 주석과 MARK의 기준은 `docs/CONVENTIONS.md`를 따른다.
