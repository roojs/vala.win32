#!/usr/bin/env bash
# Vendor WebView2 SDK, configure, compile webview2-host-demo.
#
# Uses a **local** Meson build directory (not on X:) — Samba breaks Vala -C paths and
# makes regen/configure painfully slow. Copies the .exe + loader back to build-win/ on X:.
#
# Debug log: build-win/last-build.log
#
# From Windows PowerShell (one line):
#   C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/build-win.sh'
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

DEBUG_LOG="${ROOT}/build-win/last-build.log"
# Native path under MSYS2 (fast; avoids UNC bugs with Vala-generated .c files).
LOCAL_BUILD="${LOCAL_BUILD_DIR:-/c/msys64/tmp/vala-win32-build-win}"

MESON_OPTS=(
	-Dbuild_posix_examples=false
	-Dbuild_ergonomic_examples=false
	-Dregen_on_build=false
)

dump_debug_bundle() {
	local label="${1:-failure}"
	{
		echo ""
		echo "=== debug bundle (${label}) $(date -Iseconds) ==="
		echo "ROOT=${ROOT}"
		echo "LOCAL_BUILD=${LOCAL_BUILD}"
		echo "PWD=$(pwd)"
		echo "MSYSTEM=${MSYSTEM:-}"
		command -v gcc valac meson ninja 2>/dev/null || true
		if [[ -f "${LOCAL_BUILD}/build.ninja" ]]; then
			echo "--- ninja targets (count) ---"
			ninja -C "${LOCAL_BUILD}" -t targets all 2>/dev/null | wc -l || true
			ninja -C "${LOCAL_BUILD}" -t targets all 2>/dev/null | grep -i webview2 || true
		fi
		if [[ -f "${LOCAL_BUILD}/meson-logs/meson-log.txt" ]]; then
			echo "--- tail LOCAL meson-log.txt ---"
			tail -40 "${LOCAL_BUILD}/meson-logs/meson-log.txt"
		fi
		echo "=== end debug bundle ==="
	} >> "${DEBUG_LOG}" 2>&1
	cat "${DEBUG_LOG}" >&2
}

on_err() {
	dump_debug_bundle "error line ${1}"
	echo "[build-win] FAILED — log: ${DEBUG_LOG}" >&2
	exit 1
}

start_logging() {
	mkdir -p "${ROOT}/build-win"
	: > "${DEBUG_LOG}"
	{
		echo "=== build-win.sh started $(date -Iseconds) ==="
		echo "Log file: ${DEBUG_LOG}"
		echo "Meson build dir (local): ${LOCAL_BUILD}"
	} >> "${DEBUG_LOG}"
	exec > >(tee -a "${DEBUG_LOG}") 2>&1
	trap 'on_err ${LINENO}' ERR
	set -o pipefail
}

needs_fresh_setup() {
	local coredata="${LOCAL_BUILD}/meson-private/coredata.dat"
	[[ ! -f "${coredata}" ]] && return 0
	grep -qE 'cross/mingw-w64\.ini|/home/[^/]+/' "${coredata}" 2>/dev/null && return 0
	grep -q 'build_posix_examples=true' "${coredata}" 2>/dev/null && return 0
	grep -q 'regen_on_build=true' "${coredata}" 2>/dev/null && return 0
	return 1
}

configure_build_win() {
	mkdir -p "$(dirname "${LOCAL_BUILD}")"
	if needs_fresh_setup; then
		echo '[build-win] meson setup (local build dir, WebView2 only, no regen)...'
		rm -rf "${LOCAL_BUILD}"
		meson setup "${LOCAL_BUILD}" "${ROOT}" "${MESON_OPTS[@]}"
		return 0
	fi
	echo '[build-win] Using existing local Meson build (skip reconfigure)'
}

copy_artifacts_to_share() {
	mkdir -p build-win
	local exe="${LOCAL_BUILD}/webview2-host-demo.exe"
	local dll="${LOCAL_BUILD}/WebView2Loader.dll"
	[[ -f "${exe}" ]] || exe="${LOCAL_BUILD}/webview2-host-demo"
	[[ -f "${exe}" ]] || { echo "error: no webview2-host-demo.exe in ${LOCAL_BUILD}" >&2; return 1; }
	cp -f "${exe}" build-win/webview2-host-demo.exe
	if [[ -f "${dll}" ]]; then
		cp -f "${dll}" build-win/WebView2Loader.dll
	elif [[ -f build/vendor/webview2/x64/WebView2Loader.dll ]]; then
		cp -f build/vendor/webview2/x64/WebView2Loader.dll build-win/
	fi
}

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
	echo "error: build-win.sh must run in MSYS2 UCRT64 (MSYSTEM=UCRT64)" >&2
	exit 1
fi

start_logging
echo "[build-win] Log: ${DEBUG_LOG}"
echo "[build-win] Local Meson dir: ${LOCAL_BUILD} (source stays on X:)"

./scripts/vendor-webview2-sdk.sh
configure_build_win

echo '[build-win] meson compile webview2-host-demo (5 targets typical, not 22)'
meson compile -C "${LOCAL_BUILD}" webview2-host-demo

copy_artifacts_to_share

echo "[build-win] OK — X:\\vala.win32\\build-win\\webview2-host-demo.exe"
echo "  Full log: ${DEBUG_LOG}"
echo "  Run: build-win/webview2-host-demo.exe https://example.com/"
