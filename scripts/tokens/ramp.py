#!/usr/bin/env python3
"""브랜드 seed 색 하나로 12단계 사다리와 테마 슬롯 제안을 만든다 (skills/brand가 쓴다).

사용:
  scripts/tokens/ramp.py "#C2410C"                       사다리 + 슬롯 제안 출력
  scripts/tokens/ramp.py "#C2410C" --neutral 0.008       바탕 온도도 seed 색상 각도로 (채도 0.005~0.012 권장)
  scripts/tokens/ramp.py "#C2410C" --neutral 0.008 --neutral-hue 75   바탕만 다른 각도로(붉은 seed의 바탕이 분홍으로 뜰 때)
  scripts/tokens/ramp.py "#C2410C" --css 브랜드이름        vault/themes/<이름>/theme.css 초안 생성(있으면 덮어쓰지 않음)

계산 (OKLCH):
- 12단계 사다리: seed의 색상 각도·채도로 L 0.985 → 0.26. 단계마다 흰 글자·검은 바탕 대비를 같이 보여 준다.
- accent(라이트): seed 밝기에서 시작해 흰 글자·페이지 바탕·accent-soft(강조 배지) 대비가 모두 4.8:1 이상이 될 때까지 어둡게.
  hover = L −0.07, soft = L 0.95 저채도, on-accent = 흰색.
- accent(다크): L 0.70부터 밝게 올려 다크 표면 위 6:1 이상. hover = L +0.06, soft = L 0.28, on-accent = 같은 각도 L 0.18.
- 순차 램프 seq-1…9: 지금 tokens.css seq의 밝기를 그대로 쓰고 색상 각도만 seed로 → 단계 간격이 검증된 값과 같다.
  다크는 같은 9색을 뒤집는다. map-seq-1…5 = 라이트 seq 1·3·5·7·9.
- 범주 1번(series-1)은 제안하지 않는다 — 검증기로 따로 고른다(vault/themes/README.md).
- 단계 계약 4줄(라이트·다크): ① 11 on 1 ≥4.5 ② 12 on 2 ≥7 ③ on-accent on accent ≥4.5 ④ 입력창 테두리로 쓸 첫 단계
  (1단계 대비 ≥3:1). 하나라도 실패하면 exit 1(--css도 쓰지 않음). 브랜드 hue가 상태색과 30° 안이면 경고 한 줄.
결과는 반드시 scripts/tokens/check_theme.py <이름>으로 확인한다.
"""
import sys
sys.dont_write_bytecode = True  # scripts/tokens/에 __pycache__를 남기지 않는다

import argparse

import tokencss as tc
from colorlib import contrast, oklch, oklch_to_srgb, parse_color, to_hex

