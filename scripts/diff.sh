#!/usr/bin/env bash
# 시각 회귀 비교: 기준선 스크린샷과 지금 렌더를 픽셀 단위로 비교한다.
# 사용:
#   scripts/diff.sh baseline <html|url> [이름]   → vault/baselines/<이름>/{desktop,mobile}-{light,dark}.png
#   scripts/diff.sh compare  <html|url> [이름] [--threshold 0.1]
#       → $TMPDIR/harness-diff/<이름>/{current,diff}-*.png, 바뀐 비율(%)·바뀐 영역 상자 목록
#       바뀐 비율이 임계(기본 0.1%)를 넘거나 페이지 높이가 달라지면 exit 1.
# 이름 기본값: 파일명(확장자 뺌). index.html이면 상위 폴더 이름. URL이면 호스트+경로.
# 흔들림 제거: prefers-reduced-motion, 전환·애니메이션·캐럿 끄는 CSS 주입, document.fonts.ready 대기.
# 픽셀 비교: 채널 차이 16 이하는 같은 픽셀로 본다(안티앨리어싱 잡음). 바뀐 픽셀은 16px 칸으로 묶어 상자로 보고.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
usage="사용법: scripts/diff.sh baseline|compare <html|url> [이름] [--threshold %]"
threshold=0.1; args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) threshold="${2:?$usage}"; shift 2 ;;
    --threshold=*) threshold="${1#*=}"; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
