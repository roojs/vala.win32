#!/usr/bin/env bash
# Build sparse MSIX for unpackaged WinUI3 package identity (external location).
# Output: build/vendor/winui3-sparse/vala.win32.winui3.sparse.msix
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/metadata/winui3-sparse"
OUT="${ROOT}/build/vendor/winui3-sparse"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/winui3-sparse.XXXXXX")"
trap 'rm -rf "${STAGE}"' EXIT

find_makeappx() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/makeappx.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/makeappx.exe; do
		if [[ -f "${kit}" ]]; then
			printf '%s' "${kit}"
			return 0
		fi
	done
	return 1
}

MAKEAPPX="$(find_makeappx || true)"
if [[ -z "${MAKEAPPX}" ]]; then
	echo "[vendor-winui3-sparse] warning: makeappx.exe not found (install Windows 10 SDK)" >&2
	exit 1
fi

mkdir -p "${OUT}" "${STAGE}/Assets"
cp -f "${SRC}/AppxManifest.xml" "${STAGE}/"
cp -f "${SRC}/Assets/StoreLogo.png" "${STAGE}/Assets/"

MSIX="${OUT}/vala.win32.winui3.sparse.msix"
rm -f "${MSIX}"
to_win_path() {
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "$1"
	else
		printf '%s' "$1" | sed -E 's|^/([a-zA-Z])/(.*)|\1:/\2|; s|/|\\|g'
	fi
}
STAGE_WIN="$(to_win_path "${STAGE}")"
MSIX_WIN="$(to_win_path "${MSIX}")"
echo "[vendor-winui3-sparse] packing with ${MAKEAPPX} ..."
# MSYS2 converts /d to a drive path; makeappx needs literal /d and /p flags.
MSYS2_ARG_CONV_EXCL='*' "${MAKEAPPX}" pack /d "${STAGE_WIN}" /p "${MSIX_WIN}" /o /nv
echo "[vendor-winui3-sparse] OK -> ${MSIX}"
