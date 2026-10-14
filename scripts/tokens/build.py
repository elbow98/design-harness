#!/usr/bin/env python3
"""vault/tokens.css(단일 원본) → 다른 도구용 내보내기 3종. 표준 라이브러리만 쓴다.

  vault/export/tokens.dtcg.json       W3C DTCG 2025.10 — 라이트(기본) 세트
  vault/export/tokens.dark.dtcg.json  다크에서 값이 바뀌는 토큰만 (오버라이드 세트)
  vault/export/tokens.resolver.json   DTCG Resolver 2025.10 — theme 수식자(light/dark)로 위 두 세트를 합치는 방법
  vault/export/tailwind-theme.css     Tailwind v4 `@theme inline reference` — 값 대신 var(--토큰) 참조
  vault/export/DESIGN.md              Google DESIGN.md(alpha) — 다른 AI 디자인 도구에 넘기는 휴대용 사본

사용:
  scripts/tokens/build.py                    → vault/export/
  scripts/tokens/build.py --theme _sample-warm → vault/export/_sample-warm/ (vault/themes/<이름>/theme.css를 얹은 값)
같은 입력이면 같은 출력(타임스탬프 없음, tokens.css 순서 유지).
"""
import sys
sys.dont_write_bytecode = True  # scripts/tokens/에 __pycache__를 남기지 않는다

import argparse
import json
import re
import sys

import tokencss as tc
from colorlib import parse_color, to_hex

NS = "com.elbow98.design-harness"

# Design.md §3 — 굵기는 tokens.css에 변수가 없어 여기서 정한다(Design.md와 같이 고친다)
FONT_WEIGHTS = {"regular": 400, "medium": 500, "semibold": 600, "heading": 650, "bold": 700}
# (역할, 굵기 이름, 제목 자간 여부) — Design.md §3 표
TYPE_ROLES = [("display", "bold", True), ("h1", "bold", True), ("h2", "heading", True), ("h3", "semibold", True),
              ("body", "regular", False), ("sm", "regular", False), ("xs", "medium", False)]
BREAKPOINTS = {"sm": "640px", "lg": "1024px"}  # Design.md §4

PREFIX_GROUPS = [("fs-", "fontSize"), ("lh-", "lineHeight"), ("tracking-", "letterSpacing"), ("font-", "fontFamily"),
                 ("sp-", "spacing"), ("r-", "radius"), ("shadow-", "shadow"), ("dur-", "duration")]
_DIM = re.compile(r"^(-?\d*\.?\d+)(px|rem)$")
_NUM = re.compile(r"^-?\d*\.?\d+$")
_EM = re.compile(r"^(-?\d*\.?\d+)em$")
_MS = re.compile(r"^(\d*\.?\d+)(ms|s)$")
_BEZ = re.compile(r"^cubic-bezier\(([^)]*)\)$")
_ALIAS = re.compile(r"^var\(--([\w-]+)\)$")


def _n(x):
    x = float(x)
    return int(x) if x.is_integer() else round(x, 4)


def classify(name, light):
    """토큰 이름·값 → (DTCG 그룹, 키). 모르는 값이면 None."""
    for pre, grp in PREFIX_GROUPS:
        if name.startswith(pre):
            return grp, name[len(pre):]
    if name == "ease" or name.startswith("ease-"):
        return "easing", "standard" if name == "ease" else name[5:]
    if name.startswith("z-") and _NUM.match(light[name]):
        return "zIndex", name[2:]
    if tc.resolve_color(light, name):
        return "color", name
    if _DIM.match(tc.resolve(light, name)):
        return "size", name
    return None


# ---------------------------------------------------------------- DTCG 값 변환
def dtcg_color(rgba):
    v = {"colorSpace": "srgb", "components": [round(c, 4) for c in rgba[:3]], "hex": to_hex(rgba).lower()}
    if rgba[3] < 1:
        v["alpha"] = round(rgba[3], 4)
    return v


def dtcg_dim(s):
    m = _DIM.match(s)
    return {"value": _n(m.group(1)), "unit": m.group(2)}


def _split_top(s, sep=","):
    out, depth, cur = [], 0, ""
    for c in s:
        depth += c == "("
        depth -= c == ")"
        if c == sep and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += c
    return out + [cur.strip()]


