#!/usr/bin/env bash
# 토큰 드리프트 검사: 토큰 밖 값(하드코딩된 색·폰트·px 간격)을 찾는다.
# 사용: scripts/check.sh [--allow <경로|glob>]... [경로...]   (기본: outputs/ 전체)
#
# - .html/.css: <style>·style="" 안의 CSS와 .css 파일 전체를 본다. tokens.css 복사본은 제외.
#   토큰 선언(--이름: 값;)은 허용 — explore의 변형 전용 토큰용. 속성에 값을 직접 쓰는 것만 잡는다.
# - .tsx/.ts/.jsx(Next.js·React): 주석을 뺀 문자열 리터럴 안의 색(#hex·rgb(a)·hsl·oklch)·
#   인라인 CSS 문자열(cssText 등)의 폰트·px, style={{…}} 안의 간격·글자 크기 숫자,
#   Tailwind 임의값(text-[13px] · bg-[#abc]), Tailwind 기본 팔레트 클래스(bg-blue-600 · text-white), dark: 변형
# - 제외: node_modules · .next · .git · dist · build · out · coverage · __tests__ · *.test.* · *.spec.* · *.d.ts
# - 예외 파일: --allow web/lib/mapColors.ts (여러 번 가능) 또는 대상 경로·그 상위 폴더의
#   .harnesscheckignore (한 줄에 glob 하나, # 주석, 그 파일이 있는 폴더 기준 상대 경로).
#   한 줄만 예외로 두려면 그 줄에 `harness-ignore` 주석을 단다.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" "$@" <<'PY'
import sys, os, re, fnmatch

root, argv = sys.argv[1], sys.argv[2:]
allow, targets = [], []
i = 0
while i < len(argv):
    if argv[i] == "--allow" and i + 1 < len(argv):
        allow.append(os.path.abspath(argv[i + 1])); i += 2
    elif argv[i].startswith("--allow="):
        allow.append(os.path.abspath(argv[i].split("=", 1)[1])); i += 1
    else:
        targets.append(argv[i]); i += 1
if not targets:
    targets = [os.path.join(root, "outputs")]

WEB_EXT = (".html", ".css")
JS_EXT = (".tsx", ".ts", ".jsx")
SKIP_DIRS = {"node_modules", ".next", ".git", "dist", "build", "out", "coverage", "__tests__"}
TEST_RX = re.compile(r"\.(test|spec)\.[jt]sx?$|\.d\.ts$")

# .harnesscheckignore: 대상 경로와 그 상위 폴더에서 찾는다
ignores = []  # (기준 폴더, glob)
seen = set()
for t in targets:
    d = os.path.abspath(t if os.path.isdir(t) else os.path.dirname(t) or ".")
    while True:
        f = os.path.join(d, ".harnesscheckignore")
        if f not in seen and os.path.isfile(f):
            seen.add(f)
            for ln in open(f, encoding="utf-8"):
                ln = ln.split("#", 1)[0].strip()
                if ln:
                    ignores.append((d, ln))
        if os.path.dirname(d) == d:
            break
        d = os.path.dirname(d)

def allowed(path):
    ap = os.path.abspath(path)
    for a in allow:
        if ap == a or ap.startswith(a.rstrip("/") + "/") or fnmatch.fnmatch(ap, a):
            return True
    for base, pat in ignores:
        rel = os.path.relpath(ap, base)
        if fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(rel, pat.rstrip("/") + "/*") or fnmatch.fnmatch(os.path.basename(ap), pat):
            return True
    return False

files, skipped = [], 0
for a in targets:
    if os.path.isdir(a):
        for dp, dns, fs in os.walk(a):
            dns[:] = [d for d in dns if d not in SKIP_DIRS]
            for f in fs:
                p = os.path.join(dp, f)
                if f == "tokens.css" or TEST_RX.search(f) or not f.endswith(WEB_EXT + JS_EXT):
                    continue
                if allowed(p):
                    skipped += 1
                    continue
                files.append(p)
    elif allowed(a):
        skipped += 1
    else:
        files.append(a)

COLOR = re.compile(r"#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b|\b(?:rgb|rgba|hsl|hsla|oklch)\(")
FONT = re.compile(r"font-family\s*:(?!\s*(?:var\(|inherit))")
PX = re.compile(r"(?<![\w-])(?:margin|padding|gap|row-gap|column-gap|font-size|border-radius|top|bottom|left|right)\s*:[^;\"'`}]*?\b(?!0px)\d+px")
css_rules = [("색 하드코딩", COLOR), ("폰트 하드코딩", FONT), ("px 하드코딩", PX)]

