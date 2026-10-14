# 토큰 내보내기 (생성물)

이 폴더의 파일은 `scripts/tokens/build.py`가 `vault/tokens.css`에서 만든다. **직접 고치지 않는다** — tokens.css(와 Design.md)를 고치고 다시 생성한다.
같은 입력이면 같은 출력이다(타임스탬프 없음, tokens.css 순서 유지). 테마별 사본은 `<테마 이름>/` 아래에 있다(`build.py --theme <이름>`).

| 파일 | 형식 | 쓰는 곳 |
|---|---|---|
| `tokens.dtcg.json` | W3C Design Tokens Format Module 2025.10, 라이트(기본) 세트 | Figma Tokens Studio, Style Dictionary 등 DTCG를 읽는 도구 |
| `tokens.dark.dtcg.json` | 같은 형식, 다크에서 값이 바뀌는 토큰만 | 위 세트 위에 얹는 오버라이드 |
| `tokens.resolver.json` | DTCG Resolver Module 2025.10 | 두 세트를 `theme` 수식자(light/dark)로 합치는 방법 |
| `tailwind-theme.css` | Tailwind v4 `@theme inline reference` | Next.js 등 Tailwind 프로젝트 |
| `DESIGN.md` | Google DESIGN.md (alpha) | Stitch 등 다른 AI 디자인 도구에 넘기는 휴대용 사본 |

## 라이트·다크를 DTCG에서 어떻게 나눴나

DTCG 2025.10은 값 하나에 모드 여러 개를 담는 문법이 없고, 모드·테마는 **Resolver 모듈**이 맡는다: 세트(set) 여러 개를 수식자(modifier)의 맥락(context)에 따라 순서대로 합친다. 그래서 `$extensions`에 다크 값을 숨기지 않고 표준 쪽을 택했다.

- 라이트 = 기본 세트(`tokens.dtcg.json`), 다크 = 바뀌는 토큰만 담은 오버라이드 세트(`tokens.dark.dtcg.json`), `tokens.resolver.json`의 `modifiers.theme.contexts.dark`가 오버라이드를 얹는다. tokens.css의 `:root` / `:root[data-theme="dark"]` 구조와 같다.
- 별칭(`--chart-grid: var(--border)` → `{color.border}`)은 다크 세트에 넣지 않는다. 대상이 바뀌면 따라간다.
- `color-mix()`로 정의된 `--*-soft`는 모드별로 계산한 값을 넣고, 원식은 `$extensions["com.elbow98.design-harness"].css`에 남겼다.
- 640px 이하 글자 축소·여백은 해당 토큰의 `$extensions…mobile`에 있다(DTCG에 미디어 쿼리 개념이 없다).
- 자간 `-0.02em`: DTCG dimension은 px·rem만 허용 → 기본 토큰은 `number`(-0.02, 확장에 `unit: em`), 합성 typography 토큰에는 글자 크기를 곱한 px로 넣었다.
- 굵기(`fontWeight`)와 합성 `typography`는 tokens.css에 변수가 없어 Design.md §3 표에서 가져왔다(`build.py`의 `FONT_WEIGHTS`·`TYPE_ROLES`).
- Resolver 문법은 2025.10 초판을 기억에 의존해 썼다. 이 파일을 실제로 읽는 도구가 생기면 그 도구로 한 번 검증한다.

## Tailwind v4에 붙이기

```css
/* app/globals.css */
@import "tailwindcss";
@import "./tokens.css";            /* 값의 원본 — 다크·테마 전환은 여기 변수가 한다 */
@import "./theme.css";             /* 브랜드 테마가 있으면 */
@import "./tailwind-theme.css";
```

- `@theme inline reference`라서 Tailwind는 테마 변수를 하나도 내보내지 않는다. 유틸리티가 tokens.css 변수를 직접 참조하므로(`bg-accent` → `background-color: var(--accent)`) 다크·테마 전환이 그대로 된다. `--font-sans`·`--shadow-pop`·`--tracking-tight`처럼 Tailwind 네임스페이스와 이름이 같은 토큰도 자기참조 순환이 생기지 않는다.
- 네임스페이스마다 `initial`로 Tailwind 기본값을 껐다. `p-7`·`bg-blue-600`·`text-lg`·`rounded-xl`·`shadow-lg`·`leading-tight`·`blur-sm`은 생성되지 않는다(2026-10-14 `@tailwindcss/cli@4.3.3`로 확인).
- **Tailwind는 없는 클래스를 에러 없이 무시한다.** 위 클래스를 써도 빌드는 통과하고 스타일만 빠진다. 드리프트는 `scripts/check.sh <소스 폴더>`로 잡는다(Rules.md §6).
- 클래스 이름: `bg-accent` `text-text-2` `border-border-strong` `fill-series-1` · `p-4`(= `--sp-4`, 토큰 단계 1·2·3·4·5·6·8·10·14·20만) · `text-h1` `text-sm` `text-d-xs` · `rounded-md` · `shadow-pop` · `font-heading`(650) · `max-w-page` · `ease-standard` · 브레이크포인트 `sm:`(640) `lg:`(1024).
- 테마 네임스페이스가 없는 값은 변수로 직접: `duration-(--dur-fast)` `z-(--z-modal)` `w-(--sidebar-w)` `h-(--topbar-h)` `min-h-(--hit-min)`.

## DESIGN.md

- front matter 토큰 + 정해진 섹션 순서(Overview → Colors → Typography → Layout → Elevation & Depth → Shapes → Components → Do's and Don'ts). 본문은 Design.md 요약이다.
- 색은 6자리 hex만 받으므로 라이트 값을 기본 이름으로, 다크 값은 `dark-` 접두로 넣었다. 알파가 있는 색(`--backdrop`)은 뺐다. `primary` = accent.
- 검사: `npx @google/design.md@0.4.0 lint vault/export/DESIGN.md` → errors 0. 경고는 전부 `orphaned-tokens`(차트·지도·다크 색이 컴포넌트 토큰에서 참조되지 않음)로, 이 시스템에선 정상이다. 컴포넌트 쌍 대비 경고는 0건.
