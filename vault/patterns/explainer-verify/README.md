# explainer.html 검증 기록 (2026-10-14)

대상: `vault/patterns/explainer.html` · 규격: Design.md §14 · 근거: `reference/explainer-research.md` §3.1·§4

## 기계 검사 — `scripts/verify.sh vault/patterns/explainer.html`

| 검사 | 결과 |
|---|---|
| check 토큰 드리프트 | 통과 (0건) |
| slop AI 티 | 통과 (0건, Impeccable 4.1.0 + 하네스 보조) |
| shot 렌더·접근성 | 통과 — 1280·390 × 라이트·다크 4장 넘침·콘솔 에러 0, axe critical·serious 0 |

남은 경고 1건: 본문 안 용어 버튼 `.ex-ref` 터치 타깃 28×26. 문장 속 인라인 요소라 WCAG 2.5.8 inline 예외로 두었다.

## 상호작용 — `interact.py` (375px · 다크 · `prefers-reduced-motion: reduce`)

| 항목 | 결과 |
|---|---|
| 375px 가로 넘침 | 없음 |
| reduced-motion | 진행 막대 `transition-duration` 0s (tokens.css 전역 규칙) |
| 키보드만 | Tab 34개 정지점이 테마 → 목차 → 표 → 슬라이더·눈금 4개 → 다음 단계 → 본문 용어 3개 → 그래프 노드 7개 → 비교표 → 출처 순으로 한 바퀴 |
| `.ex-slider` | → 키로 `aria-valuetext` "블록 수정", End로 "저장소 전체", 결과 칸 갱신 |
| `.ex-stepper` | Enter 8번 → 상태 줄 "8/8단계 · 종료 · 끝났어요", 기록 8줄, `다음 단계` 비활성, 포커스 `처음부터`, `aria-current="step"`은 종료 노드 |
| `.ex-linked` | 노드 포커스만으로 설명 칸 갱신(hover 불필요), Enter 고정(`aria-pressed=true`, 연결선 4개 강조), Esc 해제, 본문 용어 Enter가 같은 노드를 고정 |
| `.ex-scrolly` | 375px: sticky 없이 단계별 정적 그림 4장. 1280px: 단계 1→4 스크롤마다 그림 `aria-label` 전환 |
| 콘솔 에러 | 0 |

## 디자인 리뷰 — `skills/critique` (분리된 서브에이전트, 스크린샷만)

판정 **통과** · 기준표 21/24 · 휴리스틱 11/12. 지적 7건 중 반영:

- P1 하네스 표가 390px에서 "추론적" 열을 단서 없이 숨김 → 640px 이하 카드형 행(`.ex-stack-sm`, `data-label`)
- P2 눈금 라벨 두 줄 깨짐 → 640px 이하 가운데 두 라벨 시각적 숨김(§14), 결과 정의 목록 세로 쌓기
- P2 슬라이더 그림만 폭이 좁음 → `.ex-wide`로 다른 그림과 통일
- P2 스크롤 연동 단계 글이 본문선 밖에서 시작 → 1024px 이상 `padding-left: var(--sp-20)`로 본문선에 맞춤(1440·1280·1024 실측 일치)
- P2 손잡이 정지점과 눈금 라벨 어긋남 → 눈금 칸 1:2:2:1, 양 끝은 트랙 끝에 붙임
- P3 전체 지도 캡션이 옆 정의를 반복 → 출처 성격 문장으로 교체
- P3 스크롤 연동 오른쪽 빈 공간 → 전체 페이지 캡처의 sticky 착시. 실제 스크롤 전환은 위 표로 확인

## 실물 예시 대비 바꾼 곳 (조사 문서 §3.1)

자체 hex → 토큰(`--concept-n`은 `var(--concept-n, var(--series-n))` 폴백) · 17px/1.72·920px → 16/1.65·68ch · 주황 primary 버튼 → secondary · 마우스 전용 툴팁 → 고정 설명 칸 + 포커스·Enter·Esc · range `aria-label`만 → 보이는 label + `aria-valuetext` + 눈금 버튼 · `transition .25s` → `--dur-base` · 6초 무한 회전 애니메이션 → 삭제
