# 테마 레이어

브랜드가 생기면(예: 스터디카페 인수) 하네스 구조는 그대로 두고 **브랜드 슬롯만** 갈아 끼운다.
테마 하나 = 폴더 하나: `vault/themes/<이름>/theme.css`. `vault/tokens.css` **다음에** 불러오는 오버라이드다.

```html
<link rel="stylesheet" href="tokens.css">
<link rel="stylesheet" href="themes/<이름>/theme.css">
```

| 폴더 | 내용 |
|---|---|
| `default/` | 기준 테마(UI 코발트, 차트·램프 틸). 빈 오버라이드이고, 슬롯 목록과 지금 값을 주석으로 담았다. 새 테마는 이걸 복사해서 시작해도 된다 |
| `_sample-warm/` | 예시(이름 앞 `_` = 예시). 오렌지-브라운 seed `B5541C` + 따뜻한 무채색 바탕. `ramp.py`로 만들고 `check_theme.py`를 통과했다 |

## 바꿀 수 있는 슬롯

원본 목록은 `scripts/tokens/tokencss.py`의 `SLOTS`다. 이 표와 그 목록은 같이 고친다.

| 묶음 | 토큰 | 바꿀 때 지킬 것 |
|---|---|---|
| 브랜드 | `--accent` `--accent-hover` `--accent-soft` `--on-accent` `--focus` | accent는 bg·surface 위 4.5:1(링크), `--on-accent`는 accent·accent-hover 위 4.5:1(주 버튼), accent는 accent-soft 위 4.5:1(강조 배지), 본문 글자는 accent-soft 위 4.5:1(선택된 행). 포커스 링 3:1 |
| 범주 1번 | `--series-1` | surface 위 3:1, **dataviz 검증기 재실행**(아래). 통과 못 하면 틸 그대로 두고 브랜드색은 UI에만 쓴다 |
| 순차 램프 | `--seq-1`…`--seq-9`, `--map-seq-1`…`--map-seq-5` | 라이트는 seq-1(작음)이 가장 옅고 갈수록 진하게, 다크는 반대(같은 9색을 뒤집음). `map-seq`는 라이트 seq 1·3·5·7·9이고 **다크 블록에 넣지 않는다**(Design.md §9 지도 위 색) |
| 바탕 온도 | `--bg` `--surface` `--surface-2` `--border` `--border-strong` `--text` `--text-2` `--text-3` `--map-ink` `--map-no-data` | 무채색 범위 안에서만(OKLCH 채도 0.005~0.012). 본문·보조 글자 4.5:1, text-3 3:1 |
| 글꼴 | `--font-sans` | 본문은 Pretendard를 유지하는 게 기본. 제목 전용 글꼴이 필요하면 `--font-display` 신설을 Design.md에 먼저 제안한다(아직 토큰 없음) |
| 반경 성격 | `--r-sm` `--r-md` `--r-lg` | 셋을 같은 비율로(예: 4·6·8 각진 / 8·12·16 둥근). `--r-full`은 고정 |

라이트에서 바꾼 색 슬롯은 다크 짝이 반드시 있어야 하고, 다크 블록 두 벌(`@media (prefers-color-scheme: dark) :root:not([data-theme="light"])`와 `:root[data-theme="dark"]`)은 같은 값이어야 한다. 글꼴·반경은 모드와 무관하다.

## 바꿀 수 없는 것

테마는 의미가 정해진 색을 건드리지 않는다. `check_theme.py`와 `build.py --theme`이 거부한다.

- 상태색 `--positive` `--negative` `--warning`과 `--*-soft`(soft는 표면색에 섞으므로 바탕 온도를 바꾸면 알아서 따라간다)
- 시장 방향 `--up` `--down`(한국식, Design.md §2)
- 발산 램프 `--div-*`(한국식 상승 방향, Design.md §9)
- 범주 팔레트 2~8번(`--series-2`…`--series-8`), 간격·타입 스케일·그림자·움직임·z-index·앱 셸 치수

## 만들기 → 검사 → 내보내기

```bash
scripts/tokens/ramp.py "#C2410C"                                   # 12단계 사다리 + 슬롯 제안 (출력만)
scripts/tokens/ramp.py "#C2410C" --neutral 0.008 --neutral-hue 75 --css 브랜드  # theme.css 초안 (있으면 덮어쓰지 않음)
scripts/tokens/check_theme.py 브랜드                               # 대비·구조·램프·범주 검사, 실패 시 exit 1
scripts/tokens/build.py --theme 브랜드                             # vault/export/브랜드/ 에 DTCG·Tailwind·DESIGN.md
```

