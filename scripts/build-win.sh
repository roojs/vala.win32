#!/usr/bin/env bash
# Ensure MSYS2 toolchain; compile Win32/WebView2/GTK demos into build-win/.
# WinUI3 is off by default (BUILD_WINUI3=1 to re-enable) — see README.md.
#
# Steps (WinUI3 disabled): vendor webview2, compile demos.
#
# Repo on Windows: **C:\msys64\tmp\vala.win32** (rsync from Linux — see agent-remote-build.sh).
# Meson objects: **C:\msys64\tmp\vala-win32-build-win** (never Samba). Outputs: build-win/ beside sources.
#
# Debug log: build-win/last-build.log
#
# From Windows PowerShell (one line):
#   C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /c/msys64/tmp/vala.win32 && ./scripts/build-win.sh'
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

DEBUG_LOG="${ROOT}/build-win/last-build.log"
# Native path under MSYS2 (fast; avoids UNC bugs with Vala-generated .c files).
LOCAL_BUILD="${LOCAL_BUILD_DIR:-/c/msys64/tmp/vala-win32-build-win}"

MESON_OPTS=(
	-Dbuild_posix_examples=true
	-Dbuild_ergonomic_examples=true
	-Dregen_on_build=false
)

# WinUI3 off by default — MSIX/PRI/PriGen rabbit hole; see README.md § WinUI3.
BUILD_WINUI3="${BUILD_WINUI3:-0}"
if [[ "${BUILD_WINUI3}" == 1 ]]; then
	MESON_OPTS+=(-Dbuild_winui3=true)
else
	MESON_OPTS+=(-Dbuild_winui3=false)
fi

# Incremental WinUI3 restore — see docs/windows-winui3-restore-layers.md (BUILD_WINUI3=1 only)
WINUI3_LAYER="${WINUI3_LAYER:-hello}"
WINUI3_EXES=()

winui3_build_enabled() {
	[[ "${BUILD_WINUI3}" == 1 ]]
}

winui3_layer_needs_sparse() {
	[[ "${WINUI3_LAYER}" == widgets || "${WINUI3_LAYER}" == sparse ]]
}

winui3_layer_needs_widgets_exe() {
	winui3_layer_needs_sparse
}

# Sparse MSIX + embed + register (skip when WINUI3_UNPACKAGED_WIDGETS=1).
winui3_use_sparse_identity() {
	winui3_layer_needs_sparse && [[ "${WINUI3_UNPACKAGED_WIDGETS:-}" != 1 ]]
}

case "${WINUI3_LAYER}" in
	hello)
		WINUI3_EXES=(winui3-hello-native)
		;;
	widgets|sparse)
		WINUI3_EXES=(winui3-widgets-native winui3-hello-native)
		;;
	*)
		if winui3_build_enabled; then
			echo "[build-win] error: unknown WINUI3_LAYER=${WINUI3_LAYER} (hello|widgets|sparse)" >&2
			exit 1
		fi
		;;
esac

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
	gtk-webview2-hello
)
if winui3_build_enabled; then
	DEMO_EXES=( "${WINUI3_EXES[@]}" "${DEMO_EXES[@]}" )
fi

ensure_gtk3_for_webview_demo() {
	if pkg-config --exists gtk+-3.0 2>/dev/null; then
		return 0
	fi
	echo '[build-win] gtk+-3.0 missing; installing mingw-w64-ucrt-x86_64-gtk3...'
	if pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-gtk3; then
		return 0
	fi
	echo '[build-win] warning: gtk3 install failed; gtk-webview2-hello will be skipped' >&2
	SKIP_GTK_WEBVIEW2=1
}

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
		# ldd cannot read PE files on Samba (X:); use local Meson dir on C:.
		if [[ -f "${LOCAL_BUILD}/winui3-hello-native.exe" ]] && command -v ldd >/dev/null 2>&1; then
			echo "--- ldd LOCAL winui3-hello-native.exe ---"
			ldd "${LOCAL_BUILD}/winui3-hello-native.exe" 2>&1 || true
		fi
		echo "=== end debug bundle ==="
	} >> "${DEBUG_LOG}" 2>&1
	tail -80 "${DEBUG_LOG}" >&2
}

