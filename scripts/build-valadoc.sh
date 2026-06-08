#!/usr/bin/env bash
# Build browsable Valadoc HTML for the generated vala.win32 widget API.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build}"
OUT_DIR="${OUT_DIR:-${BUILD_DIR}/docs/valadoc}"
PACKAGE_VERSION="${PACKAGE_VERSION:-0.1.0}"

usage() {
	cat <<'USAGE'
Usage: scripts/build-valadoc.sh [--build-dir DIR] [--output-dir DIR] [--package-version VERSION]

Build Valadoc HTML for the generated Win32 widget bundle.

Environment:
  VALADOC           Valadoc executable to run (default: valadoc)
  BUILD_DIR         Build directory used to derive the default output path
  OUT_DIR           Output directory (default: $BUILD_DIR/docs/valadoc)
  PACKAGE_VERSION   Version shown in Valadoc output
USAGE
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--build-dir)
			BUILD_DIR="$2"
			shift 2
			;;
		--output-dir)
			OUT_DIR="$2"
			shift 2
			;;
		--package-version)
			PACKAGE_VERSION="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

VALADOC="${VALADOC:-valadoc}"
if ! command -v "${VALADOC}" >/dev/null 2>&1; then
	echo "valadoc was not found. Install the Vala documentation tool, then rerun this command." >&2
	exit 127
fi

mkdir -p "${OUT_DIR}"
rm -rf "${OUT_DIR:?}/"*

exec "${VALADOC}" \
	--force \
	--directory="${OUT_DIR}" \
	--package-name=vala.win32 \
	--package-version="${PACKAGE_VERSION}" \
	--vapidir="${ROOT}/vapi" \
	--pkg=glib-2.0 \
	--pkg=gobject-2.0 \
	--pkg=win32-foundation-stub \
	--pkg=win32-system-stub \
	--pkg=win32-graphics-gdi \
	--pkg=win32-ui-windowsandmessaging \
	--pkg=win32-ui-controls \
	--pkg=win32-ui-controls-dialogs \
	"${ROOT}/generated/win32-wide-strings.vala" \
	"${ROOT}/generated/win32-ui-control-strings.vala" \
	"${ROOT}/generated/win32-errors.vala" \
	"${ROOT}/generated/win32-widgets.vala"
