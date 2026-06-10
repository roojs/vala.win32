#!/usr/bin/env bash
# Register sparse MSIX so exes with embedded <msix> manifest can start (package identity).
# Requires build-win/ layout: sparse MSIX, Assets/StoreLogo.png, WinUI3 exes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

BUILD_WIN="${ROOT}/build-win"
MSIX="${BUILD_WIN}/vala.win32.winui3.sparse.msix"
ASSETS_SRC="${ROOT}/metadata/winui3-sparse/Assets/StoreLogo.png"

stage_winui3_sparse_assets() {
	mkdir -p "${BUILD_WIN}/Assets"
	if [[ -f "${ASSETS_SRC}" ]]; then
		cp -f "${ASSETS_SRC}" "${BUILD_WIN}/Assets/StoreLogo.png"
	fi
}

ps_escape() {
	printf '%s' "$1" | sed "s/'/''/g"
}

register_winui3_sparse() {
	stage_winui3_sparse_assets

	if [[ ! -f "${MSIX}" ]]; then
		echo "[register-winui3-sparse] warning: missing ${MSIX}" >&2
		return 1
	fi
	if [[ ! -f "${BUILD_WIN}/Assets/StoreLogo.png" ]]; then
		echo "[register-winui3-sparse] warning: missing build-win/Assets/StoreLogo.png" >&2
		return 1
	fi

	local dir_win msix_win dir_esc msix_esc
	dir_win="$(to_win_path "${BUILD_WIN}")"
	msix_win="$(to_win_path "${MSIX}")"
	dir_esc="$(ps_escape "${dir_win}")"
	msix_esc="$(ps_escape "${msix_win}")"

	echo "[register-winui3-sparse] ExternalLocation=${dir_win}"
	MSYS2_ARG_CONV_EXCL='*' winui3_ps "
		\$ErrorActionPreference = 'Stop'
		Add-AppxPackage -LiteralPath '${msix_esc}' -ExternalLocation '${dir_esc}' -ForceUpdateFromAnyVersion
		Write-Output '[register-winui3-sparse] sparse package registered'
	"
}

register_winui3_sparse
