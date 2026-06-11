#!/usr/bin/env bash
# Download Windows App SDK / WinUI3 NuGet packages and stage native build inputs.
#
# Staged layout (gitignored under build/vendor/winui3/):
#   metadata/*.winmd
#   include/MddBootstrap.h, WindowsAppSDK-VersionInfo.h, …
#   lib/x64/Microsoft.WindowsAppRuntime.Bootstrap.lib
#   bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll
#   cppwinrt/winrt/Microsoft.UI.Xaml.h  (when cppwinrt + ref winmd are available)
#
# Cached under build/vendor/winui3-nupkgs/:
#   *.nupkg, extracted/<package>/  (unzip once per nupkg version)
#
# MSYS2 UCRT64: pacman -S mingw-w64-ucrt-x86_64-cppwinrt unzip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF_FILE="${ROOT}/metadata/winui3-sdk-ref.txt"
VENDOR_DIR="${ROOT}/build/vendor"
SHARE_OUT="${VENDOR_DIR}/winui3"
CACHE="${VENDOR_DIR}/winui3-nupkgs"
EXTRACT="${CACHE}/extracted"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/winui3-work.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

log_step() {
	echo "[vendor-winui3] $*" >&2
}

read_ref() {
	local pkg_id="$1"
	local fallback="$2"
	if [[ -f "${REF_FILE}" ]]; then
		local v
		v="$(awk -v id="${pkg_id}" '$1 == id { print $2; exit }' "${REF_FILE}")"
		if [[ -n "${v}" ]]; then
			echo "${v}"
			return 0
		fi
	fi
	echo "${fallback}"
}

WINUI_VERSION="$(read_ref Microsoft.WindowsAppSDK.WinUI "${WINUI3_SDK_VERSION:-2.1.0}")"
FOUNDATION_VERSION="$(read_ref Microsoft.WindowsAppSDK.Foundation 2.0.21)"
IX_VERSION="$(read_ref Microsoft.WindowsAppSDK.InteractiveExperiences 2.0.13)"
RUNTIME_VERSION="$(read_ref Microsoft.WindowsAppSDK.Runtime 2.1.3)"
WINDOWS_RS_VERSION="$(read_ref github.com/microsoft/windows-rs 70)"
WEBVIEW2_REF="${ROOT}/metadata/webview2-sdk-ref.txt"
WEBVIEW2_VERSION="${WEBVIEW2_SDK_VERSION:-}"
if [[ -z "${WEBVIEW2_VERSION}" && -f "${WEBVIEW2_REF}" ]]; then
	WEBVIEW2_VERSION="$(grep -v '^#' "${WEBVIEW2_REF}" | grep -v '^[[:space:]]*$' | head -1)"
fi
WEBVIEW2_VERSION="${WEBVIEW2_VERSION:-1.0.2792.45}"
VENDOR_STAMP="${WINUI_VERSION}|${FOUNDATION_VERSION}|${IX_VERSION}|${RUNTIME_VERSION}|${WINDOWS_RS_VERSION}|${WEBVIEW2_VERSION}|cppwinrt-full"

cppwinrt_headers_ready() {
	local base="${1:-${SHARE_OUT}}"
	[[ -f "${base}/cppwinrt/winrt/impl/Microsoft.UI.Xaml.Controls.1.h" ]] \
		&& [[ -f "${base}/cppwinrt/winrt/Microsoft.UI.Xaml.XamlTypeInfo.h" ]]
}

# Samba (X:) is slow for cppwinrt output — stage on local disk, copy back once.
if [[ -n "${WINUI3_VENDOR_LOCAL:-}" ]]; then
	OUT="${WINUI3_VENDOR_LOCAL}"