def dtcg_shadow(s):
    layers = []
    for part in _split_top(s):
        m = re.match(r"^(inset\s+)?((?:-?[\d.]+(?:px)?\s+){2,4})(.+)$", part)
        lens = m.group(2).split()
        lens += ["0"] * (4 - len(lens))
        layer = {"color": dtcg_color(parse_color(m.group(3)))}
        for k, v in zip(("offsetX", "offsetY", "blur", "spread"), lens):
            layer[k] = {"value": _n(v.rstrip("px")), "unit": "px"}
        if m.group(1):
            layer["inset"] = True
        layers.append(layer)
    return layers if len(layers) > 1 else layers[0]


def dtcg_token(name, grp, values):
    """(type, value, extensions) — values는 한 모드의 실효 값."""
    raw = values[name]
    ext = {}
    if grp == "color":
        rgba = tc.resolve_color(values, name)
        if not parse_color(tc.resolve(values, name)):
            ext["css"] = raw  # color-mix 등: 계산 값 + 원식
        return "color", dtcg_color(rgba), ext
    if grp == "fontFamily":
        fams = [f.strip().strip('"\'') for f in _split_top(raw)]
        return "fontFamily", fams, ext
    if grp == "zIndex":
        return "number", _n(raw), ext
    if grp == "lineHeight":
        return ("number", _n(raw), ext) if _NUM.match(raw) else ("dimension", dtcg_dim(raw), ext)
    if grp == "letterSpacing":
        m = _EM.match(raw)
        # DTCG dimension은 px·rem만 허용 → em 배수는 number로 두고 원식을 남긴다
        return "number", _n(m.group(1)), {"css": raw, "unit": "em"}
    if grp == "shadow":
        return "shadow", dtcg_shadow(raw), ext
    if grp == "duration":
        m = _MS.match(raw)
        ms = float(m.group(1)) * (1000 if m.group(2) == "s" else 1)
        return "duration", {"value": _n(ms), "unit": "ms"}, ext
    if grp == "easing":
        m = _BEZ.match(raw)
        return "cubicBezier", [_n(x) for x in m.group(1).split(",")], ext
    return "dimension", dtcg_dim(tc.resolve(values, name)), ext


def build_dtcg(merged):
    light = tc.mode_values(merged, "light")
    dark = tc.mode_values(merged, "dark")
    index, skipped = {}, []
    for name in light:
        c = classify(name, light)
        if c:
            index[name] = c
        else:
            skipped.append(name)

    def ref(name):
        g, k = index[name]
        return "{" + g + "." + k + "}"

    def tok(name, values):
        g, k = index[name]
        m = _ALIAS.match(values[name])
        if m and m.group(1) in index:
            return {"$type": tok(m.group(1), values)["$type"], "$value": ref(m.group(1))}
        typ, val, ext = dtcg_token(name, g, values)
        t = {"$type": typ, "$value": val}
        if name in merged["mobile"]:
            ext["mobile"] = {"maxWidth": "640px", "css": merged["mobile"][name]}
        if ext:
            t["$extensions"] = {NS: ext}
        return t

    base = {"$description": "design-harness 토큰 — vault/tokens.css에서 생성(scripts/tokens/build.py). 직접 고치지 않는다."}
    over = {"$description": "다크 모드 오버라이드 — 라이트 세트 위에 얹는다(tokens.resolver.json의 theme=dark)."}
    for name, (g, k) in index.items():
        base.setdefault(g, {})[k] = tok(name, light)
        if _ALIAS.match(light[name]):
            continue  # 별칭은 대상이 바뀌면 따라간다
        if tok(name, dark)["$value"] != base[g][k]["$value"]:
            over.setdefault(g, {})[k] = tok(name, dark)
    base["fontWeight"] = {k: {"$type": "fontWeight", "$value": v} for k, v in FONT_WEIGHTS.items()}
    typo = {}
    for role, weight, heading in TYPE_ROLES:
        if f"fs-{role}" not in light:
            continue
        size = dtcg_dim(light[f"fs-{role}"])
        ls = 0
        if heading and "tracking-tight" in light:
            ls = round(float(_EM.match(light["tracking-tight"]).group(1)) * size["value"], 4)
        typo[role] = {"$type": "typography", "$value": {
            "fontFamily": "{fontFamily.sans}", "fontSize": f"{{fontSize.{role}}}",
            "fontWeight": f"{{fontWeight.{weight}}}", "lineHeight": f"{{lineHeight.{role}}}",
            "letterSpacing": {"value": _n(ls), "unit": "px"}}}
    base["typography"] = typo
    return base, over, skipped, index


