#!/usr/bin/env python3
"""테마 대비·구조 검사. 실패가 하나라도 있으면 exit 1.

사용: scripts/tokens/check_theme.py <테마 이름>      (vault/themes/<이름>/theme.css)
      scripts/tokens/check_theme.py default          (tokens.css 기본값 그대로)

검사
  구조  테마가 슬롯 밖 토큰을 바꾸지 않았나 · 라이트에서 바꾼 색 슬롯은 다크 짝도 있나 ·
        다크 블록 두 벌(@media / data-theme)이 같나 · 지도 색(map-*)을 다크에서 재정의하지 않았나
  대비  라이트·다크 각각 WCAG 2.x 비율(통과 기준) + APCA Lc(참고). 아래 PAIRS 표
  램프  seq-1…9 밝기 단조(라이트는 점점 진하게, 다크는 점점 밝게) · map-seq-1…5 단조
  범주  dataviz 검증기(validate_palette.js)로 series-1…8 인접 쌍 + 1–3 전쌍, 라이트·다크
"""
import sys
sys.dont_write_bytecode = True  # scripts/tokens/에 __pycache__를 남기지 않는다

import glob
import os
import subprocess
import sys

import tokencss as tc
from colorlib import apca, contrast, srgb_to_oklab

# (글자/앞, 바탕/뒤, 최소 WCAG 비율, 무엇) — 기준: 본문 4.5, UI·큰 글자·차트 표시 3.0, 0이면 참고만
PAIRS = [
    ("text", "bg", 4.5, "본문"),
    ("text", "surface", 4.5, "본문(패널)"),
    ("text", "surface-2", 4.5, "본문(hover·코드)"),
    ("text-2", "bg", 4.5, "보조 설명"),
    ("text-2", "surface", 4.5, "보조 설명(패널)"),
    ("text-3", "surface", 3.0, "메타·placeholder"),
    ("accent", "bg", 4.5, "링크"),
    ("accent", "surface", 4.5, "링크(패널)"),
    ("accent", "accent-soft", 4.5, "강조 배지"),
    ("text", "accent-soft", 4.5, "선택된 행·활성 토글"),
    ("on-accent", "accent", 4.5, "주 버튼 글자"),
    ("on-accent", "accent-hover", 4.5, "주 버튼 hover 글자"),
    ("focus", "bg", 3.0, "포커스 링"),
    ("focus", "surface", 3.0, "포커스 링(패널)"),
    ("text-3", "bg", 0, "메타 12px(.meta) — 기본값도 3.4:1, Design.md §2 '12px 이하 본문 금지'와 충돌"),
    ("positive", "surface", 4.5, "상태 글자(성공)"),
    ("negative", "surface", 4.5, "상태 글자(에러)"),
    ("warning", "surface", 4.5, "상태 글자(주의)"),
    ("warning", "surface-2", 0, "주의 배지 — 기본값도 4.45:1"),
    ("series-1", "surface", 3.0, "차트 1번 계열"),
    ("border-strong", "surface", 0, "입력창 테두리(참고: WCAG 1.4.11은 3:1)"),
]


