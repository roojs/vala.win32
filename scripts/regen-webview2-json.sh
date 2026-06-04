#!/usr/bin/env bash
# Regenerate metadata/webview2/api/WebView2.json (win32json shape) on Windows MSYS2.
#
# Bash + Vala only (no PowerShell, no Python). Uses vendored WebView2.h from the pinned NuGet.
# Optional: BUILD_WINMD=1 also builds Microsoft.Web.WebView2.Win32.winmd (needs dotnet + pwsh).
#
# One line from Windows:
#   C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/regen-webview2-json.sh'
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEADER="${ROOT}/build/vendor/webview2/include/WebView2.h"
OUT_JSON="${ROOT}/metadata/webview2/api/WebView2.json"
WINMD_OUT="${ROOT}/metadata/webview2/Microsoft.Web.WebView2.Win32.winmd"
WIN32MD_DIR="${ROOT}/build/vendor/webview2-win32md"
REF_FILE="${ROOT}/metadata/webview2-sdk-ref.txt"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build}"

ensure_tool() {
	if [[ ! -x "${BUILD_DIR}/generate-webview2-json" ]]; then
		echo "Building generate-webview2-json ..."
		meson compile -C "${BUILD_DIR}" generate-webview2-json
	fi
}

ensure_header() {
	if [[ ! -f "${HEADER}" ]]; then
		echo "Vendoring WebView2 SDK ..."
		"${ROOT}/scripts/vendor-webview2-sdk.sh"
	fi
	if [[ ! -f "${HEADER}" ]]; then
		echo "Missing ${HEADER}" >&2
		exit 1
	fi
}

maybe_build_winmd() {
	if [[ "${BUILD_WINMD:-0}" != "1" ]]; then
		return 0
	fi
	if ! command -v dotnet >/dev/null 2>&1; then
		echo "BUILD_WINMD=1 but dotnet not in PATH" >&2
		exit 1
	fi
	if ! command -v pwsh >/dev/null 2>&1; then
		echo "BUILD_WINMD=1 needs pwsh (pacman -S mingw-w64-ucrt-x86_64-powershell)" >&2
		exit 1
	fi
	local shim_dir
	shim_dir="$(mktemp -d "${TMPDIR:-/tmp}/wv2-pshim.XXXXXX")"
	printf '%s\n' '#!/usr/bin/env bash' 'exec pwsh "$@"' > "${shim_dir}/powershell.exe"
	chmod +x "${shim_dir}/powershell.exe"
	export PATH="${shim_dir}:${PATH}"

	if [[ ! -d "${WIN32MD_DIR}/.git" ]]; then
		mkdir -p "${ROOT}/build/vendor"
		git clone --depth 1 https://github.com/wravery/webview2-win32md.git "${WIN32MD_DIR}"
	fi

	local notargets="${HOME}/.nuget/packages/microsoft.build.notargets/3.0.4/Sdk"
	if [[ -d "${notargets}" && ! -f "${notargets}/sdk.props" ]]; then
		ln -sf Sdk.props "${notargets}/sdk.props" 2>/dev/null || true
		ln -sf Sdk.targets "${notargets}/sdk.targets" 2>/dev/null || true
	fi

	echo "Building Win32.winmd (webview2-win32md) ..."
	( cd "${WIN32MD_DIR}" && dotnet build -v minimal )
	local built="${WIN32MD_DIR}/bin/Microsoft.Web.WebView2.Win32.winmd"
	if [[ ! -f "${built}" ]]; then
		echo "WinMD build failed; expected ${built}" >&2
		exit 1
	fi
	mkdir -p "$(dirname "${WINMD_OUT}")"
	cp -f "${built}" "${WINMD_OUT}"
	echo "Copied WinMD -> ${WINMD_OUT}"
	rm -rf "${shim_dir}"
}

emit_json() {
	local version
	version="$(grep -v '^#' "${REF_FILE}" | grep -v '^[[:space:]]*$' | head -1)"
	echo "Scraping WebView2.h (SDK ${version}) -> ${OUT_JSON}"
	"${BUILD_DIR}/generate-webview2-json" \
		--header "${HEADER}" \
		--out "${OUT_JSON}" \
		--prefix ICoreWebView2
}

write_readme_stamp() {
	local readme="${ROOT}/metadata/webview2/README.md"
	local version
	version="$(grep -v '^#' "${REF_FILE}" | grep -v '^[[:space:]]*$' | head -1)"
	if [[ -f "${readme}" ]]; then
		sed -i "s/^Last regenerated against SDK.*/Last regenerated against SDK pin **${version}**./" "${readme}" 2>/dev/null || true
	fi
}

main() {
	ensure_header
	ensure_tool
	maybe_build_winmd
	emit_json
	write_readme_stamp
	echo "Done. Commit metadata/webview2/api/WebView2.json"
}

main "$@"
