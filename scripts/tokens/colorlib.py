"""색 계산 공용 모듈 (표준 라이브러리만). build.py · check_theme.py · ramp.py가 같이 쓴다.

- parse_color: #rgb / #rrggbb / #rrggbbaa / rgb(r g b / a) / rgb(r, g, b) → (r, g, b, a), 0–1 실수
- OKLab · OKLCH 변환, color-mix(in oklab, …) 계산
- WCAG 2.x 대비 비율, APCA Lc (APCA-W3 0.0.98G-4g 상수)
"""
import math
import re

_HEX = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
_RGB = re.compile(r"^rgba?\(\s*([^)]*)\)$")


def parse_color(s):
    """CSS 색 문자열 → (r, g, b, a) 0–1. 못 읽으면 None."""
    s = s.strip()
    m = _HEX.match(s)
    if m:
        h = m.group(1)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
        return (r, g, b, a)
    m = _RGB.match(s)
    if m:
        body = m.group(1).replace(",", " ").replace("/", " / ")
        parts = body.split()
        alpha = 1.0
        if "/" in parts:
            i = parts.index("/")
            alpha = _num(parts[i + 1])
            parts = parts[:i]
        elif len(parts) == 4:
            alpha = _num(parts[3])
            parts = parts[:3]
        if len(parts) != 3:
            return None
        rgb = [(_num(p) / 100 if p.endswith("%") else _num(p) / 255) for p in parts]
        return (*rgb, alpha)
    return None


def _num(p):
    return float(p.rstrip("%"))


def to_hex(rgb):
    r, g, b = (max(0, min(255, round(c * 255))) for c in rgb[:3])
    return f"#{r:02X}{g:02X}{b:02X}"


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def srgb_to_oklab(rgb):
    r, g, b = (_lin(c) for c in rgb[:3])
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklab_to_srgb(lab, clip=True):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    out = tuple(_gam(c) if c >= 0 else -_gam(-c) for c in rgb)
    return tuple(max(0.0, min(1.0, c)) for c in out) if clip else out


def oklch(rgb):
    L, a, b = srgb_to_oklab(rgb)
    return (L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360)


def oklch_to_srgb(L, C, h):
    """OKLCH → sRGB. 범위를 벗어나면 같은 L·h에서 C를 줄여 안으로 넣는다."""
    lo, hi = 0.0, C
    for _ in range(40):
        rgb = oklab_to_srgb((L, hi * math.cos(math.radians(h)), hi * math.sin(math.radians(h))), clip=False)
        if all(-1e-6 <= c <= 1 + 1e-6 for c in rgb):
            break
        mid = (lo + hi) / 2
        rgb = oklab_to_srgb((L, mid * math.cos(math.radians(h)), mid * math.sin(math.radians(h))), clip=False)
        if all(-1e-6 <= c <= 1 + 1e-6 for c in rgb):
            lo = mid
        else:
            hi = mid
    return oklab_to_srgb((L, hi * math.cos(math.radians(h)), hi * math.sin(math.radians(h))))


def mix_oklab(c1, c2, p1):
    """color-mix(in oklab, c1 p1, c2) — p1은 0–1. 알파 1 가정."""
    a, b = srgb_to_oklab(c1), srgb_to_oklab(c2)
    return oklab_to_srgb(tuple(x * p1 + y * (1 - p1) for x, y in zip(a, b)))


def luminance(rgb):
    r, g, b = (_lin(c) for c in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg):
    """WCAG 2.x 대비 비율."""
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def apca(txt, bg):
    """APCA Lc (APCA-W3 0.0.98G-4g). 양수 = 밝은 바탕 위 어두운 글자, 음수 = 반대. 참고용."""
    def y(rgb):
        r, g, b = (c ** 2.4 for c in rgb[:3])
        v = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        return v if v > 0.022 else v + (0.022 - v) ** 1.414
    yt, yb = y(txt), y(bg)
    if abs(yb - yt) < 0.0005:
        return 0.0
    if yb > yt:
        sapc = (yb ** 0.56 - yt ** 0.57) * 1.14
        return 0.0 if sapc < 0.1 else (sapc - 0.027) * 100
    sapc = (yb ** 0.65 - yt ** 0.62) * 1.14
    return 0.0 if sapc > -0.1 else (sapc + 0.027) * 100
