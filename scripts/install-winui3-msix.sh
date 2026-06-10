#!/usr/bin/env bash
# Install staged Windows App Runtime MSIX packages (local C: disk only).
# Self-contained for C:\msys64\tmp\vala-win32-winui3-runtime\ copy.
# Log: C:\msys64\tmp\vala-win32-winui3-runtime\install.log
set -euo pipefail

DEFAULT_STAGING='/c/msys64/tmp/vala-win32-winui3-runtime'

_basename() {
	local s="${1//\\//}"
	s="${s%/}"
	printf '%s' "${s##*/}"
}

_script="${0//\\//}"
if [[ "${_script}" == */* ]]; then
	SCRIPT_DIR="${_script%/*}"
else
	SCRIPT_DIR="${DEFAULT_STAGING}"
fi
MSIX_DIR="${MSIX_DIR:-${SCRIPT_DIR}/msix/x64}"
LOG_FILE="${SCRIPT_DIR}/install.log"

_say() {
	printf '%s\n' "$*"
	printf '%s\n' "$*" >> "${LOG_FILE}"
}

_on_exit() {
	local ec=$?
	_say ""
	_say "=== finished exit ${ec} ==="
	_say "Log file: ${LOG_FILE}"
	if [[ -t 0 ]] && [[ -r /dev/tty ]]; then
		read -r -p "Press Enter to close... " _ </dev/tty 2>/dev/null || true
	fi
	exit "${ec}"
}
trap _on_exit EXIT

: > "${LOG_FILE}"
_say "=== install-winui3-msix started ==="
_say "SCRIPT_DIR=${SCRIPT_DIR}"
_say "MSIX_DIR=${MSIX_DIR}"

_to_win_path() {
	local path="${1//\\//}"
	if [[ "${path}" =~ ^/([a-zA-Z])/(.*)$ ]]; then
		local drive="${BASH_REMATCH[1]}"
		local rest="${BASH_REMATCH[2]//\//\\}"
		printf '%s:\\%s' "${drive^^}" "${rest}"
		return 0
	fi
	if [[ "${path}" =~ ^([A-Za-z]):(.*)$ ]]; then
		local drive="${BASH_REMATCH[1]}"
		local rest="${BASH_REMATCH[2]//\//\\}"
		rest="${rest#\\}"
		printf '%s:\\%s' "${drive^^}" "${rest}"
		return 0
	fi
	printf '%s' "${1}"
}

_add_appx() {
	local msix_win="$1"
	local msix_esc="${msix_win//\'/''}"
	_say "[install-winui3-msix] Add-AppxPackage $(_basename "${msix_win}")"
	if powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
		try {
			Add-AppxPackage -LiteralPath '${msix_esc}' -ForceUpdateFromAnyVersion -ErrorAction Stop
			exit 0
		} catch {
			Write-Host \$_.Exception.Message
			exit 1
		}
	"; then
		return 0
	fi
	_say "[install-winui3-msix] retry elevated: $(_basename "${msix_win}")"
	powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
		\$p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @(
			'-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
			\"Add-AppxPackage -LiteralPath '${msix_esc}' -ForceUpdateFromAnyVersion\"
		)
		if (\$null -eq \$p -or \$p.ExitCode -ne 0) { exit 1 } else { exit 0 }
	"
}

_msix_sort_key() {
	case "$(_basename "$1")" in
		*DDLM*) printf '3' ;;
		*Singleton*) printf '2' ;;
		*Main*) printf '1' ;;
		*) printf '0' ;;
	esac
}

shopt -s nullglob
_msix_files=("${MSIX_DIR}"/*.msix)
shopt -u nullglob

if [[ ${#_msix_files[@]} -eq 0 ]]; then
	_say "[install-winui3-msix] error: no .msix in ${MSIX_DIR}"
	_say "[install-winui3-msix] hint: run ./scripts/build-win.sh in MSYS2 first to stage MSIX"
	exit 1
fi

_say "[install-winui3-msix] found ${#_msix_files[@]} MSIX file(s)"

for _key in 0 1 2 3; do
	for _msix in "${_msix_files[@]}"; do
		if [[ "$(_msix_sort_key "${_msix}")" == "${_key}" ]]; then
			_add_appx "$(_to_win_path "${_msix}")"
		fi
	done
done

_say "[install-winui3-msix] OK"