on_err() {
	trap - ERR
	if winui3_build_enabled; then
		if winui3_runtime_gate_failed; then
			emit_winui3_runtime_stop || true
			exit 1
		fi
		if winui3_sparse_gate_failed; then
			emit_winui3_sparse_stop || true
			exit 1
		fi
	fi
	{
		echo ""
		echo "=== build failure summary (ERR at line ${1}) ==="
		grep -E 'FAILED:|c1010070|embed-winui3|register-winui3|Add-AppxPackage|0x800B|Developer Mode|ninja: build stopped' "${DEBUG_LOG}" \
			| tail -12 || true
	} >> "${DEBUG_LOG}" 2>&1
	dump_debug_bundle "error line ${1}"
	echo "[build-win] FAILED - log: ${DEBUG_LOG}" >&2
	if winui3_build_enabled; then
		if [[ -f "${ROOT}/build-win/WINUI3-SPARSE-STOP.txt" ]]; then
			emit_winui3_sparse_stop || true
		fi
		if [[ -f "${ROOT}/build-win/WINUI3-RUNTIME-STOP.txt" ]]; then
			emit_winui3_runtime_stop || true
		fi
	fi
	exit 1
}

start_logging() {
	mkdir -p "${ROOT}/build-win"
	if winui3_build_enabled; then
		clear_winui3_runtime_stop
		clear_winui3_sparse_stop
	fi
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
	# Agent C: mirror must not reuse a Meson dir configured for Samba/UNC (X:).
	if [[ "${ROOT}" == /c/msys64/tmp/vala.win32 ]]; then
		grep -qE '192\.168\.88\.132|//.*vala\.win32|/x/vala\.win32' "${coredata}" 2>/dev/null && return 0
	fi
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

COMPILE_EXES=()
for _exe in "${DEMO_EXES[@]}"; do
	if ! winui3_build_enabled; then
		case "${_exe}" in
			winui3-*) continue ;;
		esac
	fi
	case "${WINUI3_LAYER}" in
		hello)
			case "${_exe}" in
				winui3-widgets-native) continue ;;
			esac
			;;
	esac
	if [[ "${_exe}" == gtk-webview2-hello && -n "${SKIP_GTK_WEBVIEW2:-}" ]]; then
		continue
	fi
	COMPILE_EXES+=("${_exe}")
done

stage_winui3_sparse_assets() {
	mkdir -p build-win/Assets
	if [[ -f metadata/winui3-sparse/Assets/StoreLogo.png ]]; then
		cp -f metadata/winui3-sparse/Assets/StoreLogo.png build-win/Assets/StoreLogo.png
	fi
}

copy_mingw_runtime_dlls_to_build_win() {
	local ucrt_bin="${MINGW_PREFIX:-/ucrt64}/bin"
	[[ -d "${ucrt_bin}" ]] || return 0
	for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
		if [[ -f "${ucrt_bin}/${dll}" ]]; then
			cp -f "${ucrt_bin}/${dll}" build-win/
		fi
	done
}

copy_ldd_runtime_dlls_to_build_win() {
	local exe="$1"
	local ucrt_bin="${MINGW_PREFIX:-/ucrt64}/bin"
	[[ -f "${exe}" && -d "${ucrt_bin}" ]] || return 0
	command -v ldd >/dev/null 2>&1 || return 0
	local line dll path
	while IFS= read -r line; do
		case "${line}" in
			*' => /ucrt64/bin/'*|*' => /'*)
				path="${line#* => }"
				path="${path%% (*}"
				dll="$(basename "${path}")"
				if [[ -f "${ucrt_bin}/${dll}" ]]; then
					cp -f "${ucrt_bin}/${dll}" build-win/
				fi
				;;
		esac
	done < <(ldd "${exe}" 2>/dev/null || true)
}

