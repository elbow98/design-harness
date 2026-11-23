#!/usr/bin/env bash
# AI 티(slop) 결정론 탐지: Impeccable(github.com/pbakaus/impeccable, Apache-2.0) detect 래퍼
# + Impeccable이 못 잡는 Design.md §8 항목을 하네스 보조 검사로 더한다.
# 사용: scripts/slop.sh [--no-advisory] [경로...]   (기본: outputs/ 전체) — 파일 또는 폴더
#
# - .html은 file:// URL로 넘겨 브라우저 렌더 모드로 검사한다(정적 모드보다 bounce-easing·em-dash 등을 더 잡는다).
#   .css/.tsx/.ts/.jsx/.vue/.svelte는 정적(정규식) 모드.
# - 끈 규칙과 이유: 저장소 루트 `.impeccable/config.json`의 `_why`. 하네스 루트에서 실행해 그 설정을 쓴다.
# - 보조 검사(harness/*): 보라·핑크 그라디언트 · 이모지 아이콘 · 글래스모피즘(backdrop-filter blur) · .panel 안 .panel ·
#   Lorem ipsum·빈 마케팅 문구.
# - 한 줄 예외: 그 줄에 `harness-ignore` 또는 Impeccable 문법 `impeccable-disable-line <규칙>`.
# - Impeccable 오탐 보정 2개(아래 not_gray·visible_occlusions): 거의 흰색·검정 글자의 gray-on-color,
#   화면에 렌더되지 않은 요소(닫힌 <details> 안 표 등)의 text-occlusion. 회귀 견본은 scripts/tests/slop/.
# - findings(advisory 제외)가 있으면 exit 1. advisory는 경고로만 출력. Impeccable 실행이 안 되면 보조 검사만 돌리고 알린다.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMPECCABLE_VERSION="4.1.0"   # 2026-09-08 릴리스. 올릴 때는 outputs·vault에 다시 돌려 오탐을 확인한다
python3 - "$ROOT" "$IMPECCABLE_VERSION" "$@" <<'PY'
import sys, os, re, json, subprocess, pathlib, urllib.parse

root, ver, argv = sys.argv[1], sys.argv[2], sys.argv[3:]
show_adv = "--no-advisory" not in argv
targets = [a for a in argv if not a.startswith("--")] or [os.path.join(root, "outputs")]

HTML_EXT = (".html", ".htm")
SRC_EXT = (".css", ".tsx", ".ts", ".jsx", ".vue", ".svelte")
SKIP_DIRS = {"node_modules", ".next", ".git", "dist", "build", "out", "coverage", "__tests__", "vendor"}
files = []
for t in targets:
    t = os.path.abspath(t)
    if os.path.isfile(t):
        files.append(t)
    elif os.path.isdir(t):
        for d, ds, fs in os.walk(t):
            ds[:] = [x for x in ds if x not in SKIP_DIRS]
            files += [os.path.join(d, f) for f in fs if f.endswith(HTML_EXT + SRC_EXT) and not f.endswith(".d.ts")]
    else:
        print(f"없는 경로: {t}"); sys.exit(2)
files = sorted(set(f for f in files if f.endswith(HTML_EXT + SRC_EXT)))

