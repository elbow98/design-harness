#!/usr/bin/env bash
# 새 프로토타입 폴더 생성: outputs/<YYYY-MM-DD-slug>/index.html + tokens.css 복사본
# 사용: scripts/new.sh [--template prototype|dashboard] <slug> ["제목"] ["한 줄 설명"]
#   템플릿은 templates/<이름>.html (기본 prototype). 화면 날짜는 Design.md §10 형식(2026.10.14), 폴더명은 2026-10-14
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tpl="prototype"
if [ "${1:-}" = "--template" ]; then tpl="${2:?--template 뒤에 이름}"; shift 2; fi
[ -f "$ROOT/templates/$tpl.html" ] || { echo "템플릿 없음: templates/$tpl.html ($(ls "$ROOT/templates" | sed 's/\.html//' | tr '\n' ' '))" >&2; exit 1; }
slug="${1:?사용법: scripts/new.sh <slug> [\"제목\"] [\"설명\"]}"
title="${2:-$slug}"
desc="${3:-}"
date="$(date +%F)"
shown="$(date +%Y.%m.%d)"
dir="$ROOT/outputs/$date-$slug"
if [ -e "$dir" ]; then echo "이미 있음: $dir (덮어쓰지 않음 — 새 slug나 -v2를 쓰세요)" >&2; exit 1; fi
mkdir -p "$dir"
cp "$ROOT/vault/tokens.css" "$dir/tokens.css"
python3 - "$ROOT/templates/$tpl.html" "$dir/index.html" "$title" "$desc" "$shown" <<'PY'
import sys, html
src, dst, title, desc, date = sys.argv[1:]
t = open(src, encoding="utf-8").read()
for k, v in {"TITLE": title, "DESC": desc, "DATE": date}.items():
    t = t.replace("{{%s}}" % k, html.escape(v))
open(dst, "w", encoding="utf-8").write(t)
PY
echo "$dir/index.html"
