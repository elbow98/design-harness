#!/usr/bin/env bash
# 통합 검증: check.sh(토큰 드리프트) → slop.sh(AI 티) → shot.sh(렌더·넘침·콘솔·접근성) 순서로 돌리고 요약 표를 낸다.
# 사용: scripts/verify.sh [--no-a11y] <폴더|html> [스크린샷 출력 폴더]
#   폴더면 그 안의 index.html(없으면 첫 .html)을 렌더한다. 하나라도 실패하면 exit 1.
#   마지막 줄은 스크린샷 폴더 경로(critique 스킬이 이어 받는다).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/scripts"
shot_opts=(); args=()
for a in "$@"; do [[ "$a" == "--no-a11y" ]] && shot_opts+=("$a") || args+=("$a"); done
[[ ${#args[@]} -ge 1 ]] || { echo "사용법: scripts/verify.sh [--no-a11y] <폴더|html> [스크린샷 출력 폴더]" >&2; exit 2; }
target="${args[0]}"
if [[ -d "$target" ]]; then
  page="$target/index.html"
  [[ -f "$page" ]] || page="$(find "$target" -maxdepth 1 -name '*.html' | sort | head -1)"
elif [[ -f "$target" ]]; then
  page="$target"
else
  echo "없는 경로: $target" >&2; exit 2
fi
slug="$(basename "${page%.html}")"; [[ "$slug" == index ]] && slug="$(basename "$(dirname "$page")")"
tmpd="${TMPDIR:-/tmp}"; out="${args[1]:-${tmpd%/}/harness-shots/$slug}"

results=()
run() {  # run <이름> <명령...>
  local name="$1"; shift
  echo; echo "━━ $name ━━"
  local log; log="$(mktemp)"
  "$@" 2>&1 | tee "$log"
  local rc=${PIPESTATUS[0]}
  local last; last="$(grep -v '^[[:space:]]*$' "$log" | grep -v '^→ ' | tail -1)"
  rm -f "$log"
  results+=("$name|$([[ $rc -eq 0 ]] && echo 통과 || echo 실패)|${last:0:90}")
  return $rc
}

fail=0
run "check 토큰 드리프트" "$S/check.sh" "$target" || fail=1
run "slop AI 티" "$S/slop.sh" "$target" || fail=1
if [[ -n "$page" ]]; then
  run "shot 렌더·접근성" "$S/shot.sh" ${shot_opts[@]+"${shot_opts[@]}"} "$page" "$out" || fail=1
else
  results+=("shot 렌더·접근성|건너뜀|렌더할 .html 없음")
fi

echo; echo "━━ 요약 ━━"
echo "| 검사 | 결과 | 요약 |"
echo "|---|---|---|"
for r in "${results[@]}"; do IFS='|' read -r n s l <<<"$r"; echo "| $n | $s | $l |"; done
echo "$([[ $fail -eq 0 ]] && echo '전체 통과' || echo '실패 있음')"
echo "$out"
exit $fail