RESOLVER = {
    "version": "2025.10",
    "name": "design-harness",
    "description": "라이트가 기본 세트, 다크는 theme 수식자가 고르는 오버라이드 세트.",
    "sets": {"base": {"sources": [{"$ref": "tokens.dtcg.json"}]}},
    "modifiers": {"theme": {
        "description": "tokens.css의 :root / :root[data-theme=\"dark\"] (+ prefers-color-scheme: dark)",
        "contexts": {"light": [], "dark": [{"$ref": "tokens.dark.dtcg.json"}]},
        "default": "light"}},
    "resolutionOrder": [{"$ref": "#/sets/base"}, {"$ref": "#/modifiers/theme"}],
}


# ---------------------------------------------------------------- Tailwind v4
def build_tailwind(merged, index, theme):
    light = tc.mode_values(merged, "light")
    L = []
    w = L.append
    w("/* tailwind-theme.css — vault/tokens.css에서 생성(scripts/tokens/build.py). 직접 고치지 않는다.")
    if theme:
        w(f"   테마: vault/themes/{theme}/theme.css — tokens.css 다음에 그 파일도 불러온다.")
    w("")
    w("   쓰는 법 (globals.css):")
    w('     @import "tailwindcss";')
    w('     @import "./tokens.css";          ← 값의 원본. 다크·테마 전환은 여기 변수가 한다')
    if theme:
        w('     @import "./theme.css";')
    w('     @import "./tailwind-theme.css";')
    w("")
    w("   `inline reference`: Tailwind는 테마 변수를 하나도 내보내지 않고, 유틸리티가 tokens.css 변수를 직접 참조한다")
    w("   (bg-accent → background-color: var(--accent)). 그래서 다크·테마 전환이 그대로 되고,")
    w("   --font-sans·--shadow-pop·--tracking-tight처럼 이름이 Tailwind 네임스페이스와 같아도 자기참조 순환이 없다.")
    w("")
    w("   각 네임스페이스의 `initial`은 Tailwind 기본값(bg-blue-600, p-7, text-sm, rounded-xl…)을 꺼서 토큰 밖 클래스를 못 만들게 한다.")
    w("   단, Tailwind는 없는 클래스를 에러 없이 조용히 무시한다 — 클래스가 사라질 뿐 빌드는 통과한다.")
    w("   드리프트 검사는 scripts/check.sh <소스 폴더>를 같이 돌린다(Rules.md §6).")
    w("")
    w("   클래스 이름: 색 bg-accent · text-text-2 · border-border-strong · fill-series-1 / 간격 p-4 (= --sp-4, 4px 단위 토큰만)")
    w("   글자 text-h1 · text-sm · text-d-xs(조밀) / 반경 rounded-md / 그림자 shadow-pop / 굵기 font-heading(650)")
    w("   duration·z-index는 Tailwind 테마 네임스페이스가 없다 → duration-(--dur-fast) · z-(--z-modal) · ease-standard")
    w("   앱 셸 치수·터치 타깃도 변수로 바로 → w-(--sidebar-w) · h-(--topbar-h) · min-h-(--hit-min) */")
    w("@theme inline reference {")

    def block(title, reset, rows):
        w(f"  /* {title} */")
        for r in reset:
            w(f"  --{r}-*: initial;")
        for k, v in rows:
            w(f"  --{k}: {v};")
        w("")

    colors = [n for n, (g, _) in index.items() if g == "color"]
    block("색 — 무채색·브랜드·상태·시장 방향·차트·지도", ["color"], [(f"color-{n}", f"var(--{n})") for n in colors])
    sp = [n for n, (g, _) in index.items() if g == "spacing"]
    block("간격 — 배수(--spacing)를 끄고 토큰 단계만", ["spacing"],
          [("spacing", "initial")] + [(f"spacing-{n[3:]}", f"var(--{n})") for n in sp])
    rows = []
    for n, (g, k) in index.items():
        if g == "fontSize":
            rows.append((f"text-{k}", f"var(--{n})"))
            if f"lh-{k}" in light:
                rows.append((f"text-{k}--line-height", f"var(--lh-{k})"))
    block("글자 크기 + 행간 (모바일 축소는 tokens.css @media가 한다)", ["text"], rows)
    block("글꼴", ["font"], [(f"font-{k}", f"var(--{n})") for n, (g, k) in index.items() if g == "fontFamily"])
    block("굵기 — Design.md §3 (400 / 500 라벨 / 600 / 650 / 700)", ["font-weight"],
          [(f"font-weight-{k}", str(v)) for k, v in FONT_WEIGHTS.items()])
    block("자간", ["tracking"], [(f"tracking-{k}", f"var(--{n})") for n, (g, k) in index.items() if g == "letterSpacing"])
    block("행간 단독 클래스는 쓰지 않는다(text-* 짝 행간 사용)", ["leading"], [])
    block("반경", ["radius"], [(f"radius-{k}", f"var(--{n})") for n, (g, k) in index.items() if g == "radius"])
    block("그림자 — 떠 있는 레이어만", ["shadow", "inset-shadow", "drop-shadow", "text-shadow"],
          [(f"shadow-{k}", f"var(--{n})") for n, (g, k) in index.items() if g == "shadow"])
    block("움직임", ["ease"], [(f"ease-{k}", f"var(--{n})") for n, (g, k) in index.items() if g == "easing"])
    block("흐림 — 글래스모피즘 금지(Design.md §8)", ["blur"], [])
    block("레이아웃 — 컨테이너 최대 폭 (max-w-page)", ["container"], [("container-page", "var(--container)")])
    block("브레이크포인트 — Design.md §4 (미디어 쿼리라 var()를 못 쓴다)", ["breakpoint"],
          [(f"breakpoint-{k}", v) for k, v in BREAKPOINTS.items()])
    L[-1] = "}"  # 마지막 빈 줄 자리에 닫는 괄호
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- DESIGN.md
def _q(s):
    return json.dumps(s, ensure_ascii=False)


