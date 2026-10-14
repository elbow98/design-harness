# design-harness

개인 디자인 하네스 v1 (Will Newton 방식, 2026-10-14 업그레이드). Claude Code / Aside 공유 폴더.

```
Rules.md            하네스 행동 규칙 · 도구 · 절대 금지 · 교정 로그
Design.md           컬러 · 타입 · 간격 · 컴포넌트 · 철학 · anti-slop
CLAUDE.md           Claude Code가 위 두 파일을 자동으로 읽게 함
vault/              tokens.css(토큰 원본) · components.html · charts.html(카탈로그) · patterns/(대시보드·상세·설정)
                    themes/(브랜드 테마) · export/(DTCG·Tailwind·DESIGN.md 생성물) · baselines/(시각 회귀 기준선)
                    taste/(좋은 화면) · rejected/(거절 화면) · glossary.md(용어집) · format.js(숫자·날짜 표기)
outputs/            프로토타입 (폴더 1개 = 프로토타입 1개) → GitHub Pages 배포 대상
scripts/            new · serve · index · check(드리프트) · slop(AI 티) · shot(렌더·접근성) · diff(시각 회귀) · verify(통합)
                    tokens/ build(내보내기) · ramp(브랜드색 사다리) · check_theme(테마 검사)
skills/             explore(변형 탐색) · critique(디자인 리뷰) · brand(브랜드·테마) · wrap-session(학습 누적)  ← .claude/skills
templates/          새 프로토타입 템플릿 (prototype.html 기본, dashboard.html 대시보드 뼈대)
reference/          Aside가 수집한 참고자료 (읽기 전용)
inbox/              Aside → Claude Code 전달함
index.html          Pages 루트 → outputs/ 로 이동
```

## 사용법

```bash
scripts/new.sh onboarding "온보딩 첫 화면" "가입 직후 3단계"   # 새 프로토타입
scripts/serve.sh                                               # http://localhost:4321/outputs/
scripts/check.sh outputs/2026-09-23-onboarding                 # 토큰 드리프트 검사
scripts/shot.sh outputs/2026-09-23-onboarding/index.html        # 1280·390 × 라이트·다크 렌더 검증
scripts/check.sh ~/Projects/app/web/app ~/Projects/app/web/components   # Next.js·React(.tsx/.ts/.jsx)도 검사
scripts/check.sh --allow web/lib/mapColors.ts web/                      # 예외 파일 (또는 .harnesscheckignore)
scripts/shot.sh http://localhost:3000/ /tmp/shots                      # 로컬 개발 서버 URL도 됨
scripts/index.sh                                               # outputs/index.html 목록 갱신
scripts/new.sh --template dashboard pf "포트폴리오" "월간 점검"  # 대시보드 뼈대로 시작
scripts/verify.sh outputs/2026-09-23-onboarding                # check → slop → shot(접근성 포함) 한 번에
scripts/slop.sh outputs/2026-09-23-onboarding                  # AI 티 탐지 (Impeccable + 하네스 보조)
scripts/diff.sh baseline vault/components.html                 # 시각 회귀 기준선 → vault/baselines/components/
scripts/diff.sh compare vault/components.html                  # 기준선과 픽셀 비교
scripts/tokens/build.py                                        # tokens.css → vault/export/ (DTCG·Tailwind v4·DESIGN.md)
scripts/tokens/ramp.py "#0B6E80" --css 새브랜드                  # 브랜드 seed → 12단계 사다리 + theme.css 초안
scripts/tokens/check_theme.py 새브랜드                           # 테마 대비·구조·차트 팔레트 검사
scripts/tokens/build.py --theme 새브랜드                         # 브랜드 테마를 얹은 사본 → vault/export/새브랜드/
```

Claude Code에서:
- "이 카드 컴포넌트 변형 6개 탐색해줘" → `explore` 스킬
- "이 화면 디자인 리뷰해줘", "뭐가 어색한지 봐줘" → `critique` 스킬
- "스터디카페 브랜드 색 잡아줘", "새 테마 만들어줘" → `brand` 스킬
- "세션 마무리, 내가 교정한 거 규칙에 반영해줘" → `wrap-session` 스킬

