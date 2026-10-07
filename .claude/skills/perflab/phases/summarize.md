# Phase: summarize (measured → summarized)

목표: 주제를 블로그에 올릴 수 있는 글(`docs/SUMMARY.md`)로 정리한다.

## 절차

1. 재료를 모은다: PLAN.md, LEARNING.md, RESULTS.md, 각 Stage 파일의 전략 주석, 핵심 코드.
2. `docs/SUMMARY.md` 템플릿을 채운다 (`.claude/rules/docs.md` 준수).
   - **단계별 구현**: Stage마다 핵심 코드 스니펫 1개 이하를 넣는다. 전체 코드는 레포 링크로 대신한다.
   - **측정 결과**: RESULTS.md 표에서 핵심 지표만 추려서 넣는다. 기기와 빌드 구성을 명시한다.
   - **필요한 CS 지식**: 개념마다 2~4문장으로 설명하고, 어느 Stage와 연결되는지 밝힌다.
   - **예측과 실제**: LEARNING.md의 사용자 예측을 근거로 쓴다.
   - **트레이드오프 & 회고**: 실무에서는 어느 Stage까지 적용할지 판단 기준을 남긴다.
3. **체크포인트 (리뷰)**: 초안 요약을 보여주고 묻는다.
   - 빠진 내용, 고칠 표현, 강조할 부분이 있는지
   - 마지막 확인 질문: "이 주제를 한 문장으로 설명한다면?" → 사용자 답을 SUMMARY의 한 줄 요약 후보로 쓴다.
4. 피드백을 반영하고 `scripts/perflab advance <topic>` 후 종료 보고하고 멈춘다.
