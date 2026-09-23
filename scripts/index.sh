#!/usr/bin/env bash
# outputs/index.html 재생성 — 프로토타입 목록 (최신순). 각 폴더의 <title>과 description을 읽는다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cp "$ROOT/vault/tokens.css" "$ROOT/outputs/tokens.css"
python3 - "$ROOT/outputs" <<'PY'
import sys, os, re, html
out = sys.argv[1]
rows = []
for d in sorted(os.listdir(out), reverse=True):
    p = os.path.join(out, d, "index.html")
    if d.startswith(("_", ".")) or not os.path.isfile(p):
        continue
    s = open(p, encoding="utf-8").read()
    t = re.search(r"<title>(.*?)</title>", s, re.S)
    m = re.search(r'<meta name="description" content="(.*?)"', s, re.S)
    rows.append((d, t.group(1).strip() if t else d, m.group(1).strip() if m else ""))
items = "\n".join(
    f'      <li><a href="{html.escape(d)}/"><span class="t">{t}</span><span class="d muted">{desc}</span></a><span class="meta">{d[:10]}</span></li>'
    for d, t, desc in rows
) or '      <li class="empty"><p>아직 프로토타입이 없습니다. <code>scripts/new.sh &lt;slug&gt;</code>로 시작하세요.</p></li>'
page = f'''<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>프로토타입</title>
<link rel="stylesheet" href="tokens.css">
<style>
  main.container {{ padding-block: var(--sp-10) var(--sp-20); display: grid; gap: var(--sp-6); }}
  ul {{ list-style: none; margin: 0; padding: 0; border-top: 1px solid var(--border); }}
  li {{ display: flex; align-items: baseline; justify-content: space-between; gap: var(--sp-4); padding: var(--sp-4) 0; border-bottom: 1px solid var(--border); }}
  li a {{ display: grid; gap: var(--sp-1); text-decoration: none; color: var(--text); min-width: 0; }}
  li a:hover .t {{ color: var(--accent); }}
  .t {{ font-weight: 600; }}
  .d {{ font-size: var(--fs-sm); }}
  li .meta {{ flex: none; }}
</style>
</head>
<body>
<main class="container">
  <div>
    <h1>프로토타입</h1>
    <p class="muted">디자인 하네스 산출물 · {len(rows)}개</p>
  </div>
  <ul>
{items}
  </ul>
</main>
</body>
</html>
'''
open(os.path.join(out, "index.html"), "w", encoding="utf-8").write(page)
print(f"outputs/index.html — {len(rows)}개")
PY