copy_winui3_to_build_win() {
	mkdir -p build-win
	stage_winui3_sparse_assets
	if [[ -f build/vendor/winui3-sparse/vala.win32.winui3.sparse.msix ]]; then
		cp -f build/vendor/winui3-sparse/vala.win32.winui3.sparse.msix build-win/
	fi
	if [[ -f build/vendor/winui3-sparse/vala.win32.sparse.cer ]]; then
		cp -f build/vendor/winui3-sparse/vala.win32.sparse.cer build-win/
	fi
	local bootstrap_dll="${LOCAL_BUILD}/Microsoft.WindowsAppRuntime.Bootstrap.dll"
	if [[ -f "${bootstrap_dll}" ]]; then
		cp -f "${bootstrap_dll}" build-win/
	elif [[ -f build/vendor/winui3/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll ]]; then
		cp -f build/vendor/winui3/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll build-win/
	fi
	if winui3_layer_needs_widgets_exe; then
		if [[ -f "${LOCAL_BUILD}/winui3-widgets-native.exe" ]]; then
			cp -f "${LOCAL_BUILD}/winui3-widgets-native.exe" build-win/
		fi
	fi
	if ! winui3_layer_needs_widgets_exe; then
		rm -f build-win/winui3-widgets-native.exe
		if [[ -f "${LOCAL_BUILD}/winui3-hello-native.exe" ]]; then
			cp -f "${LOCAL_BUILD}/winui3-hello-native.exe" build-win/
		fi
	fi
	copy_mingw_runtime_dlls_to_build_win
}

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
	if [[ -f build/vendor/winui3-sparse/vala.win32.winui3.sparse.msix ]]; then
		cp -f build/vendor/winui3-sparse/vala.win32.winui3.sparse.msix build-win/
	fi
	stage_winui3_sparse_assets
	# Track B demos (webview2-demo, hello-window, …) need MSYS2 GLib beside the exe when not run from UCRT64 shell.
	local ucrt_bin="${MINGW_PREFIX:-/ucrt64}/bin"
	if [[ -d "${ucrt_bin}" ]]; then
		for dll in \
			libglib-2.0-0.dll libgobject-2.0-0.dll libintl-8.dll libiconv-2.dll libffi-8.dll libpcre2-8-0.dll; do
			if [[ -f "${ucrt_bin}/${dll}" ]]; then
				cp -f "${ucrt_bin}/${dll}" build-win/
			fi
		done
	fi
	copy_mingw_runtime_dlls_to_build_win
	if [[ -f "${LOCAL_BUILD}/gtk-webview2-hello.exe" ]]; then
		copy_ldd_runtime_dlls_to_build_win "${LOCAL_BUILD}/gtk-webview2-hello.exe"
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
	local share_exe="${ROOT}/build-win/winui3-hello-native.exe"
	local share_dir="${ROOT}/build-win"
	local ldd_exe="${LOCAL_BUILD}/winui3-hello-native.exe"

	if [[ ! -f "${share_exe}" ]]; then
		echo "[build-win] error: winui3-hello-native.exe missing after compile" >&2
		return 1
	fi

	echo "[build-win] === winui3-hello-native.exe PE dependency check ==="

	local missing_beside=()
	for dll in \
		Microsoft.WindowsAppRuntime.Bootstrap.dll \
		libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
		if [[ ! -f "${share_dir}/${dll}" ]]; then
			missing_beside+=("${dll}")
		fi
	done
	if [[ ${#missing_beside[@]} -gt 0 ]]; then
		echo "[build-win] error: required DLL(s) missing beside exe in build-win/:" >&2
		printf '  %s\n' "${missing_beside[@]}" >&2
		return 1
	fi
	echo "[build-win]   beside exe: Bootstrap + MinGW runtime DLLs OK"

	if ! command -v ldd >/dev/null 2>&1; then
		echo "[build-win] error: ldd not in PATH (pacman -S mingw-w64-ucrt-x86_64-binutils)" >&2
		return 1
	fi
	if [[ ! -f "${ldd_exe}" ]]; then
		echo "[build-win] warning: skip ldd (local copy missing: ${ldd_exe})" >&2
		return 0
	fi

	local ldd_out=""
	ldd_out="$(ldd "${ldd_exe}" 2>&1)" || true
	echo "[build-win] ldd ${ldd_exe}"
	echo "${ldd_out}"
	if echo "${ldd_out}" | grep -qi 'permission denied'; then
		echo "[build-win] warning: ldd permission denied; skipping import check" >&2
		return 0
	fi

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
	echo "error: build-win.sh must be launched via msys2_shell.cmd -ucrt64 (not plain bash/PowerShell)" >&2
	echo "Run:" >&2
	winui3_build_win_shell_cmd >&2
	exit 1
fi

start_logging
echo "[build-win] Log: ${DEBUG_LOG}"
echo "[build-win] Repo: ${ROOT}"
echo "[build-win] Meson dir: ${LOCAL_BUILD}"

./scripts/setup-msys2-toolchain.sh
ensure_gtk3_for_webview_demo
configure_build_win

if winui3_build_enabled; then
	echo '[build-win] vendor-winui3-sdk.sh (nupkg extract + cppwinrt can take a few minutes on first run)'
	./scripts/vendor-winui3-sdk.sh
	require_winui3_vendor

	echo "[build-win] WinUI3 layer: ${WINUI3_LAYER} (see docs/windows-winui3-restore-layers.md)"
	if winui3_use_sparse_identity; then
		echo '[build-win] vendor-winui3-sparse.sh (pack sparse MSIX)'
		./scripts/vendor-winui3-sparse.sh
	elif winui3_layer_needs_widgets_exe; then
		echo '[build-win] skip sparse MSIX (WINUI3_UNPACKAGED_WIDGETS=1)'
	else
		echo '[build-win] skip sparse MSIX (WINUI3_LAYER=hello)'
	fi
	echo '[build-win] install-winui3-runtime.sh'
	./scripts/install-winui3-runtime.sh
	if winui3_layer_needs_widgets_exe; then
		require_winui3_widgets_runtime
	fi

	if winui3_compile_ready; then
		if [[ "${AGENT_REMOTE_BUILD:-}" == 1 ]]; then
			echo '[build-win] agent: clean WinUI3 exes (force relink after rsync)'
			ninja -C "${LOCAL_BUILD}" -t clean winui3-hello-native.exe 2>/dev/null || true
			winui3_layer_needs_sparse \
				&& ninja -C "${LOCAL_BUILD}" -t clean winui3-widgets-native.exe 2>/dev/null || true
		fi
		if winui3_use_sparse_identity; then
			echo '[build-win] compile winui3-widgets-native + embed'
			meson compile -C "${LOCAL_BUILD}" winui3-widgets-native \
				winui3-widgets-embed-manifest
		elif winui3_layer_needs_widgets_exe; then
			echo '[build-win] compile winui3-widgets-native (unpackaged; no embed)'
			meson compile -C "${LOCAL_BUILD}" winui3-widgets-native
		else
			echo '[build-win] compile winui3-hello-native (hello layer; no embed)'
			meson compile -C "${LOCAL_BUILD}" winui3-hello-native
		fi
		copy_winui3_to_build_win
		if winui3_use_sparse_identity; then
			./scripts/register-winui3-sparse.sh
		fi
		if [[ "${AGENT_REMOTE_BUILD:-}" == 1 ]]; then
			check_winui3_pe_deps
			WINUI3_LAYER="${WINUI3_LAYER}" WINUI3_UNPACKAGED_WIDGETS="${WINUI3_UNPACKAGED_WIDGETS:-}" \
				./scripts/validate-winui3-build-win.sh
			BUILD_WIN_WIN="$(to_win_path "${ROOT}/build-win")"
			echo "[build-win] OK (agent remote, layer=${WINUI3_LAYER}) - ${BUILD_WIN_WIN}\\"
			if winui3_layer_needs_sparse; then
				echo "  Run: C:\\msys64\\tmp\\vala.win32\\build-win\\winui3-widgets-native.exe"
			else
				echo "  Run: C:\\msys64\\tmp\\vala.win32\\build-win\\winui3-hello-native.exe"
			fi
			echo "  Log: winui3-debug.log"
			echo "  Full log: ${DEBUG_LOG}"
			exit 0
		fi
	fi
else
	echo '[build-win] WinUI3 disabled (BUILD_WINUI3=1 to re-enable; see README.md)'
fi

echo '[build-win] vendor-webview2-sdk.sh'
./scripts/vendor-webview2-sdk.sh
if [[ -f "${LOCAL_BUILD}/meson-private/coredata.dat" ]] \
	&& ! grep -q 'webview2-host-native\.exe:' "${LOCAL_BUILD}/build.ninja" 2>/dev/null; then
	echo '[build-win] meson reconfigure (webview2 SDK now staged)...'
	meson setup --reconfigure "${LOCAL_BUILD}" "${ROOT}" "${MESON_OPTS[@]}"
fi

echo '[build-win] compile demo targets'
rest_targets=()
for name in "${COMPILE_EXES[@]}"; do
	case " ${WINUI3_EXES[*]} " in
		*" ${name} "*) ;;
		*) rest_targets+=("${name}") ;;
	esac
done
meson compile -C "${LOCAL_BUILD}" "${rest_targets[@]}"

copy_artifacts_to_share
if winui3_build_enabled && winui3_layer_needs_sparse; then
	./scripts/register-winui3-sparse.sh
fi
if winui3_build_enabled; then
	check_winui3_pe_deps
fi

BUILD_WIN_WIN="$(to_win_path "${ROOT}/build-win")"
echo "[build-win] OK - ${#COMPILE_EXES[@]} demos in ${BUILD_WIN_WIN}\\"
if winui3_build_enabled; then
	if winui3_layer_needs_sparse; then
		echo "  WinUI3 layer=${WINUI3_LAYER}: winui3-widgets-native.exe (log: winui3-debug.log)"
		echo "  Run: C:\\msys64\\tmp\\vala.win32\\build-win\\winui3-widgets-native.exe"
	else
		echo "  WinUI3 layer=hello: winui3-hello-native.exe (log: winui3-debug.log)"
		echo "  Run: C:\\msys64\\tmp\\vala.win32\\build-win\\winui3-hello-native.exe"
	fi
else
	echo "  webview2-host-native.exe, gtk-webview2-hello.exe, Win32 demos — see README.md"
fi
echo "  Full log: ${DEBUG_LOG}"
