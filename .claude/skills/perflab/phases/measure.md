# Phase: measure (stage2 → measured)

목표: 모든 Stage×Framework를 같은 조건으로 측정하고, 예측과 비교해 분석한다.

## 절차

1. **측정 기기를 정한다.** 사용자에게 실기기 측정이 가능한지 묻는다.
   - 가능하면 `scripts/perflab devices`로 이름을 확인하고 `--device "<이름>"`을 쓴다. 실기기에서는 서명(Team) 설정이 필요할 수 있다.
   - 불가능하면 시뮬레이터로 측정하고, 결과가 참고용임을 문서에 밝힌다.
2. **체크포인트 `[Measure]` (측정 전)**: 결과를 보기 전에 예측을 받는다.
   - 예) "S0 대비 S2의 FPS, Hitch, 메모리는 각각 어떻게 변할까? UIKit과 SwiftUI 중 어느 쪽이 더 빠를까?"
   - 예측은 숫자나 방향(↑↓→)으로 받는다.
3. 측정 (Release 빌드, 기본 warm-up 2초 / 측정 10초 / 3회 반복 중앙값, baseline 포함. 약 5~6분 소요):

   ```bash
   scripts/perflab measure <topic> [--device "<이름>"]
   scripts/perflab table <topic>
   ```

   측정 중에는 기기를 조작하지 않도록 안내한다. 편차 경고(⚠)가 나오거나 이상치가 의심되면 다시 측정하고, 그 사실을 기록한다.
   Stage 간 차이가 Baseline 수준이면 의미 있는 차이로 해석하지 않는다. 지표의 한계는 `docs/GUIDE.md` 5절을 참고한다.
4. RESULTS.md를 작성한다.
   - **예측 vs 실제** 표에 사용자 예측과 실제 수치를 함께 적는다.
   - **대가**: PLAN.md의 대가 지표로 Stage마다 얻은 것과 잃은 것을 표로 비교한다.
   - **분석**: Stage별 변화의 원인을 지표와 연결해서 설명한다.
   - **Instruments 관찰**: 필요하면 사용자에게 Instruments 확인을 권하고, 사용자가 공유한 내용을 정리한다. 직접 확인하지 못한 내용은 쓰지 않는다.
5. **체크포인트 `[Measure]` (측정 후)**: 예측과 크게 다른 지점 1~2개를 골라 "왜 그랬을까?"를 함께 추론한다.
6. LEARNING.md에 `### [Measure]` 기록을 남긴다.
7. `scripts/perflab advance <topic>` 후 종료 보고하고 멈춘다.
