#!/usr/bin/env bash
# Regenerate vapi/win32-ui-webview2.vapi from metadata/webview2/api/WebView2.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build}"
JSON="${ROOT}/metadata/webview2/api/WebView2.json"

if [[ ! -f "${JSON}" ]]; then
	echo "Missing ${JSON} — run ./scripts/regen-webview2-json.sh first" >&2
	exit 1
fi

if [[ ! -x "${BUILD_DIR}/generate-binding" ]]; then
	meson setup "${BUILD_DIR}" 2>/dev/null || true
	meson compile -C "${BUILD_DIR}" generate-binding
fi

"${BUILD_DIR}/generate-binding" \
	--metadata "${ROOT}/metadata/webview2" \
	--filter "${ROOT}/metadata/filters/webview2.filter" \
	--api-list "${ROOT}/metadata/webview2-api.files" \
	--out "${ROOT}/vapi" \
	--symbol-prefix Microsoft.Web.WebView2.Win32 \
	--no-basename-in-symbol \
	--cheader win32-ui-webview2-sdk.h \
	--vala-namespace Microsoft.Web.WebView2.Win32 \
	--vapi-only

echo "Done. Commit vapi/win32-ui-webview2.vapi"
