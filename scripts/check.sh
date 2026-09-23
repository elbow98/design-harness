#!/usr/bin/env bash
# 토큰 드리프트 검사: 프로토타입 HTML/CSS에서 토큰 밖 값(하드코딩된 색·폰트·px 간격)을 찾는다.
# 사용: scripts/check.sh [경로...]   (기본: outputs/ 전체) · tokens.css 복사본은 검사 제외
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -eq 0 ] && set -- "$ROOT/outputs"
python3 - "$@" <<'PY'
import sys, os, re
files = []
for a in sys.argv[1:]:
    if os.path.isdir(a):
        for dp, _, fs in os.walk(a):
            files += [os.path.join(dp, f) for f in fs if f.endswith((".html", ".css")) and f != "tokens.css"]
    else:
        files.append(a)
# style 블록/속성 안의 CSS만 본다
rules = [
    ("색 하드코딩", re.compile(r"#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla|oklch)\(")),
    ("폰트 하드코딩", re.compile(r"font-family\s*:\s*(?!var\(|inherit)")),
    ("px 하드코딩", re.compile(r"(?<![\w-])(?:margin|padding|gap|row-gap|column-gap|font-size|border-radius|top|bottom|left|right)\s*:[^;\"}]*?\b(?!0px)\d+px")),
]
bad = 0
for f in files:
    text = open(f, encoding="utf-8").read()
    css_chunks = []
    if f.endswith(".css"):
        css_chunks.append((0, text))
    else:
        for m in re.finditer(r"<style[^>]*>(.*?)</style>", text, re.S):
            css_chunks.append((m.start(1), m.group(1)))
        for m in re.finditer(r'style="([^"]*)"', text):
            css_chunks.append((m.start(1), m.group(1)))
    for off, chunk in css_chunks:
        for name, rx in rules:
            for m in rx.finditer(chunk):
                line = text.count("\n", 0, off + m.start()) + 1
                snippet = chunk[m.start():m.start()+60].split("\n")[0]
                print(f"{os.path.relpath(f)}:{line}  [{name}]  {snippet}")
                bad += 1
print(f"\n드리프트 {bad}건 · 파일 {len(files)}개 검사" if bad else f"OK · 드리프트 0건 · 파일 {len(files)}개 검사")
sys.exit(1 if bad else 0)
PY
