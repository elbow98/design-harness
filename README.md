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
scripts/index.sh                                               # outputs/index.html 목록 갱신
```

Claude Code에서:
- "이 카드 컴포넌트 변형 6개 탐색해줘" → `explore` 스킬
- "세션 마무리, 내가 교정한 거 규칙에 반영해줘" → `wrap-session` 스킬

## 다른 프로젝트에서 쓰기

전역 스킬 `~/.claude/skills/my-design` — 아무 폴더에서 "내 디자인으로 만들어줘"라고 하면 이 폴더의 Design.md·tokens.css를 읽어 적용한다.
HTML이면 `<link rel="stylesheet" href="https://elbow98.github.io/design-harness/vault/tokens.css">` 한 줄로도 된다.

## 배포

- 레포: https://github.com/elbow98/design-harness (공개)
- 사이트: https://elbow98.github.io/design-harness/ → `outputs/` 목록 · 카탈로그는 `/vault/components.html`
- 방식: main 브랜치 루트를 그대로 Pages로 서빙 (`.nojekyll`). **main에 push하면 1~2분 뒤 반영된다.**
- `reference/`는 다른 작성자 자료라 git에서 제외(로컬 전용).