KO = {  # Impeccable 규칙 → 한국어 한 줄
    "ai-color-palette": "보라 계열/어두운 바탕 형광 시안 — AI 기본 팔레트 (설정에서 꺼 둠)",
    "gradient-text": "그라디언트 글자(background-clip:text) (Design.md §8)",
    "nested-cards": "카드 안의 카드 (Design.md §8)",
    "glassmorphism": "글래스모피즘 (Design.md §8)",
    "bounce-easing": "튕기는(bounce·elastic) easing — 전환은 --ease 하나 (Design.md §5)",
    "dark-glow": "네온 글로우 (Design.md §8)",
    "radial-halo": "장식용 방사형 후광",
    "radial-spotlight-glow": "장식용 스포트라이트 글로우",
    "gpt-thin-border-wide-shadow": "1px 테두리 + 넓은 그림자 동시 사용 — 붙은 카드는 테두리만 (Design.md §5)",
    "identical-card-grids": "같은 모양 카드 그리드 반복 (Design.md §8 3열 feature 그리드)",
    "icon-tile-stack": "아이콘 타일 + 제목 + 설명 반복 블록",
    "hero-metric-layout": "근거 없는 큰 숫자 지표 히어로 (Design.md §8 가짜 지표)",
    "hero-eyebrow-chip": "헤드라인 위 알약형 칩",
    "kicker-above-heading": "제목 위 작은 키커 라벨",
    "numbered-section-labels": "번호 붙은 섹션 라벨",
    "marketing-buzzword": "빈 마케팅 문구 (Design.md §8)",
    "theater-slop-phrase": "연출용 상투 문구",
    "em-dash-overuse": "대시(—) 남발",
    "side-tab": "카드 한쪽 두꺼운 색 띠",
    "border-accent-on-rounded": "둥근 카드 한쪽에만 색 테두리",
    "cream-palette": "크림·베이지 바탕 (하네스 --bg는 무채색)",
    "monotonous-spacing": "간격이 전부 같음 — 관련은 가깝게, 그룹은 멀게 (Design.md §4)",
    "tight-leading": "본문 행간이 좁음 (Design.md §3 본문 1.65)",
    "wide-tracking": "본문 자간을 벌림 (Design.md §3 본문 0)",
    "extreme-negative-tracking": "과한 음수 자간 (제목 -0.02em까지)",
    "all-caps-body": "본문 전체 대문자",
    "justified-text": "양쪽 정렬 본문",
    "line-length": "본문 한 줄이 너무 김 (Design.md §3 최대 68ch)",
    "tiny-text": "본문 글자가 너무 작음",
    "undersized-ui-text": "조작 요소 글자가 너무 작음",
    "skipped-heading": "제목 단계를 건너뜀 (h1→h3)",
    "heading-rhythm": "제목이 아래 내용보다 위 블록에 더 붙음",
    "cramped-padding": "버튼·카드 안쪽 여백이 좁음",
    "over-round": "과한 radius (Design.md §5)",
    "oversized-h1": "h1이 지나치게 큼",
    "gray-on-color": "색 바탕 위 회색 글자",
    "text-overflow": "글자가 상자를 넘침",
    "text-occlusion": "글자가 다른 요소에 가려짐",
    "broken-image": "깨진 이미지",
    "script-error": "스크립트 에러",
    "marquee": "흐르는 글자(marquee)",
    "pulsing-dot": "깜빡이는 점 장식",
    "blinking-cursor": "깜빡이는 커서 장식",
    "layout-transition": "레이아웃 속성(width·top 등)에 전환",
    "image-hover-transform": "이미지 hover 확대",
    "codex-grid-background": "장식용 격자 배경",
    "repeating-stripes-gradient": "장식용 줄무늬 그라디언트",
    "organic-clip-path": "장식용 유기적 clip-path",
    "sketchy-svg": "손그림 풍 SVG 장식",
    "shape-assembled-illustration": "도형을 조립한 장식 일러스트 (Design.md §8)",
    "italic-serif-display": "이탤릭 세리프 헤드라인",
    "aphoristic-cadence": "격언식 짧은 문장 리듬",
    "design-system-color": "DESIGN.md 팔레트 밖 색",
    "design-system-font": "DESIGN.md 밖 폰트",
    "design-system-font-size": "DESIGN.md 타입 스케일 밖 크기",
    "design-system-radius": "DESIGN.md radius 밖 값",
}
# Impeccable은 HTML의 줄 번호를 0으로 준다 → 규칙별 힌트로 첫 줄을 찾아 붙인다(없으면 '?')
HINT = {
    "gradient-text": r"background-clip\s*:\s*text", "ai-color-palette": r"gradient\(",
    "bounce-easing": r"cubic-bezier\([^)]*-|bounce|elastic", "gpt-thin-border-wide-shadow": r"box-shadow|shadow-pop",
    "nested-cards": r"class=\"[^\"]*(card|panel)", "glassmorphism": r"backdrop-filter", "em-dash-overuse": r"—",
    "tight-leading": r"line-height", "layout-transition": r"transition\s*:\s*(width|height|top|left|right|bottom|margin|padding)", "wide-tracking": r"letter-spacing", "over-round": r"border-radius",
}

