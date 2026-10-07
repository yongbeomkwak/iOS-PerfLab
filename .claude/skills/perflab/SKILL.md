---
name: perflab
description: iOS-PerfLab 주제를 파이프라인(proposed → planned → stage0~2 → measured → summarized → archived)에 따라 진행한다. 새 주제 제안, 이어서 진행, 상태 확인 등 주제 작업 요청이 오면 항상 이 skill을 사용한다. "/perflab", "새 주제", "다음 단계", "이어서 진행", "주제 진행" 요청 시 사용.
argument-hint: "[new | <topic-id> | status]"
---

# PerfLab 파이프라인 진행

모든 주제는 이 문서의 절차를 **그대로** 따른다. 주제마다 진행 방식이 달라지면 안 된다.

## 0. 시작: 현재 위치 파악

1. `scripts/perflab status`를 실행한다.
2. 인자에 따라 진행할 대상을 정한다.
   - `new`: [phases/propose.md](phases/propose.md)
   - `<topic-id>`: 해당 주제
   - 인자 없음: `archived`가 아닌 주제가 있으면 그 주제를 이어서 진행한다 (여러 개면 사용자에게 고르게 한다). 없으면 `new`로 간다.
   - `status`: 상태 표만 보여주고 끝낸다.
3. 대상 주제의 `topic.json` status를 보고 **다음 단계**의 phase 문서를 읽은 뒤 그대로 수행한다.

| 현재 status | 다음 단계 | 읽을 문서 |
|---|---|---|
| (없음) | proposed | [phases/propose.md](phases/propose.md) |
| proposed | planned | [phases/plan.md](phases/plan.md) |
| planned / stage0 / stage1 | stage0 / stage1 / stage2 | [phases/implement.md](phases/implement.md) |
| stage2 (마지막 Stage) | measured | [phases/measure.md](phases/measure.md) |
| measured | summarized | [phases/summarize.md](phases/summarize.md) |
| summarized | archived | [phases/archive.md](phases/archive.md) |

`topic.json`의 `stages`에 없는 Stage는 건너뛴다 (`scripts/perflab status`의 `next` 값이 기준).

## 공통 규칙

- **체크포인트**: 모든 단계에는 사용자에게 묻는 지점이 있다. 방식은 [checkpoints.md](checkpoints.md)를 따른다.
  질문을 던졌으면 **그 턴을 끝내고 답을 기다린다.** 답을 가정하고 진행하지 않는다.
- **한 번에 한 단계**: 한 단계를 마치면 `scripts/perflab advance <topic>`으로 전환하고, 결과를 보고한 뒤 멈춘다.
  사용자가 "계속"이라고 하면 다음 단계로 간다.
- **advance 실패 시**: 출력된 미충족 항목을 해결한 뒤 다시 시도한다. 검증을 우회하지 않는다.
- **빌드 확인**: 코드를 바꾼 단계는 끝내기 전에 `scripts/perflab lint`, `scripts/perflab build`, `scripts/perflab test <topic>`이 통과해야 한다.
- **규칙**: 코드는 `docs/CONVENTIONS.md`와 `.claude/rules/topics.md`, 문서는 `.claude/rules/docs.md`를 따른다.
- **커밋**: 단계가 끝날 때마다 커밋할지 사용자에게 묻는다. 제목은 `[#NN] <status>: <요약>`이다. 예) `[#01] stage1: 셀 이미지 비동기 디코딩`
  본문은 `docs/COMMITS.md`의 구획(`왜:`, `설정:`, `변경:`, `확인:`)을 따른다. 설정을 바꿨다면 `설정:`에 무엇/왜를 남긴다.

## 단계 종료 보고 형식

```
✔ #NN <제목> — <이전 상태> → <새 상태>
- 한 일: (2~4줄)
- 배운 것: (이번 체크포인트의 핵심 1~2줄)
- 다음 단계: <다음 상태> — <무엇을 할지 한 줄>
```
