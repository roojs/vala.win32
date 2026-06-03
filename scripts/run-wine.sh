#!/usr/bin/env bash
# Run a cross-built .exe under Wine with MinGW runtime DLLs on the search path.
#
# Usage:
#   ./scripts/run-wine.sh build/ergonomic-button-demo.exe
#   ./scripts/run-wine.sh build/hello-window.exe

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINGW_BIN="${MINGW_LIBDIR:-$ROOT/mingw-libs}/mingw64/bin"
EXE="${1:-}"

if [[ -z "$EXE" ]]; then
	echo "usage: $0 path/to/app.exe" >&2
	exit 1
fi

if [[ ! -f "$EXE" ]]; then
	echo "run-wine: not found: $EXE" >&2
	exit 1
fi

# Track B copies DLLs into build/; WINEPATH still helps if you run from elsewhere.
if [[ -d "$MINGW_BIN" ]]; then
	export WINEPATH="${MINGW_BIN}${WINEPATH:+:$WINEPATH}"
fi

WINE="${WINE:-wine}"
if command -v wine64 >/dev/null 2>&1; then
	WINE=wine64
fi

exec "$WINE" "$EXE"
