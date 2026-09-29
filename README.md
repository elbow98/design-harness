# design-harness

개인 디자인 하네스 v0 (Will Newton 방식). Claude Code / Aside 공유 폴더.

```
Rules.md            하네스 행동 규칙 · 도구 · 절대 금지 · 교정 로그
Design.md           컬러 · 타입 · 간격 · 컴포넌트 · 철학 · anti-slop
CLAUDE.md           Claude Code가 위 두 파일을 자동으로 읽게 함
vault/              tokens.css(토큰 원본) · components.html · charts.html(카탈로그) · rejected/(거절 화면)
outputs/            프로토타입 (폴더 1개 = 프로토타입 1개) → GitHub Pages 배포 대상
scripts/            new · serve · index · check(드리프트) · shot(렌더 검증)
skills/             explore(변형 탐색) · wrap-session(학습 누적)  ← .claude/skills 로 연결
templates/          새 프로토타입 템플릿
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
```

Claude Code에서:
- "이 카드 컴포넌트 변형 6개 탐색해줘" → `explore` 스킬
- "세션 마무리, 내가 교정한 거 규칙에 반영해줘" → `wrap-session` 스킬

## 다른 프로젝트에서 쓰기

`check.sh`는 `.tsx/.ts/.jsx`에서 문자열 안 색(`#hex`·`rgb(a)(`)·인라인 CSS 문자열의 px·`style={{…}}` 숫자·Tailwind 임의값(`text-[13px]`·`bg-[#abc]`)·Tailwind 기본 팔레트(`bg-blue-600`)를 잡는다. `node_modules`·`.next`·테스트 파일은 건너뛴다. 토큰을 JS로 옮긴 파일(지도 색 등)은 `--allow` 또는 대상 폴더(상위 포함)의 `.harnesscheckignore`(한 줄에 glob 하나)로 빼고, 한 줄만 빼려면 그 줄에 `// harness-ignore`.
`shot.sh`의 넘침 검사는 조상 중 `overflow`가 visible이 아닌 요소 안(잘리는 지도 타일, 가로 스크롤 표 래퍼)은 제외하고, 페이지 전체 `scrollWidth`는 그대로 본다.

전역 스킬 `~/.claude/skills/my-design` — 아무 폴더에서 "내 디자인으로 만들어줘"라고 하면 이 폴더의 Design.md·tokens.css를 읽어 적용한다.
HTML이면 `<link rel="stylesheet" href="https://elbow98.github.io/design-harness/vault/tokens.css">` 한 줄로도 된다.

## 배포

- 레포: https://github.com/elbow98/design-harness (공개)
- 사이트: https://elbow98.github.io/design-harness/ → `outputs/` 목록 · 카탈로그는 `/vault/components.html`
- 방식: main 브랜치 루트를 그대로 Pages로 서빙 (`.nojekyll`). **main에 push하면 1~2분 뒤 반영된다.**
- `reference/`는 다른 작성자 자료라 git에서 제외(로컬 전용).
