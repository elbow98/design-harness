#!/usr/bin/env bash
# 하네스 검사 도구 회귀 테스트 + 저장소 전체 게이트.
# 사용: scripts/test.sh [--quick]
#   1) 검사 도구 자체: scripts/tests/의 견본으로 오탐(ok-*)과 미탐(bad-*)을 함께 확인한다.
#   2) 저장소 게이트(--quick이면 건너뜀): 토큰 내보내기 최신 여부 · 테마 검사 · 카탈로그·산출물 드리프트·slop ·
#      vault 시각 회귀 기준선 · outputs/ 폴더별 verify.sh(scripts/tests/verify-skip.txt에 이유와 함께 적은 지난 기록은 SKIP)
# 하나라도 기대와 다르면 exit 1. 렌더 결과는 $TMPDIR/harness-test/ 아래.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
S="$ROOT/scripts"
T="$S/tests"
tmpd="${TMPDIR:-/tmp}"; work="${tmpd%/}/harness-test"; mkdir -p "$work"
quick=0; [[ "${1:-}" == "--quick" ]] && quick=1
pass=0; fail=0; skipped=0; failed=()

expect() {  # expect <이름> <기대 exit> <출력에 있어야 할 글자(없으면 "")> <명령...>
  local name="$1" want="$2" grep_for="$3"; shift 3
  local log="$work/$(echo "$name" | tr -c '[:alnum:]가-힣' '_').log"
  "$@" >"$log" 2>&1; local rc=$?
  if [[ $rc -eq $want ]] && { [[ -z "$grep_for" ]] || grep -q -- "$grep_for" "$log"; }; then
    pass=$((pass + 1)); echo "  PASS  $name"
  else
    fail=$((fail + 1)); failed+=("$name"); echo "  FAIL  $name (exit $rc, 기대 $want${grep_for:+, 출력에 '$grep_for'}) → $log"
    tail -5 "$log" | sed 's/^/        /'
  fi
}

echo "[검사 도구 — check.sh]"
expect "check: 없는 경로는 exit 2" 2 "없는 경로" "$S/check.sh" "$T/no-such-dir"
expect "check: 없는 경로가 섞여도 exit 2" 2 "없는 경로" "$S/check.sh" templates "$T/no-such-file.html"
expect "check: 하드코딩 색은 잡는다" 1 "색 하드코딩" "$S/check.sh" "$T/check/bad-hardcoded-color.html"
expect "check: 토큰만 쓴 파일은 통과" 0 "" "$S/check.sh" templates

echo "[검사 도구 — slop.sh]"
expect "slop: 다크 accent-soft 위 본문색은 회색 글자가 아님" 0 "" "$S/slop.sh" --no-advisory "$T/slop/ok-text-on-accent-soft.html"
expect "slop: 진한 색 바탕 위 회색 글자는 잡는다" 1 "gray-on-color" "$S/slop.sh" --no-advisory "$T/slop/bad-gray-on-color.html"
expect "slop: 닫힌 details 안 표는 가려진 글자가 아님" 0 "" "$S/slop.sh" --no-advisory "$T/slop/ok-closed-details-table.html"
expect "slop: 보이는 글자가 실제로 가려지면 잡는다" 1 "text-occlusion" "$S/slop.sh" --no-advisory "$T/slop/bad-text-occlusion.html"

if [[ $quick -eq 0 ]]; then
  echo "[저장소 — 토큰·테마]"
  expect "build.py 기본 내보내기 실행" 0 "" python3 "$S/tokens/build.py"
  expect "build.py --theme _sample-warm 실행" 0 "" python3 "$S/tokens/build.py" --theme _sample-warm
  expect "vault/export가 tokens.css와 같음(재생성해도 변화 없음)" 0 "" git diff --exit-code --stat -- vault/export
  for th in default _sample-warm; do
    expect "check_theme $th" 0 "모든 검사 통과" python3 "$S/tokens/check_theme.py" "$th"
  done

  echo "[저장소 — 카탈로그·템플릿]"
  expect "check: vault·templates·outputs" 0 "" "$S/check.sh" vault templates outputs
  expect "slop: vault·templates" 0 "" "$S/slop.sh" --no-advisory vault templates
  for f in components charts; do
    expect "diff compare vault/$f.html" 0 "OK: 기준선과 같음" "$S/diff.sh" compare "vault/$f.html"
  done

  echo "[저장소 — outputs/ verify.sh]"
  for d in outputs/*/; do
    d="${d%/}"; [[ "$(basename "$d")" == _* ]] && continue
    why="$(grep -v '^#' "$T/verify-skip.txt" | awk -v n="$(basename "$d")" '$1 == n { $1 = ""; sub(/^ +/, ""); print }')"
    if [[ -n "$why" ]]; then skipped=$((skipped + 1)); echo "  SKIP  verify $d — $why"; continue; fi
    expect "verify $d" 0 "전체 통과" "$S/verify.sh" "$d" "$work/shots/$(basename "$d")"
  done
fi

echo
echo "통과 $pass · 실패 $fail$([[ $skipped -gt 0 ]] && echo " · 건너뜀 $skipped")"
for n in "${failed[@]+"${failed[@]}"}"; do echo "  - $n"; done
exit $(( fail > 0 ))