## 다른 프로젝트에서 쓰기

`check.sh`는 `.tsx/.ts/.jsx`에서 문자열 안 색(`#hex`·`rgb(a)(`)·인라인 CSS 문자열의 px·`style={{…}}` 숫자·Tailwind 임의값(`text-[13px]`·`bg-[#abc]`)·Tailwind 기본 팔레트(`bg-blue-600`)를 잡는다. `node_modules`·`.next`·테스트 파일은 건너뛴다. 토큰을 JS로 옮긴 파일(지도 색 등)은 `--allow` 또는 대상 폴더(상위 포함)의 `.harnesscheckignore`(한 줄에 glob 하나)로 빼고, 한 줄만 빼려면 그 줄에 `// harness-ignore`.
`shot.sh`의 넘침 검사는 조상 중 `overflow`가 visible이 아닌 요소 안(잘리는 지도 타일, 가로 스크롤 표 래퍼)은 제외하고, 페이지 전체 `scrollWidth`는 그대로 본다.

전역 스킬 `~/.claude/skills/my-design` — 아무 폴더에서 "내 디자인으로 만들어줘"라고 하면 이 폴더의 Design.md·tokens.css를 읽어 적용한다.
HTML이면 `<link rel="stylesheet" href="https://elbow98.github.io/design-harness/vault/tokens.css">` 한 줄로도 된다.

Tailwind v4 프로젝트는 `vault/export/tailwind-theme.css`를 tokens.css 다음에 import한다(`@theme inline reference` — 유틸리티가 tokens.css 변수를 직접 참조하고 Tailwind 기본 팔레트·간격은 꺼진다). 다른 AI 디자인 도구(Google Stitch 등)에는 `vault/export/DESIGN.md`, Figma·Style Dictionary에는 `tokens.dtcg.json` + `tokens.resolver.json`을 넘긴다. tokens.css를 고치면 `scripts/tokens/build.py`를 다시 돌린다.
숫자·날짜 표기는 `vault/format.js`(`fmt.krw(123456789, "short")` → `1억 2,346만원`)를 복사해 쓴다.

## 배포

- 레포: https://github.com/elbow98/design-harness (공개)
- 사이트: https://elbow98.github.io/design-harness/ → `outputs/` 목록 · 카탈로그는 `/vault/components.html`
- 방식: main 브랜치 루트를 그대로 Pages로 서빙 (`.nojekyll`). **main에 push하면 1~2분 뒤 반영된다.**
- `reference/`는 다른 작성자 자료라 git에서 제외(로컬 전용).

## claude.ai 디자인 시스템 (슬라이드·Artifact용)

- claude.ai 계정의 Design System Artifact "Design Harness" (https://claude.ai/artifact/5P4RCA4tcBpM9Wk3rEEcuT, 비공개)가 이 하네스의 사본이다. Slides·디자인 Artifact를 만들 때 이것이 입혀진다.
- 2026-10-14 v1으로 동기화(`1e3b6f3` 기준): tokens.json(텍스트3·경고색·Slide 글자 단계·zIndex·size), README, 숫자·문구·대시보드·슬라이드·테마 절, 컴포넌트 21종.
- 2026-10-14 `0e93872` 기준 재동기화: 코발트 강조색(`02491ac`), §6 앱 셸 → `components/Navigation/README.md`(App shell rules)·`dashboard.md`(페이지 전체 범위는 도구 막대 예외)·`design-system.json` lastChange. Version 7.
- 2026-10-14 `0c0bcc3` 기준 재동기화: §14 해설 페이지 → `explainer.md`(새 절)·`components/Explainer/`(README + preview = `vault/patterns/explainer.html`)·`bundle.css`에 `--concept-1…3`·`-soft` 별칭(tokens.json은 변경 없음)·README 컴포넌트 목록과 움직임 예외·`design-system.json` lastChange. Version 9.
- 원본은 이 레포다. Design.md·tokens.css·components.html을 바꾸면 세션 끝(wrap-session)에 이 Artifact도 다시 동기화한다.
