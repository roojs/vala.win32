#!/usr/bin/env bash
# Ensure Windows App Runtime 2.x (x64) is installed.
#
# Skip: WINUI3_SKIP_RUNTIME_INSTALL=1 ./scripts/build-win.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_PS="${ROOT}/scripts/check-winui3-runtime.ps1"
INSTALL_PS="${ROOT}/scripts/install-winui3-runtime.ps1"

run_ps() {
	powershell.exe -NoProfile -ExecutionPolicy Bypass "$@"
}

if [[ "${WINUI3_SKIP_RUNTIME_INSTALL:-}" == 1 ]]; then
	echo "[install-winui3-runtime] skipped (WINUI3_SKIP_RUNTIME_INSTALL=1)"
	exit 0
fi

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
	echo "[install-winui3-runtime] error: run in MSYS2 UCRT64" >&2
	exit 1
fi

if run_ps -File "${CHECK_PS}" -Quiet; then
	echo "[install-winui3-runtime] Microsoft.WindowsAppRuntime.2 (x64) already installed"
	exit 0
fi

"${ROOT}/scripts/vendor-winui3-runtime.sh"

runtime_dir="${ROOT}/build/vendor/winui3-runtime"
installer="${runtime_dir}/WindowsAppRuntimeInstall-x64.exe"
msix_dir="${runtime_dir}/msix/x64"

to_win_path() {
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "$1"
	else
		printf '%s' "$1"
	fi
}

ps_args=(-File "${INSTALL_PS}")
if [[ -f "${installer}" ]]; then
	echo "[install-winui3-runtime] running WindowsAppRuntimeInstall-x64.exe --quiet --force ..."
	ps_args+=(-InstallerPath "$(to_win_path "${installer}")")
elif compgen -G "${msix_dir}/*.msix" >/dev/null; then
	echo "[install-winui3-runtime] installing MSIX packages from ${msix_dir} ..."
	ps_args+=(-MsixDir "$(to_win_path "${msix_dir}")")
else
	echo "[install-winui3-runtime] error: no installer or MSIX under ${runtime_dir}" >&2
	exit 1
fi

if ! run_ps "${ps_args[@]}"; then
	echo "[install-winui3-runtime] error: install script failed (see above)" >&2
	exit 1
fi

if ! run_ps -File "${CHECK_PS}" -Quiet; then
	echo "[install-winui3-runtime] error: runtime verification failed after install" >&2
	run_ps -File "${CHECK_PS}"
	exit 1
fi

echo "[install-winui3-runtime] OK"