# 12단계 역할(Radix식): 1 바탕 · 2 옅은 바탕 · 3–5 면·hover·선택 · 6–8 선·테두리 · 9–10 채움 · 11 글자 · 12 고대비 글자
LADDER_L = [0.985, 0.96, 0.92, 0.87, 0.81, 0.74, 0.66, 0.58, 0.50, 0.42, 0.34, 0.26]
DARK_LADDER_L = [0.17, 0.20, 0.24, 0.28, 0.32, 0.37, 0.44, 0.53, 0.60, 0.66, 0.80, 0.93]
STATUS = ["positive", "negative", "warning"]
HUE_WARN = 30  # 브랜드 hue가 상태색 hue와 이 각도 안이면 경고
WHITE = (1.0, 1.0, 1.0)
NEUTRALS = ["bg", "surface", "surface-2", "border", "border-strong", "text", "text-2", "text-3"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("seed", help='브랜드 seed 색 (예: "#C2410C")')
    ap.add_argument("--neutral", type=float, help="바탕 온도: 무채색에 seed 각도로 섞을 채도 (0.005~0.012)")
    ap.add_argument("--neutral-hue", type=float, help="바탕 온도의 색상 각도 (기본 = seed 각도). 따뜻한 회색 ≈ 70–85")
    ap.add_argument("--css", metavar="이름", help="vault/themes/<이름>/theme.css 초안을 쓴다")
    a = ap.parse_args()
    seed = parse_color(a.seed if a.seed.startswith("#") else "#" + a.seed)
    if not seed:
        sys.exit(f"색을 못 읽음: {a.seed}")
    L0, C0, h = oklch(seed)
    C0 = max(C0, 0.04)
    hx = lambda L, C: to_hex(oklch_to_srgb(L, C, h))
    rgb = lambda s: parse_color(s)

    base = tc.parse(tc.TOKENS)
    lv, dv = tc.mode_values(base, "light"), tc.mode_values(base, "dark")
    l_bg, d_surf = tc.resolve_color(lv, "bg"), tc.resolve_color(dv, "surface")

    print(f"seed {to_hex(seed)}  OKLCH L {L0:.3f} C {C0:.3f} h {h:.1f}\n")
    chroma = lambda L, mid: C0 * max(0.25, 1 - abs(L - mid) / 0.45)
    ladders = {"light": [hx(L, chroma(L, 0.62)) for L in LADDER_L],
               "dark": [hx(L, chroma(L, 0.55)) for L in DARK_LADDER_L]}
    print("12단계 사다리   라이트    (흰 글자)   다크      (다크 표면 위)")
    for i in range(12):
        lt, dk = ladders["light"][i], ladders["dark"][i]
        print(f"  {i + 1:2}  {lt}  {contrast(WHITE, rgb(lt)):5.2f}:1   {dk}  {contrast(rgb(dk), d_surf):5.2f}:1")

    soft = rgb(hx(0.95, min(C0, 0.03)))
    L = min(L0, 0.62)
    while L > 0.2 and min(contrast(WHITE, rgb(hx(L, C0))), contrast(rgb(hx(L, C0)), l_bg),
                          contrast(rgb(hx(L, C0)), soft)) < 4.8:
        L -= 0.005
    dL = 0.70
    while dL < 0.95 and contrast(rgb(hx(dL, C0)), d_surf) < 6:
        dL += 0.005
    light = {"accent": hx(L, C0), "accent-hover": hx(L - 0.07, C0), "accent-soft": hx(0.95, min(C0, 0.03)),
             "on-accent": "#FFFFFF", "focus": hx(L, C0)}
    dark = {"accent": hx(dL, C0), "accent-hover": hx(dL + 0.06, C0), "accent-soft": hx(0.28, min(C0, 0.05)),
            "on-accent": hx(0.18, min(C0, 0.04)), "focus": hx(dL, C0)}
    seqL = [oklch(tc.resolve_color(lv, f"seq-{i}"))[0] for i in range(1, 10)]
    seq = [hx(sl, C0 * (0.35 if i == 0 else 1.0)) for i, sl in enumerate(seqL)]
    mapseq = [seq[i] for i in (0, 2, 4, 6, 8)]
    nl, nd = {}, {}
    if a.neutral is not None:
        for n in NEUTRALS:
            for vals, out in ((lv, nl), (dv, nd)):
                nL = oklch(tc.resolve_color(vals, n))[0]
                out[n] = to_hex(oklch_to_srgb(nL, a.neutral, h if a.neutral_hue is None else a.neutral_hue))
        nl["map-ink"], nl["map-no-data"] = nl["text"], nl["border-strong"]

    print(f"\n슬롯 제안  accent 라이트 L {L:.3f} (흰 글자 {contrast(WHITE, rgb(light['accent'])):.2f}:1) · "
          f"다크 L {dL:.3f} (표면 위 {contrast(rgb(dark['accent']), d_surf):.2f}:1)")
    if not contract(ladders, {"light": light, "dark": dark}, h, lv, rgb):
        sys.exit(1)
    # 주석에 #hex를 남기면 check.sh가 하드코딩으로 잡는다 → seed는 # 없이
    cmd = '"' + a.seed.lstrip("#") + '"' + (f" --neutral {a.neutral:g}" if nl else "") + (f" --neutral-hue {a.neutral_hue:g}" if a.neutral_hue is not None else "")
    css = render(a.css or "draft", cmd, light, dark, seq, mapseq, nl, nd)
    if not a.css:
        print(css)
        return
    path = tc.THEMES / a.css / "theme.css"
    if path.exists():
        sys.exit(f"이미 있음(덮어쓰지 않음): {path.relative_to(tc.ROOT)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(css, encoding="utf-8")
    print(f"생성: {path.relative_to(tc.ROOT)}\n다음: scripts/tokens/check_theme.py {a.css}")


def contract(ladders, slots, h, lv, rgb):
    """단계 계약 4줄 (KRDS: 단계 차 = 대비, Radix: 11·12단계 글자 보증). 실패가 있으면 False.
    ① 11 on 1 ≥4.5  ② 12 on 2 ≥7  ③ on-accent on accent ≥4.5  ④ 1단계 대비 3:1을 넘는 첫 단계(입력창 테두리)"""
    ok = True
    cols = {}
    for mode in ("light", "dark"):
        lad = ladders[mode]
        c1 = contrast(rgb(lad[10]), rgb(lad[0]))
        c2 = contrast(rgb(lad[11]), rgb(lad[1]))
        c3 = contrast(rgb(slots[mode]["on-accent"]), rgb(slots[mode]["accent"]))
        border = next((i + 1 for i in range(1, 12) if contrast(rgb(lad[i]), rgb(lad[0])) >= 3), None)
        cols[mode] = (c1 >= 4.5, c1), (c2 >= 7, c2), (c3 >= 4.5, c3), (border is not None, border)
        ok = ok and all(r[0] for r in cols[mode])
    f = lambda r: f"{'PASS' if r[0] else 'FAIL'} {r[1]:5.2f}:1"
    L, D = cols["light"], cols["dark"]
    print("\n단계 계약 (라이트 / 다크)")
    print(f"  ① 글자(11) on 바탕(1)        ≥4.5:1  {f(L[0])} / {f(D[0])}")
    print(f"  ② 고대비 글자(12) on 2단계   ≥7:1    {f(L[1])} / {f(D[1])}")
    print(f"  ③ --on-accent on --accent    ≥4.5:1  {f(L[2])} / {f(D[2])}")
    b = lambda r: f"{r[1]}단계" if r[0] else "FAIL 없음"
    print(f"  ④ 입력창 테두리 첫 단계(1단계 대비 ≥3:1)  {b(L[3])} / {b(D[3])}")
    for n in STATUS:
        sh = oklch(tc.resolve_color(lv, n))[2]
        d = abs((h - sh + 180) % 360 - 180)
        if d <= HUE_WARN:
            print(f"  경고: 브랜드 hue {h:.0f}°가 --{n}({sh:.0f}°)와 {d:.0f}° 차이 — 상태색과 헷갈릴 수 있다(버튼·배지 렌더 확인)")
    if not ok:
        print("단계 계약 실패 — theme.css를 쓰지 않는다")
    return ok


def render(name, cmd, light, dark, seq, mapseq, nl, nd):
    row = lambda d: "  " + " ".join(f"--{k}: {v};" for k, v in d.items())
    seqrow = lambda s: "  " + " ".join(f"--seq-{i + 1}: {v};" for i, v in enumerate(s))
    dark_body = "\n".join([row(dark), seqrow(list(reversed(seq)))] + ([row(nd)] if nd else []))
    ind = lambda s: "\n".join("  " + x for x in s.splitlines())
    return f"""/* {name} — scripts/tokens/ramp.py {cmd} 초안. vault/tokens.css 다음에 불러온다.
   범주 1번(--series-1)은 기본 틸 그대로 — 바꾸려면 vault/themes/README.md의 검증기 절차.
   확인: scripts/tokens/check_theme.py {name} */
:root {{
{row(light)}
{seqrow(seq)}
  {" ".join(f"--map-seq-{i + 1}: {v};" for i, v in enumerate(mapseq))}
{row(nl) if nl else "  /* 바탕 온도: 기본 무채색 유지 (--neutral로 바꿀 수 있음) */"}
}}

@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
{ind(dark_body)}
  }}
}}
:root[data-theme="dark"] {{
{dark_body}
}}
"""


if __name__ == "__main__":
    main()
