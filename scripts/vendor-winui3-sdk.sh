#!/usr/bin/env bash
# Download Microsoft.WindowsAppSDK.WinUI NuGet (.nupkg is a zip) and stage
# WinUI3 metadata for native binding experiments.
#
# Staged layout (gitignored under build/vendor/winui3/):
#   metadata/Microsoft.UI.Xaml.winmd
#   metadata/Microsoft.UI.Text.winmd
#   include/microsoft.ui.xaml.window.h
#   include/microsoft.ui.xaml.hosting.referencetracker.h
#   include/microsoft.ui.xaml.media.dxinterop.h
#
# Linux/macOS, or invoked from Windows via:
#   msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/vendor-winui3-sdk.sh'
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF_FILE="${ROOT}/metadata/winui3-sdk-ref.txt"
VERSION="${WINUI3_SDK_VERSION:-}"
if [[ -z "${VERSION}" && -f "${REF_FILE}" ]]; then
	VERSION="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "${REF_FILE}")"
fi
VERSION="${VERSION:-2.1.0}"

VENDOR_DIR="${ROOT}/build/vendor"
NUPKG="${VENDOR_DIR}/winui3.nupkg"
OUT="${VENDOR_DIR}/winui3"
EXTRACT="$(mktemp -d "${TMPDIR:-/tmp}/winui3-extract.XXXXXX")"
trap 'rm -rf "${EXTRACT}"' EXIT
PKG_URL="https://www.nuget.org/api/v2/package/Microsoft.WindowsAppSDK.WinUI/${VERSION}"

mkdir -p "${VENDOR_DIR}"

if [[ ! -f "${NUPKG}" ]]; then
	echo "Downloading ${PKG_URL} ..."
	curl -fsSL --connect-timeout 60 -o "${NUPKG}" "${PKG_URL}"
else
	echo "Using cached ${NUPKG}"
fi

extract_nupkg() {
	mkdir -p "${EXTRACT}"
	if command -v unzip >/dev/null 2>&1; then
		unzip -q -o "${NUPKG}" -d "${EXTRACT}"
		return 0
	fi
	if tar -xf "${NUPKG}" -C "${EXTRACT}" 2>/dev/null; then
		return 0
	fi
	echo "error: need unzip to extract .nupkg (Windows: rerun setup-msys2-toolchain.sh or pacman -S unzip)" >&2
	exit 1
}

copy_required() {
	local from="$1"
	local to="$2"
	if [[ ! -f "${from}" ]]; then
		echo "error: package ${VERSION} missing ${from#${EXTRACT}/}" >&2
		exit 1
	fi
	cp -- "${from}" "${to}"
}

extract_nupkg

rm -rf "${OUT}"
mkdir -p "${OUT}/metadata" "${OUT}/include"

copy_required "${EXTRACT}/metadata/Microsoft.UI.Xaml.winmd" "${OUT}/metadata/"
copy_required "${EXTRACT}/metadata/Microsoft.UI.Text.winmd" "${OUT}/metadata/"
copy_required "${EXTRACT}/include/microsoft.ui.xaml.window.h" "${OUT}/include/"
copy_required "${EXTRACT}/include/microsoft.ui.xaml.hosting.referencetracker.h" "${OUT}/include/"
copy_required "${EXTRACT}/include/microsoft.ui.xaml.media.dxinterop.h" "${OUT}/include/"

cat > "${OUT}/VERSION.txt" <<EOF
Microsoft.WindowsAppSDK.WinUI NuGet ${VERSION}
staged $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "Staged WinUI3 SDK ${VERSION} -> ${OUT}"
echo "  metadata/Microsoft.UI.Xaml.winmd"
echo "  metadata/Microsoft.UI.Text.winmd"
echo "  include/microsoft.ui.xaml.window.h"