# Tailwind: 간격·타입·radius·위치 접두사의 임의 수치, 임의 색, 기본 팔레트
TW_ARB = re.compile(r"(?<![\w-])-?(?:[\w-]+:)*(?:text|leading|tracking|p[xytrblse]?|m[xytrblse]?|gap(?:-[xy])?|space-[xy]|rounded(?:-[a-z]{1,2})?|top|left|right|bottom|inset(?:-[xy])?)-\[-?\d[^\]\s]*\]")
TW_ARB_COLOR = re.compile(r"(?<![\w-])(?:[\w-]+:)*[\w-]+-\[(?:#|rgba?\(|hsla?\(|oklch\()[^\]\s]*\]")
PALETTE = "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose"
UTIL = "bg|text|border(?:-[xytrblse])?|ring|ring-offset|fill|stroke|from|via|to|outline|divide|placeholder|decoration|accent|caret|shadow"
TW_PAL = re.compile(rf"(?<![\w\[-])(?:[\w-]+:)*(?:{UTIL})-(?:(?:{PALETTE})-\d{{2,3}}|black|white)(?:/\d+)?(?![\w-])")
TW_DARK = re.compile(r"(?<![\w-])dark:[a-z]")
STR_COLOR = re.compile(r"(?<!-\[)" + COLOR.pattern)  # Tailwind 임의 색은 아래 규칙이 따로 잡는다
str_rules = [("색 하드코딩", STR_COLOR), ("폰트 하드코딩", FONT), ("px 하드코딩", PX), ("Tailwind 임의값", TW_ARB), ("Tailwind 임의 색", TW_ARB_COLOR), ("Tailwind 기본 팔레트", TW_PAL), ("Tailwind dark: 변형(토큰이 다크 값을 가진다)", TW_DARK)]

STYLE_NUM = re.compile(r"\b(?:margin|padding|gap|rowGap|columnGap|fontSize|borderRadius|top|bottom|left|right|inset)\w*\s*:\s*[\"'`]?\s*-?(?!0\b)\d+(?:\.\d+)?(?:px)?\b(?![%.\w])")

def scan_js(text):
    """주석은 공백으로 지우고(줄 번호 유지), 문자열 리터럴 구간 목록을 돌려준다."""
    out, strings = list(text), []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            if "harness-ignore" in text[i:j]:
                ls = text.rfind("\n", 0, i) + 1
                for k in range(ls, j): out[k] = " "
            for k in range(i, j): out[k] = " "
            i = j
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n": out[k] = " "
            i = j
        elif c in "\"'`":
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == "\\": j += 1
                elif c != "`" and text[j] == "\n": break
                j += 1
            strings.append((i + 1, j))
            i = j + 1
        else:
            i += 1
    return "".join(out), strings

def style_blocks(code):
    for m in re.finditer(r"style=\{\{", code):
        depth, j = 2, m.end()
        while j < len(code) and depth:
            depth += {"{": 1, "}": -1}.get(code[j], 0); j += 1
        yield m.start(), j

bad = 0
def report(f, text, pos, name, snippet):
    global bad
    line = text.count("\n", 0, pos) + 1
    print(f"{os.path.relpath(f)}:{line}  [{name}]  {snippet.splitlines()[0] if snippet else ''}")
    bad += 1

for f in files:
    try:
        text = open(f, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue
    if f.endswith(JS_EXT):
        code, strings = scan_js(text)
        for s, e in strings:
            chunk = code[s:e]
            if not chunk.strip():  # harness-ignore 줄에서 지워진 문자열
                continue
            chunk = re.sub(r"--[\w-]+\s*:[^;{}\"'`]*", lambda m: " " * len(m.group(0)), chunk)
            for name, rx in str_rules:
                for m in rx.finditer(chunk):
                    report(f, text, s + m.start(), name, chunk[m.start():m.start() + 60])
        for s, e in style_blocks(code):
            block = code[s:e]
            for m in STYLE_NUM.finditer(block):
                report(f, text, s + m.start(), "style 숫자 하드코딩", block[m.start():m.start() + 60])
        continue
    css_chunks = []
    if f.endswith(".css"):
        css_chunks.append((0, text))
    else:
        for m in re.finditer(r"<style[^>]*>(.*?)</style>", text, re.S):
            css_chunks.append((m.start(1), m.group(1)))
        for m in re.finditer(r'style="([^"]*)"', text):
            css_chunks.append((m.start(1), m.group(1)))
    for off, chunk in css_chunks:
        # 커스텀 속성 선언은 같은 길이 공백으로 지워 줄 번호를 유지
        chunk = re.sub(r"--[\w-]+\s*:[^;{}]*", lambda m: " " * len(m.group(0)), chunk)
        for name, rx in css_rules:
            for m in rx.finditer(chunk):
                report(f, text, off + m.start(), name, chunk[m.start():m.start() + 60])

extra = f" · 예외 {skipped}개" if skipped else ""
print(f"\n드리프트 {bad}건 · 파일 {len(files)}개 검사{extra}" if bad else f"OK · 드리프트 0건 · 파일 {len(files)}개 검사{extra}")
sys.exit(1 if bad else 0)
PY
