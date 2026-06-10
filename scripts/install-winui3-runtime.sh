#!/usr/bin/env bash
# Best-effort Windows App Runtime 2.x (x64) install from MSYS2.
# If this cannot complete, build-win.sh stops once with paste-into-PowerShell instructions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

if [[ "${WINUI3_SKIP_RUNTIME_INSTALL:-}" == 1 ]]; then
	echo "[install-winui3-runtime] skipped (WINUI3_SKIP_RUNTIME_INSTALL=1)"
	exit 0
fi

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
	echo "[install-winui3-runtime] error: run in MSYS2 UCRT64" >&2
	exit 1
fi

if winui3_widgets_ready; then
	echo "[install-winui3-runtime] already installed"
	exit 0
fi

"${ROOT}/scripts/vendor-winui3-runtime.sh"

if winui3_try_install_runtime; then
	echo "[install-winui3-runtime] OK"
	exit 0
fi

echo "[install-winui3-runtime] could not install from MSYS2 (build will stop if still incomplete)"