def build_design_md(merged, index, theme):
    light = tc.mode_values(merged, "light")
    dark = tc.mode_values(merged, "dark")
    hx = lambda vals, n: tc.hex_of(vals, n)
    # DESIGN.md 색은 6자리 hex만 → 알파가 있는 색(--backdrop 등)은 뺀다
    colors = [n for n, (g, _) in index.items() if g == "color" and tc.resolve_color(light, n)[3] == 1]
    fam = [f.strip().strip('"\'') for f in _split_top(light["font-sans"])]
    title = "design-harness" + (f" · {theme}" if theme else "")
    Y = ["---", "version: alpha", f"name: {_q(title)}",
         "description: " + _q("한국어 데이터 화면용 개인 디자인 시스템. 무채색 바탕 + 브랜드색 하나, 검증된 차트 팔레트, 한국식 시장 방향색."),
         "colors:", f"  primary: {_q(hx(light, 'accent'))}", f"  on-primary: {_q(hx(light, 'on-accent'))}"]
    for n in colors:
        Y.append(f"  {n}: {_q(hx(light, n))}")
    for n in colors:
        if n.startswith("map-"):
            continue  # 지도 위 색은 테마와 무관하게 라이트 값
        if hx(dark, n) != hx(light, n):
            Y.append(f"  dark-{n}: {_q(hx(dark, n))}")
    Y.append("typography:")
    lh = lambda k: light[f"lh-{k}"]
    for role, weight, heading in TYPE_ROLES:
        if f"fs-{role}" not in light:
            continue
        Y += [f"  {role}:", f"    fontFamily: {_q(fam[0])}", f"    fontSize: {light['fs-' + role]}",
              f"    fontWeight: {FONT_WEIGHTS[weight]}", f"    lineHeight: {lh(role)}"]
        if heading:
            Y.append(f"    letterSpacing: {light['tracking-tight']}")
    for n, (g, k) in index.items():
        if g == "fontSize" and k.startswith("d-"):
            Y += [f"  dense-{k[2:]}:", f"    fontFamily: {_q(fam[0])}", f"    fontSize: {light[n]}",
                  f"    fontWeight: 400", f"    lineHeight: {lh(k)}"]
    if "font-mono" in light:
        mono = [f.strip().strip('"\'') for f in _split_top(light["font-mono"])]
        Y += ["  numeric:", f"    fontFamily: {_q(mono[1] if mono[0] == 'ui-monospace' and len(mono) > 1 else mono[0])}",
              f"    fontSize: {light['fs-sm']}", "    fontWeight: 400", f"    lineHeight: {lh('sm')}",
              "    fontFeature: \"'tnum' 1\""]
    Y.append("rounded:")
    for n, (g, k) in index.items():
        if g == "radius":
            Y.append(f"  {k}: {light[n]}")
    Y.append("spacing:")
    for n, (g, k) in index.items():
        if g == "spacing":
            Y.append(f"  {_q(k)}: {light[n]}")
    Y += [f"  container: {light['container']}", f"  gutter: {light['gutter']}",
          f"  gutter-mobile: {merged['mobile'].get('gutter', light['gutter'])}"]
    comps = {
        "page": {"backgroundColor": "bg", "textColor": "text"},
        "page-dark": {"backgroundColor": "dark-bg", "textColor": "dark-text"},
        "button-primary": {"backgroundColor": "accent", "textColor": "on-accent", "rounded": "md", "height": "40px",
                           "padding": light["sp-4"], "typography": "sm"},
        "button-primary-hover": {"backgroundColor": "accent-hover", "textColor": "on-accent"},
        "button-primary-dark": {"backgroundColor": "dark-accent", "textColor": "dark-on-accent"},
        "button-secondary": {"backgroundColor": "surface", "textColor": "text", "rounded": "md", "height": "40px",
                             "padding": light["sp-4"]},
        "button-danger": {"backgroundColor": "surface", "textColor": "negative", "rounded": "md", "height": "40px"},
        "input": {"backgroundColor": "surface", "textColor": "text", "rounded": "md", "height": "40px",
                  "padding": light["sp-3"], "typography": "sm"},
        "badge": {"backgroundColor": "surface-2", "textColor": "text-2", "rounded": "sm", "height": "22px",
                  "padding": light["sp-2"], "typography": "xs"},
        "badge-accent": {"backgroundColor": "accent-soft", "textColor": "accent", "rounded": "sm"},
        "panel": {"backgroundColor": "surface", "textColor": "text", "rounded": "lg", "padding": light["sp-6"]},
        "table-row": {"textColor": "text", "height": "44px", "typography": "sm"},
        "table-row-selected": {"backgroundColor": "accent-soft", "textColor": "text"},
        "segment-active": {"backgroundColor": "accent-soft", "textColor": "text", "rounded": "md"},
        "notice-warning": {"backgroundColor": "warning-soft", "textColor": "text-2", "rounded": "lg"},
        "toast": {"backgroundColor": "surface", "textColor": "text", "rounded": "lg"},
        "stat-value": {"textColor": "text", "typography": "h2"},
        "stat-up": {"textColor": "up"},
        "stat-down": {"textColor": "down"},
        "meta": {"textColor": "text-3", "typography": "xs"},
    }
    Y.append("components:")
    defined = set(colors) | {"dark-" + n for n in colors if hx(dark, n) != hx(light, n)}
    for cname, props in comps.items():
        Y.append(f"  {cname}:")
        for k, v in props.items():
            if k in ("backgroundColor", "textColor"):
                if v not in defined:
                    continue
                v = "{colors." + v + "}"
            elif k == "rounded":
                v = "{rounded." + v + "}"
            elif k == "typography":
                v = "{typography." + v + "}"
            Y.append(f"    {k}: {_q(v)}")
    Y.append("---")

    a, ad = hx(light, "accent"), hx(dark, "accent")
    s1 = hx(light, "series-1")
    body = f"""
<!-- 휴대용 사본: Stitch 등 다른 AI 디자인 도구에 넘길 때 쓴다. 원본은 design-harness의 Design.md · vault/tokens.css.
     scripts/tokens/build.py{' --theme ' + theme if theme else ''}로 생성 — 직접 고치지 말고 원본을 고친 뒤 다시 만든다. -->

## Overview

한국어 데이터 화면(대시보드, 지도 서비스, 리포트, 도구)을 위한 차분한 시스템이다. 화면의 주인공은 데이터와 문장이고 장식은 뒤로 물러난다.
바탕은 무채색, 브랜드색은 {a}(다크 {ad}) 하나다. 위계는 박스·그림자보다 글자 크기·굵기·여백으로 만든다.
한글 기준으로 조판한다: 본문 행간 1.65, 한글 본문에 음수 자간 금지, `word-break: keep-all`, 본문 한 줄 최대 68ch.
라이트와 다크는 항상 짝으로 있다. front matter의 `dark-*` 색이 다크 값이다.

## Colors

- **바탕·면·선·글자:** bg {hx(light, 'bg')} → surface {hx(light, 'surface')} → surface-2 {hx(light, 'surface-2')}(눌린 면·hover), border {hx(light, 'border')} / border-strong {hx(light, 'border-strong')}, 글자 text {hx(light, 'text')} · text-2 {hx(light, 'text-2')} · text-3 {hx(light, 'text-3')}(메타, 12px 이하 본문 금지).
- **브랜드(primary = accent {a}):** "여기를 누르세요 / 지금 이 상태입니다"에만 쓴다. 한 화면에 accent가 3곳을 넘으면 줄인다. 선택된 행·활성 토글은 accent-soft {hx(light, 'accent-soft')} 바탕 + 본문색 글자.
- **상태색** positive {hx(light, 'positive')} · negative {hx(light, 'negative')} · warning {hx(light, 'warning')}: 글자·아이콘·얇은 선에만. 안내 상자 바탕은 상태색 10%를 표면에 섞은 *-soft.
- **시장 방향은 한국식:** 상승 up {hx(light, 'up')}(빨강) + ▲, 하락 down {hx(light, 'down')}(파랑) + ▼, 보합 text-2. 가격·지수·수익률·환율, 매출·점포 수 증감률에 쓴다. 그 밖의 지표는 색 = 좋고 나쁨(positive/negative), 화살표 = 방향.
- **차트 범주 8색**은 series-1({s1})부터 순서대로, 순환 금지. 산점도·지도·작은 차트 여러 개는 3계열까지. 순차 램프 seq-1(작음)~seq-9(큼)는 브랜드 색상 하나, 발산 램프는 파랑 ↔ 회색 ↔ 버건디.
- 지도 타일 위 색(map-*)은 다크에서도 라이트 값을 쓴다.

## Typography

Pretendard Variable 한 가족. 숫자가 정렬돼야 하는 곳은 tabular-nums(`numeric`).
기본 단계(글 중심): display 44 · h1 32 · h2 24 · h3 19 · body 16 · sm 14 · xs 12. 굵기는 400 / 500(라벨·배지 전용) / 600 / 650 / 700만.
제목 자간 -0.02em. 640px 이하에서 display 32, h1 26, h2 21.
조밀 단계(`dense-*`, 패널·차트가 빽빽한 대시보드): 10/16 · 12/16 · 14/20 · 16/24 · 20/30 · 24/32 · 32/42.

## Layout

4px 기반 간격(spacing 1–20 = 4–80px)만 쓴다. 관련된 것은 8–12px로 가깝게, 다른 그룹은 32px 이상 멀게 — 중간값으로 뭉개지 않는다.
컨테이너 최대 1120px, 좌우 여백 데스크톱 24px / 모바일 16px. 브레이크포인트 640px, 1024px. 가로 스크롤은 표 내부에서만.
고정 N칸 그리드(지표 줄)는 640px 이하에서 2칸으로 접는다. 터치 타깃 40px 이상.

## Elevation & Depth

평면이 기본이다. 페이지에 붙은 패널은 1px border만, 그림자는 메뉴·모달·토스트처럼 떠 있는 레이어에만(shadow-pop).
패널 안에 패널을 넣지 않는다. 글래스모피즘·네온 글로우·과한 blur는 쓰지 않는다.

## Shapes

radius sm 6px(배지·체크박스) · md 8px(버튼·입력창) · lg 12px(패널·모달) · full(칩·아바타). 화면마다 radius를 바꾸지 않는다.
아이콘은 1.5px 선 아이콘(Lucide 스타일) 16/20px. 이모지를 아이콘으로 쓰지 않는다.

## Components

- **Button:** 높이 40(기본)/32(sm). primary(accent 채움, 화면당 1개) · secondary(surface + border-strong) · ghost · danger(negative 글자). 아이콘 버튼은 aria-label.
- **Input/Select:** 높이 40, 라벨은 위(xs, text-2), 에러는 아래(negative, xs). placeholder를 라벨 대신 쓰지 않는다.
- **Badge:** xs, 높이 22, surface-2 바탕, 줄바꿈 금지. 상태 배지는 점 + 글자.
- **Table:** 행 44, 헤더 xs text-2, 숫자 열 우측 정렬 + tabular-nums, 가로선만.
- **Tabs:** 밑줄형, 선택 탭은 text + 2px accent 밑줄.
- **Stat:** 라벨(xs, text-2) → 값(h2, tabular-nums) → 변화량(▲▼ + 부호 + 색).
- **Empty state:** 한 줄 설명 + 다음 행동 버튼 1개, 일러스트 없음. **Toast:** 하단 중앙, 4초, 닫기 버튼.
- 포커스 링 2px focus + 2px offset. hover / active / disabled / selected가 서로 구분돼야 한다.

## Do's and Don'ts

- Do: 실제 한국어 문구와 현실적인 숫자(단위·자릿수 맞게). 천 단위 쉼표, 큰 금액은 만 단위(`1억 2,346만원`), 음수는 −(U+2212), 데이터 없음은 –.
- Do: 문구는 해요체, 버튼은 일어날 일(`저장`, `다시 시도`), 에러는 무엇이 + 다음 행동.
- Do: 차트는 y축 하나, 범례 필수(2계열 이상), 글자는 데이터 색을 입지 않는다. 같은 값을 표로도 볼 수 있게.
- Don't: 보라·핑크 그라디언트, 그라디언트 글자, 모든 요소를 카드 + 그림자로 감싸기, 카드 안의 카드.
- Don't: 이모지 아이콘, 장식 일러스트, "Unlock your potential" 류 문구, Lorem ipsum, 근거 없는 지표(+312%, 10x).
- Don't: 가운데 정렬된 긴 본문, 회색 위의 회색 글자, 모든 섹션에 같은 3열 그리드.
- Don't: 값과 무관하게 늘 같은 색(항상 음수인 MDD에 고정 빨강). 색은 조건부일 때만.
"""
    return "\n".join(Y) + "\n" + body