def find_validator():
    env = os.environ.get("DATAVIZ_VALIDATOR")
    if env:
        return env if os.path.isfile(env) else None
    cands = glob.glob(os.path.expanduser("~/.claude/skills/dataviz/scripts/validate_palette.js"))
    cands += glob.glob("/private/tmp/claude-*/bundled-skills/*/*/dataviz/scripts/validate_palette.js")
    cands += glob.glob("/tmp/claude-*/bundled-skills/*/*/dataviz/scripts/validate_palette.js")
    return max(cands, key=os.path.getmtime) if cands else None


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    name = sys.argv[1]
    base = tc.parse(tc.TOKENS)
    tpath = tc.THEMES / name / "theme.css"
    if not tpath.is_file():
        sys.exit(f"테마 파일 없음: {tpath}")
    theme = tc.parse(tpath)
    fails = []
    warn = []

    print(f"테마 {name} — {tpath.relative_to(tc.ROOT)}\n")
    print("[구조]")
    bad = sorted(n for n in set(theme["light"]) | set(theme["dark"]) | set(theme["dark_media"]) if n not in tc.ALLOWED)
    for n in bad:
        fails.append(f"--{n}: 테마가 바꿀 수 없는 토큰({tc.locked_reason(n)})")
    mism = tc.dark_mismatch(theme)
    if mism:
        fails.append("다크 블록 두 벌(@media prefers-color-scheme / [data-theme=dark])이 다름: " + ", ".join(mism))
    for n in theme["light"]:
        if n in tc.ALLOWED and n not in tc.LIGHT_ONLY and n not in tc.MODELESS and n not in theme["dark"]:
            fails.append(f"--{n}: 라이트만 바꾸고 다크 짝이 없음")
    for n in theme["dark"]:
        if n in tc.LIGHT_ONLY:
            fails.append(f"--{n}: 지도 위 색은 다크에서 재정의하지 않는다(Design.md §9)")
    touched = sorted(set(theme["light"]) | set(theme["dark"]))
    print(f"  바꾼 슬롯 {len(touched)}개: {', '.join(touched) if touched else '(없음 — 기본값)'}")
    for f in fails:
        print(f"  FAIL {f}")

    merged = tc.merge(base, theme)
    modes = {m: tc.mode_values(merged, m) for m in ("light", "dark")}
    for mode, vals in modes.items():
        print(f"\n[대비 — {'라이트' if mode == 'light' else '다크'}]   WCAG(기준)   APCA Lc(참고)")
        for fg, bg, need, what in PAIRS:
            if fg not in vals or bg not in vals:
                continue
            a, b = tc.resolve_color(vals, fg), tc.resolve_color(vals, bg)
            r, lc = contrast(a, b), apca(a, b)
            if need == 0:
                mark = "info"
            elif r >= need:
                mark = "PASS"
            else:
                mark = "FAIL"
                fails.append(f"{mode}: {fg} on {bg} {r:.2f}:1 < {need}:1 ({what})")
            print(f"  {mark:4}  {fg:>13} on {bg:<12} {r:5.2f}:1 (≥{need:g})  Lc {lc:6.1f}   {what}")

    print("\n[순차 램프 — 밝기 단조]")
    for mode, vals in modes.items():
        for prefix, count, ramp_mode in (("seq-", 9, mode), ("map-seq-", 5, "light")):
            if ramp_mode != mode:
                continue
            keys = [f"{prefix}{i}" for i in range(1, count + 1)]
            if not all(k in vals for k in keys):
                continue
            Ls = [srgb_to_oklab(tc.resolve_color(vals, k))[0] for k in keys]
            steps = [b - a for a, b in zip(Ls, Ls[1:])]
            # 라이트: 작은 값 = 옅게 → 진하게(L 감소). 다크: 작은 값 = 배경에 가까운 어두운 단계(L 증가)
            want_down = mode == "light"
            ok = all((s < 0) if want_down else (s > 0) for s in steps)
            minstep = min(abs(s) for s in steps)
            mark = "PASS" if ok else "FAIL"
            if not ok:
                fails.append(f"{mode}: {prefix}1…{count} 밝기가 단조가 아님")
            elif minstep < 0.03:
                warn.append(f"{mode}: {prefix} 단계 간 밝기 차 최소 {minstep:.3f} (<0.03, 구분 어려움)")
            print(f"  {mark}  {mode:5} {prefix}1…{count}  L {Ls[0]:.2f} → {Ls[-1]:.2f}, 최소 간격 {minstep:.3f}")

    print("\n[범주 팔레트 — dataviz 검증기]")
    v = find_validator()
    if not v:
        warn.append("dataviz 검증기를 못 찾음 — DATAVIZ_VALIDATOR=<validate_palette.js 경로>로 지정")
        print("  SKIP  validate_palette.js 없음")
    else:
        print(f"  검증기: {v}")
        for mode, vals in modes.items():
            pal = [tc.hex_of(vals, f"series-{i}") for i in range(1, 9)]
            surf = tc.hex_of(vals, "surface")
            for label, args in (("인접 쌍 8색", [",".join(pal)]), ("1–3 전쌍", [",".join(pal[:3]), "--pairs", "all"])):
                p = subprocess.run(["node", v, *args, "--mode", mode, "--surface", surf], capture_output=True, text=True)
                verdict = "PASS" if p.returncode == 0 else "FAIL"
                if p.returncode != 0:
                    fails.append(f"{mode}: dataviz 검증기 {label} 실패")
                print(f"  {verdict}  {mode:5} {label}")
                for line in p.stdout.splitlines():
                    if line.strip().startswith("[") and ("FAIL" in line or "WARN" in line or "CVD" in line):
                        print(f"          {line.strip()}")

    print()
    for w in warn:
        print(f"WARN  {w}")
    if fails:
        print(f"\n실패 {len(fails)}건:")
        for f in fails:
            print(f"  - {f}")
        sys.exit(1)
    print("모든 검사 통과")


if __name__ == "__main__":
    main()
