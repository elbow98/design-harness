#!/usr/bin/env bash
# 로컬 미리보기: 하네스 루트를 http://localhost:${PORT:-4321} 로 서빙
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-4321}"
echo "http://localhost:$PORT/outputs/   ·   http://localhost:$PORT/vault/components.html"
exec python3 -m http.server "$PORT" --directory "$ROOT"