def line_of(path, rule, line):
    if line: return line
    rx = HINT.get(rule)
    if not rx: return "?"
    try:
        for i, l in enumerate(open(path, encoding="utf-8", errors="ignore"), 1):
            if re.search(rx, l, re.I): return i
    except OSError: pass
    return "?"

def ignored(path, line):
    if not isinstance(line, int): return False
    try: l = open(path, encoding="utf-8", errors="ignore").read().split("\n")[line - 1]
    except (OSError, IndexError): return False
    return "harness-ignore" in l

primary, advisory = [], []   # (경로, 줄, 규칙, 설명, 근거)
occl = []                    # text-occlusion 후보: 실제로 보이는 요소인지 렌더로 확인한 뒤 primary로
imp_ok = True

# 오탐 보정 1) gray-on-color: Impeccable 4.1.0은 채도 낮은 글자를 모두 '회색'으로 본다. 그런데 이 규칙의
# 권고 자체가 "흰색·거의 흰색 글자를 쓰라"이고, 하네스 다크 --text #EDEDEA on --accent-soft(Design.md §6
# 선택 상태)가 여기에 걸렸다. 거의 흰색·거의 검정(OKLab L ≥ 0.9 또는 ≤ 0.25) 글자는 회색이 아니므로 뺀다.
# 중간 밝기 회색(--text-2·--text-3 등, L 0.5~0.75)은 그대로 잡는다.
sys.dont_write_bytecode = True  # scripts/tokens/에 __pycache__를 남기지 않는다(build.py와 같음)
sys.path.insert(0, os.path.join(root, "scripts", "tokens"))
from colorlib import parse_color, srgb_to_oklab
GRAY_RX = re.compile(r"text\s+(#[0-9a-fA-F]{3,8}|rgba?\([^)]*\))\s+on\s+bg")

def not_gray(snippet):
    m = GRAY_RX.search(snippet)
    c = parse_color(m.group(1)) if m else None
    if not c: return False  # 못 읽으면 보고를 유지한다
    L = srgb_to_oklab(c)[0]
    return L >= 0.9 or L <= 0.25

# 오탐 보정 2) text-occlusion: 닫힌 <details> 안의 표처럼 렌더되지 않은 요소도 Chromium이 상자를 주면
# Impeccable이 '가려진 글자'로 본다. 보고된 요소(태그 + 글자 앞부분)를 같은 뷰포트(1280×800)로 열어
# 화면에 보이는 것이 하나라도 있으면 유지, 일치하는 요소가 모두 보이지 않을 때만 뺀다.
# 일치하는 요소를 못 찾거나 Playwright를 못 쓰면 보고를 유지한다(실제 문제를 놓치지 않는 쪽).
OCCL_RX = re.compile(r'^([a-zA-Z][\w-]*)\s+"(.*?)"\s+is\s+\d+%\s+covered')

def visible_occlusions(cands):
    by_file = {}
    for row, snip in cands:
        by_file.setdefault(row[0], []).append((row, snip))
    keep = []
    try:
        from playwright.sync_api import sync_playwright
    except Exception:
        return [r for r, _ in cands]
    try:
        return _visible(by_file, sync_playwright)
    except Exception:
        return [r for r, _ in cands]

