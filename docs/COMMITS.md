# 커밋 컨벤션

이 레포의 커밋 로그는 **학습 기록**이기도 하다. 특히 Xcode, Package, Info.plist 같은 설정 변경은 코드보다 이유를 잊기 쉽다.
그래서 커밋 하나만 읽어도 "**무엇을, 왜** 바꿨고, 그 설정이나 API가 **무엇인지**"를 알 수 있게 쓴다.

## 1. 제목

```
<type>(<scope>): <무엇을 위해 무엇을 했는지 한 줄>
```

- 한국어로 쓰고, 50자 안팎에서 마침표 없이 끝낸다.
- **"무엇을 바꿨다"보다 "왜 바꿨다"가 드러나게** 쓴다.
  - ✅ `build(app): ProMotion iPhone에서 FPS 측정이 60Hz로 묶이지 않게 하기`
  - ❌ `build(app): Info.plist 키 추가`
- 주제 파이프라인의 단계 커밋은 `[#NN] <status>: <요약>` 형식을 쓴다. 예) `[#01] stage1: 셀 이미지를 백그라운드에서 디코딩`

| type | 언제 |
|---|---|
| `feat` | 기능 추가 (앱, Shared, CLI) |
| `fix` | 잘못된 동작이나 잘못된 측정값 수정 |
| `refactor` | 동작 변화 없는 구조 변경 |
| `build` | **설정 변경**: Xcode 빌드 설정, scheme, Info.plist, `Package.swift`, `.swift-format`, `.claude/settings.json` |
| `style` | 포맷만 바꾼 변경 (`scripts/perflab format` 결과) |
| `test` | 테스트만 추가하거나 수정 |
| `docs` | 문서, `.claude/`의 규칙과 skill |
| `chore` | 위에 속하지 않는 잡무 (`.gitignore` 등) |

scope는 `app`, `shared`, `topics`, `cli`(scripts/perflab), `claude`, `docs` 중 하나를 쓴다. 여러 곳에 걸치면 생략한다.

## 2. 본문

제목과 본문 사이는 한 줄 비운다. 본문은 아래 구획을 **이 순서로** 쓰고, 해당 없는 구획은 생략한다.

| 구획 | 내용 | 필수 |
|---|---|---|
| `왜:` | 무엇이 문제였는지, 어떤 근거로 알게 됐는지 (측정값, 로그, 헤더 문서) | 항상 |
| `설정:` | 바꾼 설정마다 `이전 → 이후`, **무엇**(그 설정이 뭔지), **왜**(이 값으로 정한 이유) | `build` 커밋 |
| `변경:` | 코드 변경마다 무엇을 바꿨는지와, 쓴 API나 개념이 무엇인지 한 줄 | 코드 변경 |
| `확인:` | 어떻게 검증했는지 (빌드, 테스트, 측정, 산출물 확인) | 항상 |

- 항목은 `- `로 시작하고, 한 줄은 100자 안팎으로 끊는다.
- "무엇"은 공식 문서나 헤더의 설명을 **내 말로 짧게** 옮긴다. 기본값과, 끄거나 켰을 때 무엇이 달라지는지를 적는다.
- 수치는 실제로 확인한 것만 쓴다.
- Claude가 작성한 커밋은 마지막에 `Co-Authored-By:` 트레일러를 붙인다.

### 설정 변경 예시

```
build(app): ProMotion iPhone에서 FPS 측정이 60Hz로 묶이지 않게 하기

왜:
- iPhone은 이 키가 없으면 CADisplayLink를 60Hz로 제한한다. 120Hz 기기에서 FPS와 hitch를 제대로 잴 수 없다.

설정:
- CADisableMinimumFrameDurationOnPhone (Info.plist): 없음 → YES
  - 무엇: iPhone에서 CADisplayLink와 커스텀 애니메이션이 60Hz를 넘을 수 있게 허용하는 키. iPad는 기본으로 허용한다.
  - 왜: 측정 상한을 기기 최대 주사율로 맞추기 위해서다.
- INFOPLIST_FILE (빌드 설정): 없음 → Config/Info.plist
  - 무엇: 생성된 Info.plist(GENERATE_INFOPLIST_FILE)에 합칠 plist 파일 경로.
  - 왜: 이 키는 INFOPLIST_KEY_* 빌드 설정으로 넣을 수 없어서 파일이 필요하다.

확인:
- 빌드 산출물 Info.plist에 키가 들어간 것을 plutil로 확인
```

### 코드 변경 예시

```
fix(shared): CPU 사용률이 종료된 스레드를 빠뜨리지 않게 하기

왜:
- thread_info의 cpu_usage는 스케줄러의 감쇠 추정치이고, 샘플 사이에 끝난 GCD 스레드가 빠진다.

변경:
- SystemMetrics.cpuTime(): getrusage(RUSAGE_SELF)로 프로세스 누적 CPU 시간을 읽는다.
  - getrusage: 프로세스가 쓴 user/system 시간을 종료된 스레드까지 포함해 돌려주는 POSIX API.
- PerfMonitor: 두 샘플의 CPU 시간 차이 ÷ 경과 시간으로 사용률을 구한다.

확인:
- 호출 비용 비교 (macOS, 스레드 20개): thread_info 루프 30µs → getrusage 0.2µs
- Shared 테스트 통과, 시뮬레이터 측정 정상
```

## 3. 커밋 단위

- **한 커밋에는 한 가지 의도만** 담는다. 설정 변경과 그 설정을 쓰는 코드는 같은 커밋에 둬도 된다.
- 포맷만 바뀐 변경은 `style` 커밋으로 분리한다. 로직 변경과 섞으면 diff를 읽기 어렵다.
- 주제 파이프라인은 단계마다 커밋한다. Stage 커밋 본문의 `변경:`은 Stage 파일 머리말(`// 전략:`, `// 변경:`)을 그대로 쓴다.

## 4. 템플릿

루트의 [`.gitmessage`](../.gitmessage)를 커밋 템플릿으로 쓸 수 있다.

```bash
git config commit.template .gitmessage
```
