#!/usr/bin/env bash
# Register sparse MSIX so exes with embedded <msix> manifest can start (package identity).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

if [[ "${WINUI3_SKIP_SPARSE_REGISTER:-}" == 1 ]]; then
	echo "[register-winui3-sparse] skipped (WINUI3_SKIP_SPARSE_REGISTER=1)"
	exit 0
fi

BUILD_WIN="${ROOT}/build-win"
MSIX="${BUILD_WIN}/vala.win32.winui3.sparse.msix"
ASSETS_SRC="${ROOT}/metadata/winui3-sparse/Assets/StoreLogo.png"

stage_winui3_sparse_assets() {
	mkdir -p "${BUILD_WIN}/Assets"
	if [[ -f "${ASSETS_SRC}" ]]; then
		cp -f "${ASSETS_SRC}" "${BUILD_WIN}/Assets/StoreLogo.png"
	fi
}

register_winui3_sparse() {
	clear_winui3_sparse_stop
	stage_winui3_sparse_assets

	local dir_win msix_win
	dir_win="$(to_win_path "${BUILD_WIN}")"
	msix_win="$(to_win_path "${MSIX}")"

	if [[ ! -f "${MSIX}" ]]; then
		write_winui3_sparse_stop_banner "sparse MSIX missing: ${MSIX}" "${msix_win}" "${dir_win}"
		return 1
	fi
	if [[ ! -f "${BUILD_WIN}/Assets/StoreLogo.png" ]]; then
		write_winui3_sparse_stop_banner "Assets/StoreLogo.png missing under build-win/" "${msix_win}" "${dir_win}"
		return 1
	fi
	winui3_log_developer_mode_status

	echo "[register-winui3-sparse] ExternalLocation=${dir_win}"
	local ps_out ps_rc=0
	ps_out="$(winui3_register_sparse_ps "${msix_win}" "${dir_win}" 2>&1)" || ps_rc=$?
	if [[ ${ps_rc} -eq 0 ]]; then
		echo "${ps_out}"
		echo "[register-winui3-sparse] sparse package registered"
		return 0
	fi

	local reason="${ps_out}"
	if echo "${ps_out}" | grep -qi '0x800B0100\|digitally signed\|signature'; then
		reason="HRESULT 0x800B0100 sparse MSIX signature/trust failed (not Developer Mode). ${ps_out}"
	fi
	write_winui3_sparse_stop_banner "${reason}" "${msix_win}" "${dir_win}"
	echo "${ps_out}" >&2
	return 1
}

register_winui3_sparse
