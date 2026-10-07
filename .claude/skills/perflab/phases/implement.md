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
8. **체크포인트 `[Stage N]` (구현 후)**:
   - 이전 Stage 대비 핵심 변경을 코드 위치(`파일:라인`)와 함께 3줄 이내로 짚는다.
   - 이해 확인 질문 1개를 던지고, 궁금한 점이 있는지 묻는다.
   - 시뮬레이터로 앱을 직접 실행해 HUD 수치를 확인해 보라고 권한다 (정식 측정은 measure 단계).
9. LEARNING.md에 `### [Stage N]` 기록을 남긴다.
10. `scripts/perflab advance <topic>` 후 종료 보고하고 멈춘다.

## 주의

- Stage 0을 일부러 느리게 만들지 않는다. 리뷰어가 이 부분을 가장 먼저 본다.
- 이번 Stage의 범위를 넘는 최적화를 미리 넣지 않는다.
- 구현 중 계획이 맞지 않는다는 것을 알게 되면 멈추고 사용자와 PLAN.md 수정을 논의한다. 계획을 몰래 바꾸지 않는다.
