"""tokens.css · theme.css 파서와 테마 슬롯 정의. build.py · check_theme.py가 같이 쓴다.

읽는 블록 (미디어 쿼리 밖의 선택자는 정확히 일치해야 한다):
  :root                                                     → light (여러 블록이면 순서대로 합침)
  :root[data-theme="dark"]                                  → dark
  @media (prefers-color-scheme: dark) :root:not([data-theme="light"]) → dark_media (dark와 같아야 함)
  @media (max-width: 640px) :root                           → mobile
"""
import re
from pathlib import Path

from colorlib import mix_oklab, parse_color, to_hex

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "vault" / "tokens.css"
THEMES = ROOT / "vault" / "themes"
EXPORT = ROOT / "vault" / "export"

SEL_LIGHT = ":root"
SEL_DARK = ':root[data-theme="dark"]'
SEL_DARK_MEDIA = ':root:not([data-theme="light"])'
MQ_DARK = "(prefers-color-scheme: dark)"
MQ_MOBILE = "(max-width: 640px)"

# ---- 테마가 바꿀 수 있는 슬롯 (vault/themes/README.md와 같이 고친다) ----
SLOTS = {
    "brand": ["accent", "accent-hover", "accent-soft", "on-accent", "focus"],
    "series": ["series-1"],
    "sequential": [f"seq-{i}" for i in range(1, 10)] + [f"map-seq-{i}" for i in range(1, 6)],
    "font": ["font-sans", "font-display"],
    "radius": ["r-sm", "r-md", "r-lg"],
    "neutral": ["bg", "surface", "surface-2", "border", "border-strong", "text", "text-2", "text-3",
                "map-ink", "map-no-data"],
}
ALLOWED = {n for names in SLOTS.values() for n in names}
# 라이트 값 고정(다크에서 재정의하지 않는) 슬롯 — Design.md §9 지도 위 색
LIGHT_ONLY = {n for n in ALLOWED if n.startswith("map-")}
# 테마와 무관한 슬롯: 다크 짝을 요구하지 않는다
MODELESS = {"font-sans", "r-sm", "r-md", "r-lg"}
# 명시적 잠금(문서용). ALLOWED 밖은 전부 잠금이지만 이유를 보여 주려고 따로 둔다.
LOCKED_REASON = [
    (("positive", "negative", "warning", "positive-soft", "negative-soft", "warning-soft"), "상태색"),
    (("up", "down"), "시장 방향(한국식)"),
    (("series-",), "범주 팔레트 2~8번(1번만 브랜드)"),
    (("div-",), "발산 램프(한국식 상승 방향)"),
]


def locked_reason(name):
    for names, why in LOCKED_REASON:
        if any(name == n or (n.endswith("-") and name.startswith(n)) for n in names):
            return why
    return "슬롯 목록에 없음"


def _strip_comments(s):
    return re.sub(r"/\*.*?\*/", "", s, flags=re.S)


def _match_brace(s, i):
    """s[i] == '{' 일 때 짝 '}'의 위치."""
    depth = 0
    quote = None
    for j in range(i, len(s)):
        c = s[j]
        if quote:
            if c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j
    raise ValueError("중괄호 짝이 맞지 않음")


def _rules(css, media=None):
    """(media, selector, body) 를 순서대로 낸다. @media는 한 단계만 들어간다."""
    i = 0
    while i < len(css):
        brace = css.find("{", i)
        if brace < 0:
            return
        prelude = css[i:brace]
        # 앞의 ; 로 끝난 문장(@import 등)은 버린다
        if ";" in prelude:
            prelude = prelude[prelude.rfind(";") + 1:]
        prelude = " ".join(prelude.split())
        end = _match_brace(css, brace)
        body = css[brace + 1:end]
        if prelude.startswith("@media"):
            yield from _rules(body, prelude[len("@media"):].strip())
        else:
            yield (media, prelude, body)
        i = end + 1


def _decls(body):
    out = {}
    for part in body.split(";"):
        if ":" not in part:
            continue
        k, v = part.split(":", 1)
        k = k.strip()
        if k.startswith("--"):
            out[k[2:]] = " ".join(v.split())
    return out


def parse(path):
    css = _strip_comments(Path(path).read_text(encoding="utf-8"))
    res = {"light": {}, "dark": {}, "dark_media": {}, "mobile": {}}
    for media, sel, body in _rules(css):
        sels = [s.strip() for s in sel.split(",")]
        d = _decls(body)
        if media is None and SEL_LIGHT in sels:
            res["light"].update(d)
        if media is None and SEL_DARK in sels:
            res["dark"].update(d)
        if media == MQ_DARK and SEL_DARK_MEDIA in sels:
            res["dark_media"].update(d)
        if media == MQ_MOBILE and SEL_LIGHT in sels:
            res["mobile"].update(d)
    return res


def dark_mismatch(p):
    """다크 블록 두 벌(미디어 쿼리 / data-theme)이 다른 토큰 이름 목록."""
    a, b = p["dark"], p["dark_media"]
    return sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))


def merge(base, theme):
    """base(tokens.css) 위에 theme 오버라이드를 얹은 light/dark/mobile 값. 순서는 base 순서 + 새 토큰."""
    out = {}
    for mode in ("light", "dark", "mobile"):
        d = dict(base[mode])
        if theme:
            for k, v in theme[mode].items():
                d[k] = v
        out[mode] = d
    return out


def mode_values(merged, mode):
    """mode의 실효 값: light 위에 mode 블록을 얹는다(다크 블록에 없는 토큰은 light 값)."""
    d = dict(merged["light"])
    if mode != "light":
        d.update(merged[mode])
    return d


_VAR = re.compile(r"var\(--([\w-]+)\)")
_MIX = re.compile(r"^color-mix\(in oklab,\s*(.+?)\s+([\d.]+)%,\s*(.+)\)$")


def resolve(values, name, depth=0):
    """var()를 끝까지 풀어 문자열로."""
    v = values[name]
    if depth > 20:
        raise ValueError(f"var 순환: --{name}")
    return _VAR.sub(lambda m: resolve(values, m.group(1), depth + 1), v)


def resolve_color(values, name):
    """색 토큰을 (r, g, b, a)로. color-mix(in oklab, X p%, Y)도 계산. 색이 아니면 None."""
    v = resolve(values, name)
    c = parse_color(v)
    if c:
        return c
    m = _MIX.match(v)
    if m:
        c1, p, c2 = parse_color(m.group(1)), float(m.group(2)) / 100, parse_color(m.group(3))
        if c1 and c2:
            return (*mix_oklab(c1, c2, p), 1.0)
    return None


def hex_of(values, name):
    c = resolve_color(values, name)
    return to_hex(c) if c else None
