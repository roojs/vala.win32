#!/usr/bin/env bash
# Embed application manifest into a built WinUI3 exe (replaces MinGW default manifest).
set -euo pipefail

if [[ $# -lt 2 ]]; then
	echo "usage: $0 <exe-path> <manifest-xml>" >&2
	exit 1
fi

EXE="$1"
MANIFEST="$2"

if [[ ! -f "${EXE}" ]]; then
	echo "[embed-winui3-manifest] error: exe not found: ${EXE}" >&2
	exit 1
fi
if [[ ! -f "${MANIFEST}" ]]; then
	echo "[embed-winui3-manifest] error: manifest not found: ${MANIFEST}" >&2
	exit 1
fi

find_mt() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/mt.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/mt.exe; do
		if [[ -f "${kit}" ]]; then
			printf '%s' "${kit}"
			return 0
		fi
	done
	return 1
}

MT="$(find_mt || true)"
if [[ -z "${MT}" ]]; then
	echo "[embed-winui3-manifest] error: mt.exe not found (install Windows 10 SDK)" >&2
	exit 1
fi

to_win_path() {
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "$1"
	else
		printf '%s' "$1" | sed -E 's|^/([a-zA-Z])/(.*)|\1:/\2|; s|/|\\|g'
	fi
}

# mt.exe cannot read manifests on UNC/Samba paths (X: / \\server\share).
exe_dir="$(dirname "${EXE}")"
MANIFEST_LOCAL="${exe_dir}/.embed-winui3.manifest.xml"
cp -f "${MANIFEST}" "${MANIFEST_LOCAL}"

EXE_WIN="$(to_win_path "${EXE}")"
MANIFEST_WIN="$(to_win_path "${MANIFEST_LOCAL}")"

echo "[embed-winui3-manifest] exe=${EXE}"
echo "[embed-winui3-manifest] manifest local copy=${MANIFEST_LOCAL}"
MSYS2_ARG_CONV_EXCL='*' "${MT}" -nologo \
	-manifest "${MANIFEST_WIN}" \
	-outputresource:"${EXE_WIN};#1"
rm -f "${MANIFEST_LOCAL}"
