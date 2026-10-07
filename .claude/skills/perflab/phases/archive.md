# Phase: archive (summarized → archived)

목표: 주제를 아카이브에 등록하고 마무리한다.

## 절차

1. `scripts/perflab readme`로 README Topics 표를 갱신한다.
2. README Backlog에 이 주제와 겹치는 후보가 있으면 지운다. 진행 중에 떠오른 새 후보가 있으면 Backlog에 추가한다 (LEARNING.md의 "남은 궁금증" 참고).
3. `scripts/perflab advance <topic>`을 실행한다.
4. 커밋 여부를 묻는다. 메시지 예: `[#NN] archived: <제목>`
5. `main`에 머지할지 묻는다. 승인되면 `docs/COMMITS.md` 4절대로 `--no-ff` 머지하고 브랜치를 지운다. push는 요청이 있을 때만 한다.
6. 회고 질문 하나로 마무리한다: "다음 주제에서 파이프라인이나 체크포인트를 바꾸고 싶은 점이 있나요?"
   - 개선 의견이 나오면 skill과 규칙 수정을 제안한다. 파이프라인 변경은 모든 주제에 적용되므로 사용자 승인 후에 반영한다.
