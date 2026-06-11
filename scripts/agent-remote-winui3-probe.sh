#!/usr/bin/env bash
# Run on Windows UCRT64 via SSH: probe exe launch + write build-win/agent-probe.txt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_WIN="${ROOT}/build-win"
EXE="${BUILD_WIN}/winui3-widgets-native.exe"
OUT="${BUILD_WIN}/agent-probe.txt"
MANIFEST_OUT="${BUILD_WIN}/agent-extracted.manifest"

{
	echo "probe $(date -Iseconds)"
	echo "--- launch ---"
	set +e
	(cd "${BUILD_WIN}" && ./winui3-widgets-native.exe) &
	pid=$!
	sleep 8
	if kill -0 "${pid}" 2>/dev/null; then
		echo "still running pid=${pid}"
		kill "${pid}" 2>/dev/null || true
	else
		wait "${pid}" || echo "exit=$?"
	fi
	set -e
	echo "--- log tail ---"
	tail -20 "${BUILD_WIN}/winui3-debug.log" 2>/dev/null || true
} > "${OUT}" 2>&1

find_mt() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/mt.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/mt.exe; do
		[[ -f "${kit}" ]] && printf '%s' "${kit}" && return 0
	done
	return 1
}

MT="$(find_mt || true)"
if [[ -n "${MT}" && -f "${EXE}" ]]; then
	to_win_path() {
		if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"
		else printf '%s' "$1" | sed -E 's|^/([a-zA-Z])/(.*)|\1:/\2|; s|/|\\|g'; fi
	}
	EXE_WIN="$(to_win_path "${EXE}")"
	MAN_WIN="$(to_win_path "${MANIFEST_OUT}")"
	MSYS2_ARG_CONV_EXCL='*' "${MT}" -nologo -inputresource:"${EXE_WIN};#1" -out:"${MAN_WIN}" >/dev/null 2>&1 || true
	[[ -f "${MANIFEST_OUT}" ]] && { echo "--- embedded manifest ---"; cat "${MANIFEST_OUT}"; } >> "${OUT}"
fi
