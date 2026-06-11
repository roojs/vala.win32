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

# Pack/sign on C: first — Samba (X:) breaks rm/makeappx output and signing tools.
LOCAL_MSIX="${LOCAL_SPARSE_MSIX:-/c/msys64/tmp/vala.win32.winui3.sparse.msix}"
MSIX="${OUT}/vala.win32.winui3.sparse.msix"
mkdir -p "${OUT}"
rm -f "${LOCAL_MSIX}" 2>/dev/null || true
to_win_path() {
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "$1"
	else
		printf '%s' "$1" | sed -E 's|^/([a-zA-Z])/(.*)|\1:/\2|; s|/|\\|g'
	fi
}
STAGE_WIN="$(to_win_path "${STAGE}")"
LOCAL_MSIX_WIN="$(to_win_path "${LOCAL_MSIX}")"
echo "[vendor-winui3-sparse] packing with ${MAKEAPPX} ..."
# MSYS2 converts /d to a drive path; makeappx needs literal /d and /p flags.
MSYS2_ARG_CONV_EXCL='*' "${MAKEAPPX}" pack /d "${STAGE_WIN}" /p "${LOCAL_MSIX_WIN}" /o /nv
"${ROOT}/scripts/sign-winui3-sparse.sh" "${LOCAL_MSIX}"
cp -f "${LOCAL_MSIX}" "${MSIX}"
echo "[vendor-winui3-sparse] OK -> ${MSIX}"
