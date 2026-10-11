# Phase: archive (summarized → archived)

목표: 주제를 아카이브에 등록하고 마무리한다.

## 절차

1. `scripts/perflab readme`로 README Topics 표를 갱신한다.
2. README Backlog에 이 주제와 겹치는 후보가 있으면 지운다. 진행 중에 떠오른 새 후보가 있으면 Backlog에 추가한다 (LEARNING.md의 "남은 궁금증" 참고).
3. `scripts/perflab advance <topic>`을 실행한다.
4. 커밋 여부를 묻는다. 메시지 예: `[#NN] archived: <제목>`
5. **PR로 머지할지 묻는다.** 주제 브랜치는 로컬 `main`에 머지하지 않고 GitHub PR로 머지한다 (`docs/COMMITS.md` 4절 "주제 브랜치: PR").
   원격에 올리는 일이므로 승인을 받은 뒤 아래 순서로 진행한다.
   - 공개 저장소에 올리면 안 되는 내용(서명 Team ID, 기기 식별자, 로컬 경로)이 커밋과 커밋 메시지에 없는지 검색한다.
   - 로컬 `main`이 원격보다 앞서 있으면 먼저 push한다 (PR에 주제 커밋만 보이게 하기 위해서다).
   - 주제 브랜치를 push하고 PR을 연다. 본문에는 Stage별 전략, 실기기 핵심 결과, 확인한 것, 확인하지 않은 것을 쓴다.
   - PR을 merge commit 방식으로 머지하고, 로컬 `main`을 맞춘 뒤 로컬과 원격의 주제 브랜치를 지운다.
6. 회고 질문 하나로 마무리한다: "다음 주제에서 파이프라인이나 체크포인트를 바꾸고 싶은 점이 있나요?"
   - 개선 의견이 나오면 skill과 규칙 수정을 제안한다. 파이프라인 변경은 모든 주제에 적용되므로 사용자 승인 후에 반영한다.