- `ramp.py`는 출력 끝에 **단계 계약 4줄**을 라이트·다크 각각 찍는다: ① 글자 단계(11) on 바탕 단계(1) ≥4.5:1 ② 고대비 글자(12) on 2단계 ≥7:1 ③ `--on-accent` on `--accent` ≥4.5:1 ④ 입력창 테두리로 쓸 수 있는 첫 단계(1단계 대비 ≥3:1)가 몇 단계인지. 하나라도 실패하면 exit 1이고 `--css`도 쓰지 않는다. 근거: KRDS "단계 차 = 대비" 원리, Radix 11·12단계 글자 보증. 다크 사다리는 L 0.17→0.93으로 따로 만든다.
- 브랜드 hue가 `--positive`/`--negative`/`--warning`의 hue와 30° 안이면 경고 한 줄을 낸다(실패는 아님). 예: 오렌지 `B5541C`는 negative 20°·warning 25°, 초록 `2E7D32`는 positive 8° 차이.
- `ramp.py`의 순차 램프는 지금 tokens.css seq의 **밝기를 그대로 쓰고 색상 각도만 바꾼다**. 그래서 단계 간격은 검증된 값과 같다.
- 바탕 온도는 seed 각도를 따르면 붉은 계열 seed에서 바탕이 분홍으로 뜬다. `--neutral-hue 70~85`(따뜻한 회색)로 각도를 따로 준다.
- `check_theme.py`는 라이트·다크 각각 WCAG 2.x 비율(통과 기준)과 APCA Lc(참고, 음수 = 어두운 바탕 위 밝은 글자)를 보여 준다. `info` 줄은 통과 기준이 없는 참고값이다.

## 범주 1번 검증기 (dataviz)

검증기는 Claude Code에 들어 있는 `dataviz` 스킬의 `scripts/validate_palette.js`다. 설치된 파일이 아니라 Claude Code 버전마다 경로가 바뀐다:
`/private/tmp/claude-<uid>/bundled-skills/<버전>/<해시>/dataviz/scripts/validate_palette.js`
(2026-10-14 기준 `…/bundled-skills/2.1.296/897a97d704b8521a7b0103f414f6aa0f/…`). 세션에서 `dataviz` 스킬을 한 번 불러야 이 폴더가 생긴다.

`check_theme.py`가 이 경로를 glob으로 찾아 자동으로 돌린다(가장 최근 것). 못 찾으면 SKIP하고 경고하며, `DATAVIZ_VALIDATOR=<경로>`로 지정할 수 있다. 손으로 돌릴 때:

```bash
V=$(ls -t /private/tmp/claude-*/bundled-skills/*/*/dataviz/scripts/validate_palette.js | head -1)
# 8색 인접 쌍 (기본) — 라이트·다크 각각, 그 모드의 surface로
node "$V" "<새 series-1>,#9B2C4E,#EDA100,#E87BA4,#4A3AA7,#EB6834,#2A78D6,#008300" --mode light --surface "#FFFFFF"
node "$V" "<새 다크 series-1>,#B03A62,#C98500,#D55181,#9085E9,#D95926,#3987E5,#008300" --mode dark --surface "#1A1A19"
# 1–3 전쌍 (산점도·지도·작은 차트 여러 개는 3계열까지 — Design.md §9)
node "$V" "<새 series-1>,#9B2C4E,#EDA100" --mode light --pairs all --surface "#FFFFFF"
```

exit 1이면 실패다. `WARN Contrast vs surface`(골드·마젠타 3:1 미만)는 기본 팔레트부터 있는 경고로, 직접 라벨이나 표 보기로 보완한다(Design.md §9).

### 오렌지·브라운 계열은 series-1에 못 넣는다 (2026-10-14 확인)

`_sample-warm`을 만들며 `#A0522D` `#B3521A` `#8C5A2B`를 series-1로 넣어 봤고 셋 다 실패했다. 6번 오렌지(`#EB6834`)와 정상 시각 ΔE 12.3(하한 15), 8번 그린(`#008300`)과 적록 색각이상 ΔE 1.4~3.2로 겹친다. 그래서 따뜻한 브랜드는 차트 1번을 틸로 두고 UI 브랜드색과 차트 색을 분리한다. 빨강·주황 계열 브랜드는 `--negative`(삭제·에러)·`--up`(상승)과도 색이 가깝다. 위험한 행동 버튼은 글자·테두리로 구분되는지 렌더해서 확인한다.

## 렌더 확인

```bash
S=$(mktemp -d); cp vault/tokens.css vault/themes/<이름>/theme.css "$S"/
sed 's#<link rel="stylesheet" href="tokens.css">#&\n<link rel="stylesheet" href="theme.css">#' vault/components.html > "$S/index.html"
scripts/shot.sh "$S/index.html" "$S/shots"
```

기본 카탈로그부터 접근성 실패가 2건 있다(`.meta` text-3 12px 3.4:1, 주의 배지 surface-2 위 4.45:1). 테마 렌더에서 같은 두 건만 나오면 테마 탓이 아니다.
