#!/usr/bin/env bash
# 렌더 검증: Playwright(Chromium)로 데스크톱(1280)·모바일(390) × 라이트·다크 전체 페이지 스크린샷
# + 가로 넘침(overflow)과 콘솔 에러 + 접근성(axe-core) 자동 보고. 문제가 있으면 exit 1.
# 사용: scripts/shot.sh [--no-a11y] <html 경로 또는 URL> [출력 폴더]
#   → <출력>/{desktop,mobile}-{light,dark}.png + <출력>/a11y.json
#
# 접근성: scripts/vendor/axe.min.js(axe-core 버전 고정, 네트워크 불필요)를 렌더마다 주입한다.
#   태그 wcag2a·wcag2aa·wcag21a·wcag21aa·best-practice. 끈 규칙: region(모든 내용을 landmark 안에 —
#   한 화면짜리 프로토타입·카탈로그에 강제하면 소음만 늘어난다). heading-order 등 나머지는 켜 둔다.
#   critical·serious = 실패(exit 1), moderate·minor = 경고. 4장에서 반복되는 위반은 한 번으로 묶는다.
#   모바일 렌더에서는 터치 타깃 40px 미만(Design.md §7)도 경고로 보고한다(문장 안 링크 제외).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
a11y=1; args=()
for a in "$@"; do [[ "$a" == "--no-a11y" ]] && a11y=0 || args+=("$a"); done
[[ ${#args[@]} -ge 1 ]] || { echo "사용법: scripts/shot.sh [--no-a11y] <html|url> [출력폴더]" >&2; exit 2; }
target="${args[0]}"
tmpd="${TMPDIR:-/tmp}"; out="${args[1]:-${tmpd%/}/harness-shots}"
python3 - "$target" "$out" "$a11y" "$ROOT/scripts/vendor/axe.min.js" <<'PY'
import sys, os, json, re, pathlib
from playwright.sync_api import sync_playwright
target, out, a11y, axe_path = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
url = target if target.startswith(("http:", "https:", "file:")) else pathlib.Path(target).resolve().as_uri()
os.makedirs(out, exist_ok=True)
problems = 0
AXE_TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "best-practice"]
AXE_OFF = ["region"]
KO = {  # axe 규칙 → 한국어 한 줄 (없으면 axe 영문 설명)
    "color-contrast": "글자와 배경의 명암비가 부족함 (본문 4.5:1, 큰 글자 3:1)",
    "color-contrast-enhanced": "명암비 AAA 미달",
    "image-alt": "이미지에 alt가 없음",
    "button-name": "버튼에 읽을 수 있는 이름이 없음 (아이콘 버튼은 aria-label)",
    "link-name": "링크에 읽을 수 있는 이름이 없음",
    "label": "입력창에 라벨이 없음 (placeholder는 라벨이 아님)",
    "select-name": "select에 라벨이 없음",
    "input-button-name": "입력 버튼에 이름이 없음",
    "aria-input-field-name": "ARIA 입력 필드에 이름이 없음",
    "aria-toggle-field-name": "ARIA 토글에 이름이 없음",
    "aria-command-name": "ARIA 버튼·링크·메뉴 항목에 이름이 없음",
    "aria-progressbar-name": "진행 막대에 이름이 없음",
    "aria-meter-name": "meter에 이름이 없음",
    "aria-tooltip-name": "툴팁에 이름이 없음",
    "aria-dialog-name": "대화상자에 이름이 없음",
    "aria-allowed-attr": "이 역할에 허용되지 않는 aria 속성",
    "aria-allowed-role": "이 요소에 허용되지 않는 role",
    "aria-required-attr": "role에 필요한 aria 속성이 빠짐",
    "aria-required-children": "role에 필요한 자식 요소가 없음 (예: tablist 안 tab)",
    "aria-required-parent": "role에 필요한 부모가 없음 (예: tab 바깥 tablist)",
    "aria-valid-attr": "존재하지 않는 aria 속성",
    "aria-valid-attr-value": "aria 속성 값이 잘못됨 (가리키는 id가 없는 등)",
    "aria-roles": "존재하지 않는 role 값",
    "aria-hidden-focus": "aria-hidden 안에 포커스 가능한 요소가 있음",
    "aria-hidden-body": "body에 aria-hidden",
    "aria-prohibited-attr": "이 요소에 금지된 aria 속성 (예: 이름 없는 div의 aria-label)",
    "nested-interactive": "조작 요소 안에 조작 요소가 중첩됨 (버튼 안 링크 등)",
    "scrollable-region-focusable": "스크롤 영역에 키보드로 닿을 수 없음 (tabindex=0 필요)",
    "duplicate-id": "같은 id가 여러 번 쓰임",
    "duplicate-id-aria": "aria가 참조하는 id가 중복됨",
    "duplicate-id-active": "포커스 가능한 요소의 id가 중복됨",
    "html-has-lang": "<html>에 lang이 없음 (lang=\"ko\")",
    "html-lang-valid": "<html lang> 값이 잘못됨",
    "document-title": "<title>이 없음",
    "meta-viewport": "확대를 막는 viewport 설정 (user-scalable=no 등)",
    "meta-viewport-large": "확대 배율을 제한함",
    "list": "ul·ol 바로 아래에 li가 아닌 요소",
    "listitem": "li가 ul·ol 밖에 있음",
    "definition-list": "dl 구조가 잘못됨",
    "dlitem": "dt·dd가 dl 밖에 있음",
    "td-headers-attr": "표 headers 속성이 잘못됨",
    "th-has-data-cells": "표 머리글에 해당 데이터 셀이 없음",
    "table-duplicate-name": "표 caption과 summary가 같음",
    "empty-table-header": "빈 표 머리글",
    "heading-order": "제목 단계를 건너뜀 (h1 → h3)",
    "empty-heading": "빈 제목",
    "page-has-heading-one": "h1이 없음",
    "landmark-one-main": "main landmark가 없음",
    "landmark-unique": "같은 종류 landmark의 이름이 겹침",
    "landmark-no-duplicate-main": "main이 두 개 이상",
    "landmark-no-duplicate-banner": "banner(header)가 두 개 이상",
    "landmark-no-duplicate-contentinfo": "contentinfo(footer)가 두 개 이상",
    "landmark-complementary-is-top-level": "aside가 다른 landmark 안에 있음",
    "landmark-banner-is-top-level": "header가 다른 landmark 안에 있음",
    "landmark-contentinfo-is-top-level": "footer가 다른 landmark 안에 있음",
    "landmark-main-is-top-level": "main이 다른 landmark 안에 있음",
    "tabindex": "tabindex가 0보다 큼 (탭 순서가 꼬임)",
    "focus-order-semantics": "포커스되는 요소에 알맞은 role이 없음",
    "frame-title": "iframe에 title이 없음",
    "svg-img-alt": "role=img SVG에 이름이 없음",
    "role-img-alt": "role=img 요소에 이름이 없음",
    "object-alt": "object에 대체 텍스트가 없음",
    "link-in-text-block": "문장 안 링크가 색으로만 구분됨 (밑줄 필요)",
    "presentation-role-conflict": "장식용(role=presentation) 요소가 포커스되거나 aria 속성을 가짐",
    "label-title-only": "라벨 없이 title로만 이름을 줌",
    "label-content-name-mismatch": "보이는 글자와 접근 가능한 이름이 다름",
    "autocomplete-valid": "autocomplete 값이 잘못됨",
    "avoid-inline-spacing": "인라인 style의 !important 간격이 사용자 설정을 막음",
    "identical-links-same-purpose": "같은 이름 링크가 다른 곳으로 감",
    "image-redundant-alt": "alt가 주변 글자를 되풀이함",
    "server-side-image-map": "서버 측 이미지 맵",
    "skip-link": "건너뛰기 링크의 대상이 없음",
    "summary-name": "summary에 이름이 없음",
    "target-size": "터치 타깃이 너무 작음",
    "video-caption": "영상에 자막이 없음",
}
SEV = {"critical": 0, "serious": 1, "moderate": 2, "minor": 3}
agg = {}      # 규칙 id → 묶은 위반
touch = {}    # 셀렉터 → (w, h)
axe_ver = None
renders = []
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
            # 넘침 검사: 페이지 전체 scrollWidth + 뷰포트 오른쪽을 넘는 요소.
            # 조상 중 overflow-x가 hidden/auto/scroll/clip인 요소 안에 있으면 제외한다 —
            # 잘리거나(지도 타일) 그 안에서 스크롤되는(표 래퍼) 것은 페이지 넘침이 아니다.
            over = pg.evaluate("""() => {
              const vw = document.documentElement.clientWidth, bad = [], cache = new Map();
              const clipped = el => {
                const chain = [];
                for (let a = el.parentElement; a && a !== document.body && a !== document.documentElement; a = a.parentElement) {
                  if (cache.has(a)) { const v = cache.get(a); chain.forEach(c => cache.set(c, v)); return v; }
                  chain.push(a);
                  const ox = getComputedStyle(a).overflowX;
                  if (ox !== 'visible') { chain.forEach(c => cache.set(c, true)); return true; }
                }
                chain.forEach(c => cache.set(c, false));
                return false;
              };
              if (document.documentElement.scrollWidth > vw) bad.push('page scrollWidth ' + document.documentElement.scrollWidth + ' > ' + vw);
              let n = 0;
              for (const el of document.querySelectorAll('body *')) {
                const r = el.getBoundingClientRect();
                if (!r.width || r.right <= vw + 1 || clipped(el)) continue;
                n++;
                if (bad.length < 6) { const c = el.getAttribute('class'); bad.push(el.tagName.toLowerCase() + (c ? '.' + c.trim().split(/\\s+/)[0] : '') + ' right=' + Math.round(r.right)); }
              }
              if (n > 6) bad.push('외 ' + (n - 6) + '개');
              return bad;
            }""")
            f = os.path.join(out, f"{name}-{scheme}.png")
            pg.screenshot(path=f, full_page=True)
            label = f"{name}-{scheme}"
            a11y_note = ""
            if a11y:
                try:
                    pg.add_script_tag(path=axe_path)
                    res = pg.evaluate("""([tags, off]) => axe.run(document, {
                        runOnly: {type: 'tag', values: tags},
                        rules: Object.fromEntries(off.map(r => [r, {enabled: false}])),
                        resultTypes: ['violations'],
                        preload: false  // CSSOM 미리 읽기는 file://에서 XHR CORS 콘솔 에러를 낸다
                      }).then(r => ({v: axe.version, violations: r.violations.map(x => ({
                        id: x.id, impact: x.impact, help: x.help, helpUrl: x.helpUrl,
                        nodes: x.nodes.map(n => n.target.join(' ')),
                        data: x.nodes.slice(0, 5).map(n => { const d = (n.any[0] || n.all[0] || {}).data;
                          return d && d.contrastRatio ? d.fgColor + ' / ' + d.bgColor + ' = ' + d.contrastRatio + ':1 (기준 ' + d.expectedContrastRatio + ')' : null; }).filter(Boolean)
                      }))}))""", [AXE_TAGS, AXE_OFF])
                    axe_ver = res["v"]
                    blocking = 0
                    for v in res["violations"]:
                        a = agg.setdefault(v["id"], {"id": v["id"], "impact": v["impact"], "help": v["help"],
                                                     "ko": KO.get(v["id"], v["help"]), "helpUrl": v["helpUrl"],
                                                     "renders": [], "targets": [], "details": []})
                        if SEV.get(v["impact"], 3) < SEV.get(a["impact"], 3): a["impact"] = v["impact"]
                        a["renders"].append(label)
                        a["targets"] += [t for t in v["nodes"] if t not in a["targets"]]
                        a["details"] += [f"{label}: {d}" for d in v["data"] if len(a["details"]) < 8]
                        blocking += v["impact"] in ("critical", "serious")
                    if blocking: a11y_note = f"접근성 critical·serious {blocking}종"
                    if mobile:
                        # Design.md §7: 터치 타깃 40px 이상. 문장 안 인라인 링크는 제외(WCAG 2.5.8 예외와 같음)
                        for s, tw, th in pg.evaluate("""() => {
                          const sel = el => el.id ? '#' + el.id : el.tagName.toLowerCase() + (el.getAttribute('class') ? '.' + el.getAttribute('class').trim().split(/\\s+/).slice(0, 2).join('.') : '');
                          const out = [];
                          for (const el of document.querySelectorAll('a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button], [role=tab], [role=checkbox], [role=switch], [tabindex]:not([tabindex="-1"])')) {
                            const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
                            if (!r.width || !r.height || cs.visibility === 'hidden') continue;
                            if (el.closest('label') && (el.type === 'checkbox' || el.type === 'radio')) {
                              const lr = el.closest('label').getBoundingClientRect();
                              if (lr.height >= 40) continue;
                            }
                            if (el.tagName === 'A' && cs.display === 'inline' && el.parentElement &&
                                [...el.parentElement.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) continue;
                            if (r.width < 40 || r.height < 40) out.push([sel(el), Math.round(r.width), Math.round(r.height)]);
                          }
                          return out;
                        }"""):
                            touch.setdefault(s, (tw, th))
                except Exception as e:
                    a11y_note = f"axe 실행 실패: {str(e)[:120]}"
            status = "OK"
            if over or errors or a11y_note.startswith("접근성") :
                problems += 1
                status = "문제: " + "; ".join([*("넘침 " + o for o in over), *("콘솔 " + e for e in errors), *([a11y_note] if a11y_note else [])])
            elif a11y_note:
                status = "OK (" + a11y_note + ")"
            print(f"{f}  {status}")
            renders.append({"render": label, "file": f, "status": status})
            ctx.close()
    b.close()

if a11y:
    vs = sorted(agg.values(), key=lambda a: (SEV.get(a["impact"], 3), a["id"]))
    for a in vs: a["count"] = len(a["targets"])
    tt = [{"selector": s, "width": w, "height": h} for s, (w, h) in touch.items()]
    json.dump({"target": url, "axe": axe_ver, "tags": AXE_TAGS, "disabled": AXE_OFF, "renders": renders,
               "violations": vs, "touch_targets_under_40": tt},
              open(os.path.join(out, "a11y.json"), "w"), ensure_ascii=False, indent=2)
    if vs or tt:
        print(f"\n접근성 (axe-core {axe_ver}) — critical·serious는 실패, moderate·minor는 경고")
        for a in vs:
            every = len(set(a["renders"])) == len(renders)
            where = "4장 모두" if every else ", ".join(dict.fromkeys(a["renders"]))
            more = f" 외 {a['count'] - 3}개" if a["count"] > 3 else ""
            print(f"  [{a['impact']}] {a['id']} — {a['ko']} ({where})\n      {' | '.join(a['targets'][:3])}{more}")
            for d in dict.fromkeys(x.split(": ", 1)[1] for x in a["details"]):
                print(f"      · {d}")
        if tt:
            more = f" 외 {len(tt) - 5}개" if len(tt) > 5 else ""
            print(f"  [경고] touch-target — 모바일 터치 타깃 40px 미만 (Design.md §7) {len(tt)}개\n      " +
                  " | ".join(f"{t['selector']} {t['width']}×{t['height']}" for t in tt[:5]) + more)
    else:
        print(f"\n접근성 (axe-core {axe_ver}) 위반 0건")
    print(f"→ {os.path.join(out, 'a11y.json')}")
blk = sum(1 for a in agg.values() if a["impact"] in ("critical", "serious"))
warn = len(agg) - blk + (1 if touch else 0)
a11y_sum = f" · 접근성 실패 {blk}종 · 경고 {warn}종" if a11y else " · 접근성 검사 끔"
print(f"\n렌더 {len(renders)}장 · 문제 {problems}장{a11y_sum}")
sys.exit(1 if problems else 0)
PY