def _visible(by_file, sync_playwright):
    keep = []
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        for path, items in by_file.items():
            pg = b.new_page(viewport={"width": 1280, "height": 800})
            try:
                pg.goto(pathlib.Path(path).as_uri(), wait_until="networkidle")
            except Exception:
                keep += [r for r, _ in items]; pg.close(); continue
            for row, snip in items:
                m = OCCL_RX.match(snip)
                if not m:
                    keep.append(row); continue
                seen = pg.evaluate("""([tag, txt]) => {
                  const els = [...document.querySelectorAll(tag)].filter(e => e.textContent.trim().replace(/\\s+/g, ' ').startsWith(txt));
                  if (!els.length) return null;
                  return els.some(e => e.checkVisibility({contentVisibilityAuto: true, visibilityProperty: true, opacityProperty: true}));
                }""", [m.group(1).lower(), m.group(2).strip()])
                if seen is not False: keep.append(row)
            pg.close()
        b.close()
    return keep

# 1) Impeccable
args = [pathlib.Path(f).as_uri() if f.endswith(HTML_EXT) else f for f in files]
if args:
    try:
        r = subprocess.run(["npx", "--yes", f"impeccable@{ver}", "detect", "--json", *args],
                           cwd=root, capture_output=True, text=True, timeout=600)
        data = json.loads(r.stdout or "null")
        if not isinstance(data, list): raise ValueError(r.stderr.strip()[-300:] or "JSON 없음")
        for x in data:
            p = x.get("file") or ""
            if p.startswith("file://"): p = pathlib.Path(urllib.parse.unquote(p[7:])).as_posix()  # 한글 경로는 %인코딩돼 온다
            rule = x.get("antipattern", "?")
            ln = line_of(p, rule, x.get("line") or 0)
            if ignored(p, ln): continue
            snip = x.get("snippet") or ""
            if rule == "gray-on-color" and not_gray(snip): continue
            row = (p, ln, rule, KO.get(rule, x.get("name", rule)), snip[:80])
            if rule == "text-occlusion" and p.endswith(HTML_EXT) and not x.get("advisory"):
                occl.append((row, snip)); continue
            (advisory if x.get("advisory") else primary).append(row)
        if r.returncode == 1:
            print(f"⚠ Impeccable: 일부 대상을 검사하지 못함 — {r.stderr.strip()[-200:]}")
        if occl:
            primary += visible_occlusions(occl)
    except Exception as e:
        imp_ok = False
        print(f"⚠ Impeccable {ver} 실행 실패({str(e)[:160]}) — 하네스 보조 검사만 돌린다")

# 2) 하네스 보조 검사 (Design.md §8 중 Impeccable이 놓치는 것)
EMOJI = re.compile("[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F000-\U0001F2FF⭐⭕⌚⌛⏩-⏺]️?")
BLUR = re.compile(r"backdrop-filter\s*:\s*[^;\"}]*blur\(\s*[1-9]")
LOREM = re.compile(r"lorem ipsum|unlock your (full )?potential|supercharge your|take .{0,20} to the next level|seamless(ly)? integrat", re.I)
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}

GRAD = re.compile(r"(?:linear|radial|conic)-gradient\((?:[^()]|\([^()]*\))*\)", re.I)
TW_GRAD = re.compile(r"\b(?:from|via|to)-(?:purple|violet|fuchsia|pink)-\d{2,3}\b")
COLOR = re.compile(r"#([0-9a-f]{6}|[0-9a-f]{3})\b|rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)", re.I)

def purple_pink(chunk):
    import colorsys
    for m in COLOR.finditer(chunk):
        if m.group(1):
            h = m.group(1); h = "".join(c * 2 for c in h) if len(h) == 3 else h
            r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
        else:
            r, g, b = (int(m.group(i)) for i in (2, 3, 4))
        hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if 255 <= hue * 360 <= 345 and sat >= .35 and .2 <= light <= .85:
            return m.group(0)
    return None

def blank(m):  # 같은 길이로 지워 줄 번호 유지
    return re.sub(r"[^\n]", " ", m.group(0))

def add(path, text, pos, rule, desc, ev):
    ln = text.count("\n", 0, pos) + 1
    if not ignored(path, ln):
        primary.append((path, ln, f"harness/{rule}", desc, ev.strip()[:60]))

