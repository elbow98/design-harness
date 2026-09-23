#!/usr/bin/env bash
# 새 프로토타입 폴더 생성: outputs/<YYYY-MM-DD-slug>/index.html + tokens.css 복사본
# 사용: scripts/new.sh <slug> ["제목"] ["한 줄 설명"]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
slug="${1:?사용법: scripts/new.sh <slug> [\"제목\"] [\"설명\"]}"
title="${2:-$slug}"
desc="${3:-}"
date="$(date +%F)"
dir="$ROOT/outputs/$date-$slug"
if [ -e "$dir" ]; then echo "이미 있음: $dir (덮어쓰지 않음 — 새 slug나 -v2를 쓰세요)" >&2; exit 1; fi
mkdir -p "$dir"
cp "$ROOT/vault/tokens.css" "$dir/tokens.css"
python3 - "$ROOT/templates/prototype.html" "$dir/index.html" "$title" "$desc" "$date" <<'PY'
import sys, html
src, dst, title, desc, date = sys.argv[1:]
t = open(src, encoding="utf-8").read()
for k, v in {"TITLE": title, "DESC": desc, "DATE": date}.items():
    t = t.replace("{{%s}}" % k, html.escape(v))
open(dst, "w", encoding="utf-8").write(t)
PY
echo "$dir/index.html"