# ---------------------------------------------------------------- main
def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"  {path.relative_to(tc.ROOT)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--theme", help="vault/themes/<이름>/theme.css를 얹어 vault/export/<이름>/에 생성")
    args = ap.parse_args()
    base = tc.parse(tc.TOKENS)
    if tc.dark_mismatch(base):
        print(f"경고: tokens.css 다크 블록 두 벌이 다름: {', '.join(tc.dark_mismatch(base))}", file=sys.stderr)
    theme = None
    out = tc.EXPORT
    if args.theme:
        tpath = tc.THEMES / args.theme / "theme.css"
        if not tpath.is_file():
            sys.exit(f"테마 파일 없음: {tpath}")
        theme = tc.parse(tpath)
        bad = sorted(set(theme["light"]) - tc.ALLOWED) + sorted(set(theme["dark"]) - tc.ALLOWED)
        if bad:
            sys.exit("테마가 바꿀 수 없는 토큰: " + ", ".join(f"--{n}({tc.locked_reason(n)})" for n in bad))
        out = tc.EXPORT / args.theme
    merged = tc.merge(base, theme)
    dtcg, dark, skipped, index = build_dtcg(merged)
    if skipped:
        print(f"경고: 분류 못 한 토큰(내보내기에서 빠짐): {', '.join('--' + s for s in skipped)}", file=sys.stderr)
    dump = lambda o: json.dumps(o, ensure_ascii=False, indent=2) + "\n"
    print(f"생성 ({len(index)}개 토큰{', 테마 ' + args.theme if theme else ''}):")
    write(out / "tokens.dtcg.json", dump(dtcg))
    write(out / "tokens.dark.dtcg.json", dump(dark))
    write(out / "tokens.resolver.json", dump(RESOLVER))
    write(out / "tailwind-theme.css", build_tailwind(merged, index, args.theme))
    write(out / "DESIGN.md", build_design_md(merged, index, args.theme))


if __name__ == "__main__":
    main()