elif [[ "${ROOT}" == //* || "${ROOT}" == /[xX]/* ]]; then
	OUT="/c/msys64/tmp/vala-win32-vendor-winui3"
else
	OUT="${SHARE_OUT}"
fi

mkdir -p "${VENDOR_DIR}" "${CACHE}" "${EXTRACT}"

stamp_matches() {
	local file="$1"
	[[ -f "${file}" ]] && [[ "$(cat "${file}")" == "${VENDOR_STAMP}" ]]
}

vendor_complete() {
	stamp_matches "${SHARE_OUT}/.vendor-stamp" && cppwinrt_headers_ready "${SHARE_OUT}"
}

metadata_staged() {
	stamp_matches "${SHARE_OUT}/.metadata-stamp" \
		&& [[ -f "${SHARE_OUT}/include/MddBootstrap.h" ]] \
		&& [[ -f "${SHARE_OUT}/metadata/Microsoft.UI.Xaml.winmd" ]] \
		&& [[ -f "${SHARE_OUT}/metadata/Microsoft.Web.WebView2.Core.winmd" ]]
}

if vendor_complete; then
	log_step "already complete (stamp + cppwinrt headers OK) -> ${SHARE_OUT}"
	exit 0
fi

download_nupkg() {
	local pkg_id="$1"
	local version="$2"
	local slug="${pkg_id}.${version}.nupkg"
	local dest="${CACHE}/${slug}"
	if [[ ! -f "${dest}" ]]; then
		local url="https://www.nuget.org/api/v2/package/${pkg_id}/${version}"
		log_step "downloading ${pkg_id} ${version} ..."
		curl -fsSL --connect-timeout 60 -o "${dest}" "${url}"
	else
		log_step "using cached ${slug}"
	fi
	printf '%s\n' "${dest}"
}

extract_nupkg_cached() {
	local nupkg="$1"
	local dest="$2"
	local key
	key="$(basename "${nupkg}" .nupkg)"
	local cached="${EXTRACT}/${key}"
	if [[ -d "${cached}" && "${cached}" -nt "${nupkg}" ]]; then
		log_step "using cached extract ${key}"
		rm -rf "${dest}"
		mkdir -p "${dest}"
		cp -a "${cached}/." "${dest}/"
		return 0
	fi
	log_step "extracting ${key} (first time for this nupkg) ..."
	rm -rf "${dest}" "${cached}"
	mkdir -p "${dest}"
	if command -v unzip >/dev/null 2>&1; then
		unzip -q -o "${nupkg}" -d "${dest}"
	else
		tar -xf "${nupkg}" -C "${dest}" || {
			echo "error: need unzip to extract .nupkg" >&2
			exit 1
		}
	fi
	mkdir -p "${cached}"
	cp -a "${dest}/." "${cached}/"
}

copy_required() {
	local from="$1"
	local to="$2"
	if [[ ! -f "${from}" ]]; then
		echo "error: missing ${from}" >&2
		exit 1
	fi
	mkdir -p "$(dirname "${to}")"
	cp -- "${from}" "${to}"
}

refs_dir_valid() {
	local dir="$1"
	[[ -n "${dir}" && ( -f "${dir}/Windows.Foundation.winmd" || -f "${dir}/Windows.winmd" ) ]]
}

find_winmd_refs() {
	local candidate
	for candidate in \
		"${CPPWINRT_REFS:-}" \
		"${OUT}/refs" \
		"${SHARE_OUT}/refs" \
		"${MINGW_PREFIX:-/ucrt64}/share/CppWinRT/targets" \
		"/ucrt64/share/CppWinRT/targets" \
		"/c/Program Files (x86)/Windows Kits/10/UnionMetadata/"* \
		"/c/Program Files/Windows Kits/10/UnionMetadata/"*; do
		refs_dir_valid "${candidate}" || continue
		echo "${candidate}"
		return 0
	done
	return 1
}

stage_webview2_winmd() {
	local dest="${OUT}/metadata/Microsoft.Web.WebView2.Core.winmd"
	if [[ -f "${dest}" ]]; then
		return 0
	fi
	local nupkg="${VENDOR_DIR}/webview2.nupkg"
	if [[ ! -f "${nupkg}" ]]; then
		log_step "webview2.nupkg missing — downloading Microsoft.Web.WebView2 ${WEBVIEW2_VERSION} ..."
		nupkg="$(download_nupkg Microsoft.Web.WebView2 "${WEBVIEW2_VERSION}")"
		mkdir -p "${VENDOR_DIR}"
		cp -f "${nupkg}" "${VENDOR_DIR}/webview2.nupkg"
	fi
	local ex="${WORK}/webview2-winmd"
	extract_nupkg_cached "${nupkg}" "${ex}"
	local src=""
	for src in \
		"${ex}/lib/Microsoft.Web.WebView2.Core.winmd" \
		"${ex}/lib/uap10.0/Microsoft.Web.WebView2.Core.winmd"; do
		if [[ -f "${src}" ]]; then
			copy_required "${src}" "${dest}"
			log_step "staged Microsoft.Web.WebView2.Core.winmd (WebView2 ${WEBVIEW2_VERSION})"
			return 0
		fi
	done
	echo "error: Microsoft.Web.WebView2.Core.winmd not found in WebView2 nupkg" >&2
	exit 1
}

stage_windows_rs_refs() {
	local tarball="${CACHE}/windows-rs-${WINDOWS_RS_VERSION}.tar.gz"
	local extracted="${CACHE}/windows-rs-${WINDOWS_RS_VERSION}-refs"
	local bindgen="windows-rs-${WINDOWS_RS_VERSION}/crates/libs/bindgen/default"
	if [[ ! -f "${extracted}/Windows.winmd" ]]; then
		if [[ ! -f "${tarball}" ]]; then
			local url="https://github.com/microsoft/windows-rs/archive/${WINDOWS_RS_VERSION}/windows-rs-${WINDOWS_RS_VERSION}.tar.gz"
			log_step "downloading windows-rs ${WINDOWS_RS_VERSION} reference winmd ..."
			curl -fsSL --connect-timeout 60 -o "${tarball}" "${url}"
		else
			log_step "using cached windows-rs-${WINDOWS_RS_VERSION}.tar.gz"
		fi
		log_step "extracting windows-rs reference winmd (once) ..."
		rm -rf "${extracted}"
		mkdir -p "${extracted}"
		tar -xzf "${tarball}" -C "${extracted}" --strip-components=5 "${bindgen}"
	fi
	mkdir -p "${OUT}/refs"
	cp -f "${extracted}/"*.winmd "${OUT}/refs/"
}

stage_metadata_from_nupkgs() {
	local winui_ex="${WORK}/winui"
	local foundation_ex="${WORK}/foundation"
	local ix_ex="${WORK}/ix"
	local runtime_ex="${WORK}/runtime"

	WINUI_NUPKG="$(download_nupkg Microsoft.WindowsAppSDK.WinUI "${WINUI_VERSION}")"
	FOUNDATION_NUPKG="$(download_nupkg Microsoft.WindowsAppSDK.Foundation "${FOUNDATION_VERSION}")"
	IX_NUPKG="$(download_nupkg Microsoft.WindowsAppSDK.InteractiveExperiences "${IX_VERSION}")"
	RUNTIME_NUPKG="$(download_nupkg Microsoft.WindowsAppSDK.Runtime "${RUNTIME_VERSION}")"

	extract_nupkg_cached "${WINUI_NUPKG}" "${winui_ex}"
	extract_nupkg_cached "${FOUNDATION_NUPKG}" "${foundation_ex}"
	extract_nupkg_cached "${IX_NUPKG}" "${ix_ex}"
	extract_nupkg_cached "${RUNTIME_NUPKG}" "${runtime_ex}"

	log_step "writing metadata, headers, and libs ..."
	rm -rf "${OUT}"
	mkdir -p "${OUT}/metadata" "${OUT}/include" "${OUT}/lib/x64" "${OUT}/bin/x64" "${OUT}/cppwinrt"

	local ix_metadata="${ix_ex}/metadata/10.0.18362.0"
	if [[ ! -d "${ix_metadata}" ]]; then
		ix_metadata="${ix_ex}/metadata/10.0.17763.0"
	fi

	cp -f "${winui_ex}/metadata/"*.winmd "${OUT}/metadata/"
	cp -f "${foundation_ex}/metadata/"*.winmd "${OUT}/metadata/"
	cp -f "${ix_metadata}/"*.winmd "${OUT}/metadata/"
	stage_webview2_winmd
	copy_required "${winui_ex}/include/microsoft.ui.xaml.window.h" "${OUT}/include/"
	copy_required "${winui_ex}/include/microsoft.ui.xaml.hosting.referencetracker.h" "${OUT}/include/"
	copy_required "${winui_ex}/include/microsoft.ui.xaml.media.dxinterop.h" "${OUT}/include/"
	copy_required "${foundation_ex}/include/MddBootstrap.h" "${OUT}/include/"
	copy_required "${runtime_ex}/include/WindowsAppSDK-VersionInfo.h" "${OUT}/include/"
	copy_required "${foundation_ex}/lib/native/x64/Microsoft.WindowsAppRuntime.Bootstrap.lib" "${OUT}/lib/x64/"
	copy_required "${foundation_ex}/lib/native/x64/Microsoft.WindowsAppRuntime.lib" "${OUT}/lib/x64/"
	copy_required "${foundation_ex}/runtimes/win-x64/native/Microsoft.WindowsAppRuntime.Bootstrap.dll" "${OUT}/bin/x64/"

	stage_windows_rs_refs
	printf '%s\n' "${VENDOR_STAMP}" > "${OUT}/.metadata-stamp"
}

run_cppwinrt() {
	local ref_dir=""
	CPPWINRT_READY=0
	if ! command -v cppwinrt >/dev/null 2>&1; then
		echo "error: cppwinrt not found — install mingw-w64-ucrt-x86_64-cppwinrt" >&2
		exit 1
	fi
	if ! ref_dir="$(find_winmd_refs)"; then
		echo "error: cppwinrt found but no winmd refs (Windows.winmd)" >&2
		exit 1
	fi
	log_step "generating cppwinrt headers (refs: ${ref_dir}) — may take 1–3 min ..."
	rm -rf "${OUT}/cppwinrt"
	mkdir -p "${OUT}/cppwinrt"
	if cppwinrt \
		-input "${OUT}/metadata" \
		-reference "${ref_dir}" \
		-output "${OUT}/cppwinrt" \
		-component \
		-verbose; then
		if cppwinrt_headers_ready "${OUT}"; then
			CPPWINRT_READY=1
			log_step "cppwinrt headers ready"
		fi
	else
		echo "error: cppwinrt generation failed (see errors above)" >&2
		rm -rf "${OUT}/cppwinrt"
	fi
}

publish_to_share() {
	if [[ "${OUT}" == "${SHARE_OUT}" ]]; then
		return 0
	fi
	log_step "syncing staged SDK to ${SHARE_OUT} ..."
	rm -rf "${SHARE_OUT}"
	mkdir -p "${SHARE_OUT}"
	cp -a "${OUT}/." "${SHARE_OUT}/"
}

write_version_txt() {
	cat > "${OUT}/VERSION.txt" <<EOF
Microsoft.WindowsAppSDK.WinUI ${WINUI_VERSION}
Microsoft.WindowsAppSDK.Foundation ${FOUNDATION_VERSION}
Microsoft.WindowsAppSDK.InteractiveExperiences ${IX_VERSION}
Microsoft.WindowsAppSDK.Runtime ${RUNTIME_VERSION}
cppwinrt headers: $([[ "${CPPWINRT_READY:-0}" == 1 ]] && echo ready || echo missing)
staged $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

CPPWINRT_READY=0

# --- main: skip nupkg extract when metadata already on share ---
if metadata_staged; then
	log_step "metadata already staged — skipping nupkg extract, retrying cppwinrt only"
	rm -rf "${OUT}"
	mkdir -p "${OUT}"
	cp -a "${SHARE_OUT}/." "${OUT}/"
	stage_webview2_winmd
	run_cppwinrt
	if [[ "${CPPWINRT_READY:-0}" == 1 ]]; then
		printf '%s\n' "${VENDOR_STAMP}" > "${OUT}/.vendor-stamp"
	fi
	write_version_txt
	publish_to_share
else
	log_step "full stage -> ${OUT}"
	stage_metadata_from_nupkgs
	run_cppwinrt
	if [[ "${CPPWINRT_READY:-0}" == 1 ]]; then
		printf '%s\n' "${VENDOR_STAMP}" > "${OUT}/.vendor-stamp"
	fi
	write_version_txt
	publish_to_share
fi

if [[ "${CPPWINRT_READY:-0}" != 1 ]]; then
	echo "error: cppwinrt headers not ready — WinUI3 build cannot proceed" >&2
	exit 1
fi

echo "Staged WinUI3 SDK -> ${SHARE_OUT}"
echo "  cppwinrt/winrt/impl/Microsoft.UI.Xaml.Controls.1.h"
echo "  cppwinrt/winrt/Microsoft.UI.Xaml.XamlTypeInfo.h"
