#!/usr/bin/env bash
# Stage Windows App Runtime 2.1.x install inputs from Microsoft.WindowsAppSDK.Runtime NuGet.
#
# Microsoft.WindowsAppRuntime.Redist does not exist for 2.x on NuGet; the Runtime package
# ships tools/MSIX/win10-x64/*.msix (and sometimes WindowsAppRuntimeInstall.exe).
#
# Reuses build/vendor/winui3-nupkgs/ cache from vendor-winui3-sdk.sh when present.
#
# Output: build/vendor/winui3-runtime/
#   WindowsAppRuntimeInstall-x64.exe  (when present in nupkg)
#   msix/x64/*.msix                   (always staged when found)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF_FILE="${ROOT}/metadata/winui3-sdk-ref.txt"
VENDOR_DIR="${ROOT}/build/vendor"
WINUI3_NUPKG_CACHE="${VENDOR_DIR}/winui3-nupkgs"
OUT="${VENDOR_DIR}/winui3-runtime"
CACHE="${VENDOR_DIR}/winui3-runtime-nupkgs"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/winui3-runtime-work.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

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

RUNTIME_VERSION="$(read_ref Microsoft.WindowsAppSDK.Runtime 2.1.3)"
STAMP="${RUNTIME_VERSION}|runtime-nupkg"

if [[ -f "${OUT}/.vendor-stamp" && "$(cat "${OUT}/.vendor-stamp")" == "${STAMP}" ]]; then
	if [[ -d "${OUT}/msix/x64" ]] && compgen -G "${OUT}/msix/x64/*.msix" >/dev/null; then
		echo "[vendor-winui3-runtime] cached -> ${OUT}"
		exit 0
	fi
	if [[ -f "${OUT}/WindowsAppRuntimeInstall-x64.exe" ]]; then
		echo "[vendor-winui3-runtime] cached ${OUT}/WindowsAppRuntimeInstall-x64.exe"
		exit 0
	fi
fi

mkdir -p "${CACHE}" "${OUT}" "${OUT}/msix/x64"
slug="Microsoft.WindowsAppSDK.Runtime.${RUNTIME_VERSION}.nupkg"
nupkg="${CACHE}/${slug}"
shared="${WINUI3_NUPKG_CACHE}/${slug}"

if [[ -f "${shared}" ]]; then
	echo "[vendor-winui3-runtime] using ${shared}"
	cp -f "${shared}" "${nupkg}"
elif [[ ! -f "${nupkg}" ]]; then
	url="https://www.nuget.org/api/v2/package/Microsoft.WindowsAppSDK.Runtime/${RUNTIME_VERSION}"
	echo "[vendor-winui3-runtime] downloading ${url} ..."
	curl -fsSL --connect-timeout 120 -o "${nupkg}" "${url}"
else
	echo "[vendor-winui3-runtime] using cached ${slug}"
fi

rm -rf "${WORK}/extract"
mkdir -p "${WORK}/extract"
if command -v unzip >/dev/null 2>&1; then
	unzip -q -o "${nupkg}" -d "${WORK}/extract"
else
	tar -xf "${nupkg}" -C "${WORK}/extract"
fi

installer=""
while IFS= read -r -d '' path; do
	case "$(basename "${path}")" in
		*WindowsAppRuntimeInstall*x64*.exe|*WindowsAppRuntimeInstall*x64*.EXE)
			installer="${path}"
			break
			;;
	esac
done < <(find "${WORK}/extract" -iname '*WindowsAppRuntimeInstall*x64*.exe' -print0 2>/dev/null)

if [[ -z "${installer}" ]]; then
	while IFS= read -r -d '' path; do
		if [[ "${path}" == */x64/* ]] || [[ "$(basename "${path}")" =~ [Xx]64 ]]; then
			installer="${path}"
			break
		fi
	done < <(find "${WORK}/extract" -iname 'WindowsAppRuntimeInstall*.exe' -print0 2>/dev/null)
fi

msix_dir=""
for candidate in \
	"${WORK}/extract/tools/MSIX/win10-x64" \
	"${WORK}/extract/tools/MSIX/x64" \
	"${WORK}/extract/MSIX/x64"; do
	if [[ -d "${candidate}" ]] && compgen -G "${candidate}/*.msix" >/dev/null; then
		msix_dir="${candidate}"
		break
	fi
done

if [[ -z "${msix_dir}" ]]; then
	msix_dir="$(find "${WORK}/extract" -type d -path '*/MSIX/*x64*' 2>/dev/null | head -1)"
fi

rm -f "${OUT}/"*.exe
rm -rf "${OUT}/msix/x64"
mkdir -p "${OUT}/msix/x64"

staged=0
if [[ -n "${installer}" ]]; then
	cp -f "${installer}" "${OUT}/WindowsAppRuntimeInstall-x64.exe"
	staged=1
	echo "[vendor-winui3-runtime] staged installer -> ${OUT}/WindowsAppRuntimeInstall-x64.exe"
fi

if [[ -n "${msix_dir}" && -d "${msix_dir}" ]]; then
	cp -f "${msix_dir}/"*.msix "${OUT}/msix/x64/" 2>/dev/null || true
	if compgen -G "${OUT}/msix/x64/*.msix" >/dev/null; then
		staged=1
		echo "[vendor-winui3-runtime] staged MSIX packages -> ${OUT}/msix/x64/"
		ls -1 "${OUT}/msix/x64/"*.msix >&2
	fi
	[[ -f "${msix_dir}/MSIX.inventory" ]] && cp -f "${msix_dir}/MSIX.inventory" "${OUT}/msix/x64/"
fi

if [[ "${staged}" != 1 ]]; then
	echo "[vendor-winui3-runtime] error: no installer or MSIX found in Microsoft.WindowsAppSDK.Runtime ${RUNTIME_VERSION}" >&2
	find "${WORK}/extract" \( -iname '*.exe' -o -iname '*.msix' \) 2>/dev/null | head -30 >&2 || true
	exit 1
fi

printf '%s\n' "${STAMP}" > "${OUT}/.vendor-stamp"
cat > "${OUT}/VERSION.txt" <<EOF
Microsoft.WindowsAppSDK.Runtime ${RUNTIME_VERSION}
installer: $([[ -f "${OUT}/WindowsAppRuntimeInstall-x64.exe" ]] && echo yes || echo no)
msix x64: $(find "${OUT}/msix/x64" -maxdepth 1 -name '*.msix' 2>/dev/null | wc -l | tr -d ' ')
staged $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
