#!/usr/bin/env bash
# Quick smoke: ldd + short run of gtk-webview2-hello (MSYS2 UCRT64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BW="${ROOT}/build-win"
EXE="${BW}/gtk-webview2-hello.exe"
UCRT="${MINGW_PREFIX:-/ucrt64}/bin"

[[ -f "${EXE}" ]] || { echo "missing ${EXE}" >&2; exit 1; }

mkdir -p "${BW}"
cp -f "${ROOT}/build/vendor/webview2/x64/WebView2Loader.dll" "${BW}/" 2>/dev/null || true

if command -v ldd >/dev/null 2>&1; then
	while IFS= read -r line; do
		case "${line}" in
			*' => /ucrt64/bin/'*)
				path="${line#* => }"
				path="${path%% (*}"
				dll="$(basename "${path}")"
				[[ -f "${UCRT}/${dll}" ]] && cp -f "${UCRT}/${dll}" "${BW}/"
				;;
		esac
	done < <(ldd "${EXE}" 2>/dev/null || true)
fi

echo "=== ldd (missing) ==="
ldd "${EXE}" 2>&1 | grep 'not found' || echo "(none)"

echo "=== run (3s) ==="
cd "${BW}"
timeout 3 ./gtk-webview2-hello.exe 2>&1 || true
