# Phase: propose (→ proposed)

목표: 실제 앱에서 있을 법한 성능 문제를 주제로 정하고, 주제 폴더를 만든다.

## 절차

1. 기존 주제(`scripts/perflab status`, README Backlog)와 겹치지 않는 후보를 **3개** 준비한다.
   각 후보는 아래 기준을 만족해야 한다.
   - 실제 서비스에서 흔히 마주치는 상황이다. (어떤 앱의 어떤 화면인지 구체적으로)
   - Stage 0 → 2로 갈수록 **측정 가능한 차이**가 날 것으로 예상된다.
   - Stage 2에서 다룰 저수준 주제(CoreGraphics, CoreAnimation, Metal, GCD, 메모리 레이아웃 등)가 분명하다.
   - 사용자가 따로 요청하지 않았다면 이전 주제보다 지나치게 무겁지 않다.
2. 후보를 아래 형식으로 제시하고 **사용자 선택을 기다린다** (체크포인트).

   ```
   1) <제목 (질문형)> — <카테고리>
      상황: ...
      예상 병목: ...
      Stage 전략 미리보기: S0 ... → S1 ... → S2 ...
      태그: A, B, C
      난이도: ★☆☆ ~ ★★★
   ```

3. 선택되면 주제를 만든다.

   ```bash
   scripts/perflab new --category <category> --slug <kebab-case> \
     --title "<질문형 제목>" --summary "<한 줄 설명>" --tags A,B,C
   ```

4. 사용하지 않을 Stage나 프레임워크가 있으면 `topic.json`의 `stages` / `frameworks`를 조정한다. 기본은 모두 사용한다.
5. `scripts/perflab validate <topic>`을 실행하고 앱 빌드를 확인한다.
6. 종료 보고 후 멈춘다. 다음 단계는 plan이다.

## 제목 규칙

- 질문형으로 쓴다. 예) "수천 장의 이미지 피드를 끊김 없이 스크롤하려면?"
- slug는 영문 kebab-case로 쓴다. 예) `image-feed-scroll`