[[ ${#args[@]} -ge 2 && ( "${args[0]}" == baseline || "${args[0]}" == compare ) ]] || { echo "$usage" >&2; exit 2; }
mode="${args[0]}"; target="${args[1]}"; name="${args[2]:-}"
python3 - "$ROOT" "$mode" "$target" "$name" "$threshold" "${TMPDIR:-/tmp}" <<'PY'
import sys, os, re, json, pathlib, datetime
from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops, ImageDraw

root, mode, target, name, threshold, tmp = sys.argv[1:7]
threshold = float(threshold)
is_url = target.startswith(("http:", "https:", "file:"))
url = target if is_url else pathlib.Path(target).resolve().as_uri()
if not is_url and not os.path.exists(target):
    print(f"없는 파일: {target}"); sys.exit(2)
if not name:
    if is_url:
        name = re.sub(r"^\w+://", "", target)
    else:
        pth = pathlib.Path(target).resolve()
        name = pth.parent.name if pth.stem == "index" else pth.stem
    name = re.sub(r"[^\w가-힣.-]+", "-", name).strip("-").lower() or "page"
base_dir = os.path.join(root, "vault", "baselines", name)
work_dir = os.path.join(tmp, "harness-diff", name)
out_dir = base_dir if mode == "baseline" else work_dir
if mode == "compare" and not os.path.isdir(base_dir):
    print(f"기준선 없음: {os.path.relpath(base_dir, root)} — 먼저 scripts/diff.sh baseline {target} {name}"); sys.exit(2)
os.makedirs(out_dir, exist_ok=True)

STILL = "*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important;scroll-behavior:auto!important}"
RENDERS = [("desktop", 1280, 900, False), ("mobile", 390, 844, True)]
shots = {}
with sync_playwright() as p:
    b = p.chromium.launch()
    for vp, w, h, mobile in RENDERS:
        for scheme in ["light", "dark"]:
            ctx = b.new_context(viewport={"width": w, "height": h}, device_scale_factor=1, is_mobile=mobile,
                                has_touch=mobile, color_scheme=scheme, reduced_motion="reduce")
            pg = ctx.new_page()
            pg.goto(url, wait_until="networkidle")
            pg.add_style_tag(content=STILL)
            pg.evaluate("() => document.fonts.ready")
            pg.wait_for_timeout(300)
            key = f"{vp}-{scheme}"
            f = os.path.join(out_dir, (f"{key}.png" if mode == "baseline" else f"current-{key}.png"))
            pg.screenshot(path=f, full_page=True, animations="disabled", caret="hide")
            shots[key] = f
            ctx.close()
    b.close()

if mode == "baseline":
    json.dump({"target": target, "url": url, "created": datetime.datetime.now().isoformat(timespec="seconds"),
               "renders": [k for k in shots]}, open(os.path.join(base_dir, "meta.json"), "w"), ensure_ascii=False, indent=2)
    total = sum(os.path.getsize(f) for f in shots.values())
    for k, f in shots.items():
        im = Image.open(f); print(f"{os.path.relpath(f, root)}  {im.width}×{im.height}")
    print(f"기준선 저장: {os.path.relpath(base_dir, root)} · {total / 1024:.0f}KB")
    sys.exit(0)

CELL, TOL = 16, 16
failed = False
print(f"비교: {os.path.relpath(base_dir, root)} ↔ 지금 렌더 (임계 {threshold}%)")
for key, cur_f in shots.items():
    base_f = os.path.join(base_dir, f"{key}.png")
    if not os.path.exists(base_f):
        print(f"{key}: 기준선 파일 없음"); failed = True; continue
    a, c = Image.open(base_f).convert("RGB"), Image.open(cur_f).convert("RGB")
    notes = []
    if a.size != c.size:
        if a.height != c.height: notes.append(f"레이아웃 높이 변화 {c.height - a.height:+d}px ({a.height}→{c.height})")
        if a.width != c.width: notes.append(f"폭 변화 {c.width - a.width:+d}px")
    w, h = min(a.width, c.width), min(a.height, c.height)
    diff = ImageChops.difference(a.crop((0, 0, w, h)), c.crop((0, 0, w, h)))
    # 채널별 최대 차이 — 밝기(L)만 보면 같은 밝기의 색 바뀜을 놓친다
    r, g, bch = diff.split()
    mask = ImageChops.lighter(ImageChops.lighter(r, g), bch).point(lambda v: 255 if v > TOL else 0)
    changed = sum(mask.histogram()[255:])
    ratio = changed / (w * h) * 100 if w * h else 0
    # 16px 칸 단위로 묶어 연결된 칸들을 상자로
    cw, ch = (w + CELL - 1) // CELL, (h + CELL - 1) // CELL
    small = mask.resize((cw, ch), Image.Resampling.BOX)
    px = small.load()
    cells = {(x, y) for y in range(ch) for x in range(cw) if px[x, y] > 0}
    boxes, seen = [], set()
    for cell in cells:
        if cell in seen: continue
        stack, xs, ys = [cell], [], []
        seen.add(cell)
        while stack:
            x, y = stack.pop(); xs.append(x); ys.append(y)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in cells and n not in seen: seen.add(n); stack.append(n)
        boxes.append((min(xs) * CELL, min(ys) * CELL, min((max(xs) + 1) * CELL, w), min((max(ys) + 1) * CELL, h)))
    boxes.sort(key=lambda bx: (bx[1], bx[0]))
    over = ratio > threshold or bool(notes)
    failed |= over
    out = c.copy()
    d = ImageDraw.Draw(out)
    for bx in boxes:
        d.rectangle(bx, outline=(230, 0, 0), width=3)
    if c.height > h:  # 새로 늘어난 아래 영역
        d.rectangle((0, h, c.width - 1, c.height - 1), outline=(230, 0, 0), width=3)
    dpath = os.path.join(work_dir, f"diff-{key}.png")
    out.save(dpath)
    status = "바뀜" if over else "같음"
    print(f"{key}: {status} · 바뀐 픽셀 {ratio:.3f}% ({changed:,}px){' · ' + ' · '.join(notes) if notes else ''}")
    if over:
        for bx in boxes[:12]:
            print(f"    x={bx[0]} y={bx[1]} {bx[2] - bx[0]}×{bx[3] - bx[1]}")
        if len(boxes) > 12: print(f"    외 {len(boxes) - 12}개 영역")
        print(f"    → {dpath}")
print(f"\n{'실패: 기준선과 다름' if failed else 'OK: 기준선과 같음'} · 결과 {work_dir}")
sys.exit(1 if failed else 0)
PY
