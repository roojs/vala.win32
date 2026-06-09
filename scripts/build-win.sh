#!/usr/bin/env bash
# Ensure MSYS2 toolchain (incl. cppwinrt for WinUI3), vendor SDKs, compile all demo EXEs.
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
	winui3-hello-native
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
		if [[ -f "${ROOT}/build-win/winui3-hello-native.exe" ]] && command -v ldd >/dev/null 2>&1; then
			echo "--- ldd build-win/winui3-hello-native.exe ---"
			ldd "${ROOT}/build-win/winui3-hello-native.exe" 2>&1 || true
		elif [[ -f "${LOCAL_BUILD}/winui3-hello-native.exe" ]] && command -v ldd >/dev/null 2>&1; then
			echo "--- ldd LOCAL winui3-hello-native.exe ---"
			ldd "${LOCAL_BUILD}/winui3-hello-native.exe" 2>&1 || true
		fi
		echo "=== end debug bundle ==="
	} >> "${DEBUG_LOG}" 2>&1
	tail -80 "${DEBUG_LOG}" >&2
}

on_err() {
	trap - ERR
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

winui3_compile_ready() {
	[[ -f "${ROOT}/build/vendor/winui3/.vendor-stamp" ]] \
		&& [[ -f "${ROOT}/build/vendor/winui3/cppwinrt/winrt/impl/Microsoft.UI.Xaml.Controls.1.h" ]]
}

require_winui3_vendor() {
	if winui3_compile_ready; then
		return 0
	fi
	echo "[build-win] error: WinUI3 cppwinrt headers missing after vendor-winui3-sdk.sh" >&2
	echo "  Expected: build/vendor/winui3/.vendor-stamp" >&2
	echo "            build/vendor/winui3/cppwinrt/winrt/impl/Microsoft.UI.Xaml.Controls.1.h" >&2
	echo "  See vendor-winui3 output above in ${DEBUG_LOG}" >&2
	exit 1
}

COMPILE_EXES=("${DEMO_EXES[@]}")

copy_artifacts_to_share() {
	mkdir -p build-win
	local copied=0
	local missing=()
	local -a expected=("${COMPILE_EXES[@]}")
	for name in "${expected[@]}"; do
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
	local bootstrap_dll="${LOCAL_BUILD}/Microsoft.WindowsAppRuntime.Bootstrap.dll"
	if [[ -f "${bootstrap_dll}" ]]; then
		cp -f "${bootstrap_dll}" build-win/
	elif [[ -f build/vendor/winui3/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll ]]; then
		cp -f build/vendor/winui3/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll build-win/
	fi
	# Track B demos (webview2-demo, hello-window, …) need MSYS2 GLib beside the exe when not run from UCRT64 shell.
	local ucrt_bin="${MINGW_PREFIX:-/ucrt64}/bin"
	if [[ -d "${ucrt_bin}" ]]; then
		for dll in \
			libglib-2.0-0.dll libgobject-2.0-0.dll libintl-8.dll libiconv-2.dll libffi-8.dll libpcre2-8-0.dll \
			libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
			if [[ -f "${ucrt_bin}/${dll}" ]]; then
				cp -f "${ucrt_bin}/${dll}" build-win/
			fi
		done
	fi
	if [[ ! -f build-win/Microsoft.WindowsAppRuntime.Bootstrap.dll ]]; then
		echo "[build-win] error: Microsoft.WindowsAppRuntime.Bootstrap.dll missing in build-win/" >&2
		return 1
	fi
	if [[ ${#missing[@]} -gt 0 ]]; then
		echo "[build-win] error: ${#missing[@]} demo EXE(s) not built:" >&2
		printf '  %s\n' "${missing[@]}" >&2
		return 1
	fi
	echo "[build-win] copied ${copied}/${#expected[@]} demo EXEs to build-win/"
}

check_winui3_pe_deps() {
	local exe="${ROOT}/build-win/winui3-hello-native.exe"
	local dir="${ROOT}/build-win"

	if [[ ! -f "${exe}" ]]; then
		echo "[build-win] error: winui3-hello-native.exe missing after compile" >&2
		return 1
	fi

	echo "[build-win] === winui3-hello-native.exe PE dependency check ==="

	local missing_beside=()
	for dll in Microsoft.WindowsAppRuntime.Bootstrap.dll; do
		if [[ ! -f "${dir}/${dll}" ]]; then
			missing_beside+=("${dll}")
		fi
	done
	if [[ ${#missing_beside[@]} -gt 0 ]]; then
		echo "[build-win] error: required DLL(s) missing beside exe in build-win/:" >&2
		printf '  %s\n' "${missing_beside[@]}" >&2
		return 1
	fi
	echo "[build-win]   beside exe: Microsoft.WindowsAppRuntime.Bootstrap.dll OK"

	if ! command -v ldd >/dev/null 2>&1; then
		echo "[build-win] error: ldd not in PATH (pacman -S mingw-w64-ucrt-x86_64-binutils)" >&2
		return 1
	fi

	local ldd_out=""
	ldd_out="$(ldd "${exe}" 2>&1)" || true
	echo "${ldd_out}"

	# MinGW runtime (only if dynamically linked; static-libstdc++ should not need these).
	local mingw_missing=()
	for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
		if echo "${ldd_out}" | grep -q "${dll}.*not found"; then
			mingw_missing+=("${dll}")
		fi
	done
	if [[ ${#mingw_missing[@]} -gt 0 ]]; then
		echo "[build-win] error: ldd reports missing MinGW runtime DLL(s):" >&2
		printf '  %s\n' "${mingw_missing[@]}" >&2
		echo "[build-win]   copied to build-win/: libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll" >&2
		return 1
	fi

	local other_missing=""
	other_missing="$(echo "${ldd_out}" | grep 'not found' \
		| grep -viE 'api-ms-|ext-ms-|KERNEL32|USER32|GDI32|OLE32|OLEAUT32|COMDLG32|SHELL32|ADVAPI32|MSVCRT|ucrtbase|RPCRT4|COMBASE|SHLWAPI|IMM32|WINMM|VERSION|SETUPAPI|WTSAPI32|CRYPT32|SECHOST|BCRYPT|NTDLL|WS2_32|WINHTTP|PROPSYS|DWMAPI|UXTHEME|USERENV|profapi|windows.storage|CoreMessaging|Microsoft\.UI\.|Microsoft\.WindowsAppRuntime' \
		|| true)"
	if [[ -n "${other_missing}" ]]; then
		echo "[build-win] error: ldd reports unresolved imports:" >&2
		echo "${other_missing}" >&2
		return 1
	fi

	echo "[build-win] PE dependency check OK"
	return 0
}

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
	echo "error: build-win.sh must run in MSYS2 UCRT64 (MSYSTEM=UCRT64)" >&2
	exit 1
fi

start_logging
echo "[build-win] Log: ${DEBUG_LOG}"
echo "[build-win] Local Meson dir: ${LOCAL_BUILD} (source stays on X:)"

./scripts/setup-msys2-toolchain.sh
echo '[build-win] vendor-webview2-sdk.sh'
./scripts/vendor-webview2-sdk.sh
echo '[build-win] vendor-winui3-sdk.sh (nupkg extract + cppwinrt can take a few minutes on first run)'
./scripts/vendor-winui3-sdk.sh
require_winui3_vendor
echo '[build-win] install-winui3-runtime.sh (NuGet redist + quiet installer if needed)'
./scripts/install-winui3-runtime.sh
configure_build_win

echo '[build-win] meson compile (all demo targets)'
meson compile -C "${LOCAL_BUILD}" "${COMPILE_EXES[@]}"

copy_artifacts_to_share
check_winui3_pe_deps

if ! powershell.exe -NoProfile -ExecutionPolicy Bypass \
	-File "${ROOT}/scripts/check-winui3-runtime.ps1" -Quiet; then
	echo "[build-win] error: Windows App Runtime not installed (required for winui3-hello-native)" >&2
	powershell.exe -NoProfile -ExecutionPolicy Bypass \
		-File "${ROOT}/scripts/check-winui3-runtime.ps1"
	exit 1
fi

echo "[build-win] OK — ${#COMPILE_EXES[@]} demos in X:\\vala.win32\\build-win\\"
echo "  Full log: ${DEBUG_LOG}"
