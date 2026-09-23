#!/usr/bin/env bash
# 렌더 검증: Playwright(Chromium)로 데스크톱(1280)·모바일(390) × 라이트·다크 전체 페이지 스크린샷
# + 가로 넘침(overflow)과 콘솔 에러를 자동 보고. 문제가 있으면 exit 1.
# 사용: scripts/shot.sh <html 경로 또는 URL> [출력 폴더]   → <출력>/{desktop,mobile}-{light,dark}.png
set -euo pipefail
target="${1:?사용법: scripts/shot.sh <html|url> [출력폴더]}"
out="${2:-${TMPDIR:-/tmp}/harness-shots}"
python3 - "$target" "$out" <<'PY'
import sys, os, pathlib
from playwright.sync_api import sync_playwright
target, out = sys.argv[1], sys.argv[2]
url = target if target.startswith(("http:", "https:", "file:")) else pathlib.Path(target).resolve().as_uri()
os.makedirs(out, exist_ok=True)
problems = 0
with sync_playwright() as p:
    b = p.chromium.launch()
    for name, w, h, mobile in [("desktop", 1280, 900, False), ("mobile", 390, 844, True)]:
        for scheme in ["light", "dark"]:
            ctx = b.new_context(viewport={"width": w, "height": h}, device_scale_factor=1,
                                is_mobile=mobile, has_touch=mobile, color_scheme=scheme)
            pg = ctx.new_page()
            errors = []
            pg.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
            pg.on("pageerror", lambda e: errors.append(str(e)))
            pg.goto(url, wait_until="networkidle")
            pg.wait_for_timeout(300)
            over = pg.evaluate("""() => {
              const vw = document.documentElement.clientWidth, bad = [];
              if (document.documentElement.scrollWidth > vw) bad.push('page scrollWidth ' + document.documentElement.scrollWidth + ' > ' + vw);
              for (const el of document.querySelectorAll('body *')) {
                if (el.closest('.table-wrap')) continue;
                const r = el.getBoundingClientRect();
                if (r.width && r.right > vw + 1) { bad.push(el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : '') + ' right=' + Math.round(r.right)); if (bad.length > 5) break; }
              }
              return bad;
            }""")
            f = os.path.join(out, f"{name}-{scheme}.png")
            pg.screenshot(path=f, full_page=True)
            status = "OK"
            if over or errors:
                problems += 1
                status = "문제: " + "; ".join([*("넘침 " + o for o in over), *("콘솔 " + e for e in errors)])
            print(f"{f}  {status}")
            ctx.close()
    b.close()
sys.exit(1 if problems else 0)
PY
