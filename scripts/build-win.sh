#!/usr/bin/env bash
# Vendor WebView2 SDK, configure, compile all demo EXEs (Track A + Track B + WebView2).
#
# Uses a **local** Meson build directory (not on X:) — Samba breaks Vala -C paths and
# makes regen/configure painfully slow. Copies .exe (+ WebView2Loader.dll) back to build-win/ on X:.
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
	-Dbuild_posix_examples=true
	-Dbuild_ergonomic_examples=true
	-Dregen_on_build=false
)

# All demo executables (must match meson.build target names).
DEMO_EXES=(
	hello-window-native
	button-demo-native
	dialog-demo-native
	common-dialog-demo-native
	menu-demo-native
	error-demo-native
	hello-window
	button-demo
	widgets-demo
	dialog-demo
	common-dialog-demo
	menu-demo
	error-demo
	webview2-host-native
	webview2-demo
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
			echo "--- ninja demo targets ---"
			ninja -C "${LOCAL_BUILD}" -t targets all 2>/dev/null \
				| grep -E '\.exe:|\.exe$' \
				| grep -E 'demo|hello-window|webview2' || true
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
	grep -q 'regen_on_build=true' "${coredata}" 2>/dev/null && return 0
	if [[ -f "${LOCAL_BUILD}/build.ninja" ]]; then
		# Stale build from before target renames (webview2-host-demo → webview2-host-native).
		grep -q 'webview2-host-demo\.exe:' "${LOCAL_BUILD}/build.ninja" 2>/dev/null && return 0
		grep -q 'webview2-ergo-demo\.exe:' "${LOCAL_BUILD}/build.ninja" 2>/dev/null && return 0
		if ! grep -q 'webview2-host-native\.exe:' "${LOCAL_BUILD}/build.ninja" 2>/dev/null; then
			return 0
		fi
	fi
	return 1
}

configure_build_win() {
	mkdir -p "$(dirname "${LOCAL_BUILD}")"
	if needs_fresh_setup; then
		echo '[build-win] meson setup (fresh local build dir, all demos, no regen)...'
		rm -rf "${LOCAL_BUILD}"
		meson setup "${LOCAL_BUILD}" "${ROOT}" "${MESON_OPTS[@]}"
	elif [[ -f "${LOCAL_BUILD}/meson-private/coredata.dat" ]]; then
		echo '[build-win] meson setup --reconfigure (apply option changes)...'
		meson setup --reconfigure "${LOCAL_BUILD}" "${ROOT}" "${MESON_OPTS[@]}"
	else
		meson setup "${LOCAL_BUILD}" "${ROOT}" "${MESON_OPTS[@]}"
	fi
}

copy_artifacts_to_share() {
	mkdir -p build-win
	local copied=0
	local missing=()
	for name in "${DEMO_EXES[@]}"; do
		local src="${LOCAL_BUILD}/${name}.exe"
		[[ -f "${src}" ]] || src="${LOCAL_BUILD}/${name}"
		if [[ -f "${src}" ]]; then
			cp -f "${src}" "build-win/${name}.exe"
			copied=$((copied + 1))
		else
			missing+=("${name}")
		fi
	done
	local dll="${LOCAL_BUILD}/WebView2Loader.dll"
	if [[ -f "${dll}" ]]; then
		cp -f "${dll}" build-win/WebView2Loader.dll
	elif [[ -f build/vendor/webview2/x64/WebView2Loader.dll ]]; then
		cp -f build/vendor/webview2/x64/WebView2Loader.dll build-win/
	fi
	if [[ ${#missing[@]} -gt 0 ]]; then
		echo "[build-win] error: ${#missing[@]} demo EXE(s) not built:" >&2
		printf '  %s\n' "${missing[@]}" >&2
		return 1
	fi
	echo "[build-win] copied ${copied}/${#DEMO_EXES[@]} demo EXEs to build-win/"
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

echo '[build-win] meson compile (all demo targets)'
meson compile -C "${LOCAL_BUILD}" "${DEMO_EXES[@]}"

copy_artifacts_to_share

echo "[build-win] OK — demos in X:\\vala.win32\\build-win\\"
echo "  Full log: ${DEBUG_LOG}"