for f in files:
    try: text = open(f, encoding="utf-8", errors="ignore").read()
    except OSError: continue
    for m in GRAD.finditer(text):
        c = purple_pink(m.group(0))
        if c: add(f, text, m.start(), "purple-gradient", f"보라·핑크 그라디언트 {c} (Design.md §8)", m.group(0))
    for m in TW_GRAD.finditer(text):
        add(f, text, m.start(), "purple-gradient", "보라·핑크 그라디언트 Tailwind 클래스 (Design.md §8)", m.group(0))
    for m in BLUR.finditer(text):
        add(f, text, m.start(), "glassmorphism", "backdrop-filter blur — 글래스모피즘 (Design.md §8)", m.group(0))
    if f.endswith(HTML_EXT):
        body = re.sub(r"<(script|style)\b.*?</\1>|<!--.*?-->", blank, text, flags=re.S | re.I)
        visible = re.sub(r"<[^>]*>", blank, body)  # 태그 속성(aria-label 등) 제외, 보이는 글자만
        for m in EMOJI.finditer(visible):
            add(f, text, m.start(), "emoji-icon", "이모지 — 아이콘은 Lucide 1.5px 선 (Design.md §6·§8)", visible[max(0, m.start() - 15):m.end() + 15].replace("\n", " "))
        for m in LOREM.finditer(visible):
            add(f, text, m.start(), "filler-copy", "Lorem ipsum·빈 마케팅 문구 (Rules.md §5-3)", m.group(0))
        # .panel 안 .panel (Design.md §6: 패널 안에 패널을 넣지 않는다)
        stack = []
        for m in re.finditer(r"<(/?)([a-zA-Z][\w-]*)([^>]*?)(/?)>", body):
            close, tag, attrs, selfclose = m.group(1), m.group(2).lower(), m.group(3), m.group(4)
            if close:
                while stack:
                    t, _ = stack.pop()
                    if t == tag: break
                continue
            if tag in VOID or selfclose: continue
            cm = re.search(r"""class\s*=\s*["']([^"']*)["']""", attrs)
            is_panel = bool(cm and "panel" in cm.group(1).split())
            if is_panel and any(p for _, p in stack):
                add(f, text, m.start(), "panel-in-panel", ".panel 안의 .panel (Design.md §6)", m.group(0))
            stack.append((tag, is_panel))
    elif f.endswith((".tsx", ".jsx", ".ts")):
        code = re.sub(r"/\*.*?\*/|//[^\n]*", blank, text, flags=re.S)
        for m in EMOJI.finditer(code):
            add(f, text, m.start(), "emoji-icon", "이모지 — 아이콘은 Lucide 1.5px 선 (Design.md §6·§8)", code[max(0, m.start() - 15):m.end() + 15].replace("\n", " "))

def rel(p):
    r = os.path.relpath(p) if os.path.isabs(p) else p
    return p if r.startswith("../..") else r

dedup = lambda rows: list(dict.fromkeys(rows))  # 브라우저 모드는 같은 걸 여러 번 보고한다
primary, advisory = dedup(primary), dedup(advisory)

for title, rows in [("", primary), ("참고(advisory, 실패 아님)", advisory if show_adv else [])]:
    if not rows: continue
    if title: print(f"\n{title}")
    for p, ln, rule, desc, ev in sorted(rows, key=lambda r: (r[0], str(r[1]).zfill(6))):
        print(f"{rel(p)}:{ln} — {rule} — {desc}\n    {ev}")
src = f"Impeccable {ver} + 하네스 보조" if imp_ok else "하네스 보조만(Impeccable 실행 실패)"
adv = f" · 참고 {len(advisory)}건" if advisory else ""
print(f"\nslop {len(primary)}건{adv} · 파일 {len(files)}개 검사 · {src}" if primary else f"OK · slop 0건{adv} · 파일 {len(files)}개 검사 · {src}")
sys.exit(1 if primary else 0)
PY
