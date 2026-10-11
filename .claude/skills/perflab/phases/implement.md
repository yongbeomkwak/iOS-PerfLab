# Phase: implement (planned → stage0 → stage1 → stage2)

목표: PLAN.md의 Stage 전략대로 Stage 하나를 UIKit과 SwiftUI로 구현한다. **한 번 실행할 때 Stage 하나만** 진행한다.

## 절차

1. 진행할 Stage N을 확인한다 (`scripts/perflab status`의 next).
2. PLAN.md의 Stage N 전략과 이전 Stage 구현을 읽는다.
3. **체크포인트 `[Stage N]` (구현 전)**:
   - Stage 0: "가장 자연스러운 구현이 어떤 모습일지", 그리고 "어디서 느려질 것 같은지" 묻는다.
   - Stage 1~2: 이번 전략을 한 줄로 소개하고 묻는다.
     - 이 방법이 **왜** 빨라질까? (어떤 비용을 줄이는가)
     - 대신 무엇을 대가로 치를까? (메모리, 복잡도, 정확도 등)
   - 답을 받은 뒤 짧게 해설하고 구현을 시작한다.
4. 구현한다 (`.claude/rules/topics.md` 준수).
   - `SwiftUI/StageNView.swift`, `UIKit/StageNViewController.swift`
   - `// PERFLAB: NOT_IMPLEMENTED` 마커를 지우고, `docs/CONVENTIONS.md` 6절 형식으로 머리말(`// 전략:`, `// 변경:`)과 구획을 쓴다.
   - Benchmark 모드 자동 재생을 구현한다.
   - 핵심 구간에 signpost를, 필요하면 커스텀 지표를 넣는다.
5. 정합성 테스트를 추가하거나 갱신한다 (Stage N의 결과가 Stage 0과 같은지).
6. 검증:

   ```bash
   scripts/perflab format <주제 경로>
   scripts/perflab test <topic>
   scripts/perflab build
   ```

7. `stage-reviewer` 에이전트로 공정성 리뷰를 받고, 지적 사항을 반영하거나 반영하지 않은 이유를 사용자에게 알린다.
8. **코드 검증**: `code-verifier` 에이전트에 주제 경로와 Stage 번호만 넘긴다. 구현 의도나 대화 내용은 넘기지 않는다 (코드만 보고 판단하게 한다).
   - 보고를 `docs/VERIFICATION.md`에 `### [Stage N]`으로 붙인다. 판정은 고치지 않는다.
   - ⚠️ 추정, ❌ 틀림은 하나씩 조치하고 `조치` 열에 적는다.
     - 실험이나 문서로 확인한다 → 근거와 함께 "확인함"
     - 확인할 수 없다 → 주석에서 단정을 빼거나 "추정"이라고 밝힌다. 문서(PLAN, LEARNING)에 같은 주장이 있으면 함께 고친다
     - 틀렸거나 필요 없는 코드다 → 고치거나 지운다
   - 조치로 코드를 바꿨으면 6번 검증을 다시 돌리고, 바뀐 부분을 `code-verifier`에 다시 넘긴다. 새 지적이 없을 때까지 반복한다.
   - 끝나면 `scripts/perflab fingerprint <topic>`의 출력을 그 섹션의 `- 지문:` 줄에 적는다.
9. **체크포인트 `[Stage N]` (구현 후)**:
   - 이전 Stage 대비 핵심 변경을 코드 위치(`파일:라인`)와 함께 3줄 이내로 짚는다.
   - 검증에서 ⚠️/❌였던 항목과 조치를 숨기지 않고 알린다. 무엇이 불확실했는지가 학습 자료다.
   - 이해 확인 질문 1개를 던지고, 궁금한 점이 있는지 묻는다.
   - 시뮬레이터로 앱을 직접 실행해 HUD 수치를 확인해 보라고 권한다 (정식 측정은 measure 단계).
10. LEARNING.md에 `### [Stage N]` 기록을 남긴다.
11. `scripts/perflab advance <topic>` 후 종료 보고하고 멈춘다.

## 주의

- Stage 0을 일부러 느리게 만들지 않는다. 리뷰어가 이 부분을 가장 먼저 본다.
- 이번 Stage의 범위를 넘는 최적화를 미리 넣지 않는다.
- **검증 뒤에 코드를 바꾸면 다시 검증한다.** 체크포인트에서 사용자의 지적으로 코드를 고친 경우, 다른 단계에서 주제 코드를 고친 경우도 같다.
  `advance`는 VERIFICATION.md의 마지막 지문이 지금 코드와 다르면 실패한다. 지문만 새로 적어 넘어가지 않는다.
- 근거 없이 단정하는 주석을 쓰지 않는다 (`docs/CONVENTIONS.md` 5절 "사실 주장").
- 구현 중 계획이 맞지 않는다는 것을 알게 되면 멈추고 사용자와 PLAN.md 수정을 논의한다. 계획을 몰래 바꾸지 않는다.
