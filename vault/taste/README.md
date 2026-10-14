# taste — 마음에 드는 화면 모음

말로 설명하기 어려운 취향을 쌓는 곳이다. `vault/rejected/`가 "이렇게 하지 마"라면 여기는 "이런 게 좋다".
`reference/`(다른 작성자 자료, 읽기 전용·git 제외)와 다르다: 여기는 사용자가 직접 고른 것이고 git으로 추적한다.

## 넣는 법
사용자가 "이 화면 좋다", "이런 느낌으로"라며 URL·스크린샷을 주면 Claude가 정리한다.

```
vault/taste/<YYYY-MM-DD>-<slug>.png     스크린샷 (데스크톱 1장, 필요하면 -mobile.png)
vault/taste/<YYYY-MM-DD>-<slug>.md      아래 형식
```

```markdown
---
source: https://…            # 원본 URL (없으면 "스크린샷 제공")
kind: 대시보드 | 상세 | 폼 | 랜딩 | 지도 | 차트 | 매장·브랜드
liked: 사용자가 실제로 한 말 한 줄 ("숫자가 한눈에 들어와")
score:                       # (선택) critique 보정 예시면 "기준표 20/24 · 이유 한 줄". 나쁜 예도 점수와 함께 넣는다
---
- 좋은 이유(구조): 무엇이 그 느낌을 만드는지 Claude가 해석 — 정렬선, 간격 비율, 위계, 밀도
- 실측: DOM·CSS에서 잰 값(본문 크기·행간, 패널 여백, 표 행 높이, 최대 폭). 값은 참고용, 하네스에는 토큰으로 옮김
- 하네스와 다른 점: 레퍼런스가 하네스 규칙과 부딪히는 곳(예: 카드 그림자) — 따라 할지 말지는 사용자 결정
- 가져갈 것 1~3개
```

## 쓰는 곳
- `skills/explore` 1단계: 재료로 같은 `kind`의 레퍼런스를 먼저 연다.
- `skills/critique` 0단계: `score:`가 붙은 사례 1~2개를 리뷰어에게 보정 예시(few-shot)로 준다. 좋은 예·나쁜 예 합쳐 종류별 3~5장이 목표.
- `skills/brand` 2단계: 매장·브랜드 레퍼런스.
- 같은 이유("숫자가 한눈에")가 3번 쌓이면 wrap-session에서 Design.md 규칙 후보로 제안한다.

## 원칙
- 브랜드 자산(로고·일러스트·고유 폰트)은 가져오지 않는다. 구조와 비율만 배운다(Rules.md §3-2).
- 실측 없이 스크린샷 인상만으로 값을 적지 않는다.

## 참고 (critique·brand 근거)
- Anthropic, Harness design for long-running apps (2026-03): https://www.anthropic.com/engineering/harness-design-long-running-apps
- impeccable critique·init: https://github.com/pbakaus/impeccable
- taste-skill: https://github.com/Leonxlnx/taste-skill
- UICrit (UIST 2024): https://arxiv.org/abs/2407.08850 · Duan 외 (CHI 2024): https://arxiv.org/abs/2403.13139
- Liner Pencil 디자인 하네스: https://liner.com/ko/blog/liner-pencil-design-harness
- 긱뉴스 "나만의 디자인 하네스 만들기": https://news.hada.io/topic?id=34096 · "슬롭 UI 10가지 단서": https://news.hada.io/topic?id=34370
