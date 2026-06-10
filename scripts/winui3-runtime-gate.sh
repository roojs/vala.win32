# Shared WinUI3 runtime gate helpers (source from bash; do not execute).
#
# Paste-into-PowerShell instructions appear ONLY when the build stops (WINUI3-RUNTIME-STOP.txt).
# Bash uses inline powershell.exe for Get-AppxPackage checks and silent MSIX install attempts.

: "${ROOT:?ROOT must be set before sourcing winui3-runtime-gate.sh}"

WINUI3_RUNTIME_STOP_FILE="${ROOT}/build-win/WINUI3-RUNTIME-STOP.txt"
WINUI3_ADMIN_STAGING="${WINUI3_ADMIN_STAGING:-/c/msys64/tmp/vala-win32-winui3-runtime}"
WINUI3_REPO_MSYS="${ROOT}"

to_win_path() {
	local path="$1"
	if [[ "${path}" =~ ^/([a-zA-Z])/(.*)$ ]]; then
		local drive="${BASH_REMATCH[1]}"
		local rest="${BASH_REMATCH[2]//\//\\}"
		printf '%s:\\%s' "${drive^^}" "${rest}"
		return 0
	fi
	if [[ "${path}" =~ ^[A-Za-z]: ]]; then
		printf '%s' "${path}" | sed 's|/|\\|g'
		return 0
	fi
	if command -v cygpath >/dev/null 2>&1; then
		cygpath -w "${path}"
		return 0
	fi
	printf '%s' "${path}"
}

winui3_ps() {
	powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$@"
}

# WinApp SDK 2.x registers Main/Singleton as MicrosoftCorporationII.WinAppRuntime.* (not
# Microsoft.WindowsAppRuntime.Main*). See specs/Deployment/MSIXPackages.md in WindowsAppSDK.
winui3_runtime_packages_ps() {
	cat <<'EOF'
		$ErrorActionPreference = 'SilentlyContinue'
		$arch = { $_.Architecture -eq 'X64' -or $_.Architecture -eq 64 }
		$pkgs = @(
			Get-AppxPackage -Name '*WindowsAppRuntime*' | Where-Object $arch
			Get-AppxPackage -Name '*WinAppRuntime*' | Where-Object $arch
		) | Sort-Object Name -Unique
EOF
}

winui3_has_framework() {
	winui3_ps "$(winui3_runtime_packages_ps)
		if (\$pkgs | Where-Object { \$_.Name -eq 'Microsoft.WindowsAppRuntime.2' }) { exit 0 }
		exit 1
	"
}

winui3_has_main_package() {
	winui3_ps "$(winui3_runtime_packages_ps)
		if (\$pkgs | Where-Object {
			\$_.Name -like 'MicrosoftCorporationII.WinAppRuntime.Main*' -or
			\$_.Name -like 'Microsoft.WindowsAppRuntime.Main*'
		}) { exit 0 }
		exit 1
	"
}

winui3_has_singleton_package() {
	winui3_ps "$(winui3_runtime_packages_ps)
		if (\$pkgs | Where-Object {
			\$_.Name -like 'MicrosoftCorporationII.WinAppRuntime.Singleton*' -or
			\$_.Name -like 'Microsoft.WindowsAppRuntime.Singleton*'
		}) { exit 0 }
		exit 1
	"
}

winui3_list_runtime_package_names() {
	winui3_ps "$(winui3_runtime_packages_ps)
		\$pkgs | Select-Object -ExpandProperty Name
	" 2>/dev/null || true
}

winui3_widgets_ready() {
	winui3_has_framework && winui3_has_main_package && winui3_has_singleton_package
}

winui3_log_runtime_status() {
	local pkg
	echo "[winui3-runtime] installed x64 packages:"
	while IFS= read -r pkg; do
		[[ -z "${pkg}" ]] && continue
		echo "[winui3-runtime]   ${pkg}"
	done < <(winui3_list_runtime_package_names)
	if winui3_widgets_ready; then
		echo "[winui3-runtime] framework + Main + Singleton detected"
	else
		echo "[winui3-runtime] warning: incomplete runtime (winui3-hello may work; themed controls need Main + Singleton)"
	fi
}

winui3_msix_sort_key() {
	case "$(basename "$1")" in
		*DDLM*) printf '3' ;;
		*Singleton*) printf '2' ;;
		*Main*) printf '1' ;;
		*) printf '0' ;;
	esac
}

# MSIX fallback: explicit Add-AppxPackage commands (order computed in bash).
winui3_msix_powershell_line() {
	local msix_dir="${WINUI3_ADMIN_STAGING}/msix/x64"
	local -a files=()
	local f key k win line=''

	shopt -s nullglob
	for f in "${msix_dir}"/*.msix; do
		files+=("${f}")
	done
	shopt -u nullglob

	if [[ ${#files[@]} -eq 0 ]]; then
		printf "Write-Error 'No MSIX in %s. Run ./scripts/build-win.sh in MSYS2 first.'\n" \
			"$(to_win_path "${msix_dir}")"
		return 1
	fi

	for k in 0 1 2 3; do
		for f in "${files[@]}"; do
			key="$(winui3_msix_sort_key "${f}")"
			if [[ "${key}" == "${k}" ]]; then
				win="$(to_win_path "${f}")"
				if [[ -n "${line}" ]]; then
					line="${line}; "
				fi
				line="${line}Add-AppxPackage '${win}' -ForceUpdateFromAnyVersion"
			fi
		done
	done

	printf '%s\n' "${line}"
}

# Single line to paste into PowerShell (C: paths only; no X: drive).
winui3_install_powershell_line() {
	local stage_win
	stage_win="$(to_win_path "${WINUI3_ADMIN_STAGING}")"
	if [[ -f "${WINUI3_ADMIN_STAGING}/WindowsAppRuntimeInstall-x64.exe" ]]; then
		printf "Start-Process '%s\\WindowsAppRuntimeInstall-x64.exe' -ArgumentList '--quiet --force' -Verb RunAs -Wait\n" "${stage_win}"
		return 0
	fi
	winui3_msix_powershell_line
}

clear_winui3_runtime_stop() {
	mkdir -p "${ROOT}/build-win"
	rm -f "${WINUI3_RUNTIME_STOP_FILE}"
}

write_winui3_stop_banner() {
	local -a missing=("$@")
	local install_line
	install_line="$(winui3_install_powershell_line)"

	mkdir -p "${ROOT}/build-win"
	{
		echo '================================================================================'
		echo 'BUILD STOPPED: Windows App Runtime incomplete for winui3-widgets-native'
		echo '================================================================================'
		echo ''
		if [[ ${#missing[@]} -gt 0 ]]; then
			echo 'Missing packages:'
			for m in "${missing[@]}"; do
				echo "  - ${m}"
			done
			echo ''
		fi
		echo 'Installed x64 runtime packages detected on this machine:'
		local pkg
		while IFS= read -r pkg; do
			[[ -z "${pkg}" ]] && continue
			echo "  - ${pkg}"
		done < <(winui3_list_runtime_package_names)
		echo ''
		echo 'Paste this ONE line into PowerShell (UAC may prompt):'
		echo ''
		printf '%s' "${install_line}"
		echo 'Then in your MSYS2 UCRT64 window:'
		echo "  cd ${WINUI3_REPO_MSYS}"
		echo '  ./scripts/build-win.sh'
		echo ''
		echo 'Skip WinUI3 widgets (other demos only):'
		echo '  WINUI3_SKIP_RUNTIME_INSTALL=1 ./scripts/build-win.sh'
		echo ''
		echo '================================================================================'
		echo ''
	} > "${WINUI3_RUNTIME_STOP_FILE}"

	emit_winui3_runtime_stop || true
}

emit_winui3_runtime_stop() {
	if [[ ! -f "${WINUI3_RUNTIME_STOP_FILE}" ]]; then
		return 1
	fi
	{
		echo ''
		echo '--- PASTE INTO POWERSHELL ---'
		winui3_install_powershell_line
		echo '--- end ---'
		echo ''
		cat "${WINUI3_RUNTIME_STOP_FILE}"
		echo ''
		echo "[build-win] STOPPED: see build-win/WINUI3-RUNTIME-STOP.txt"
		echo ''
	} >&2
	return 0
}

winui3_runtime_gate_failed() {
	[[ -f "${WINUI3_RUNTIME_STOP_FILE}" ]]
}

stage_winui3_runtime_for_admin() {
	local vendor="${ROOT}/build/vendor/winui3-runtime"
	local msix_src="${vendor}/msix/x64"
	local stage="${WINUI3_ADMIN_STAGING}"

	mkdir -p "${stage}/msix/x64"

	if compgen -G "${msix_src}/*.msix" >/dev/null; then
		cp -f "${msix_src}/"*.msix "${stage}/msix/x64/"
	else
		echo "[winui3-runtime] warning: no MSIX under ${msix_src}" >&2
		return 1
	fi

	if [[ -f "${vendor}/WindowsAppRuntimeInstall-x64.exe" ]]; then
		cp -f "${vendor}/WindowsAppRuntimeInstall-x64.exe" "${stage}/"
	fi

	return 0
}

winui3_install_staged_msix() {
	local msix_dir="${WINUI3_ADMIN_STAGING}/msix/x64"
	local -a files=()
	local f key k win esc

	if ! compgen -G "${msix_dir}/*.msix" >/dev/null; then
		return 1
	fi

	shopt -s nullglob
	for f in "${msix_dir}"/*.msix; do
		files+=("${f}")
	done
	shopt -u nullglob

	for k in 0 1 2 3; do
		for f in "${files[@]}"; do
			key="$(winui3_msix_sort_key "${f}")"
			if [[ "${key}" != "${k}" ]]; then
				continue
			fi
			win="$(to_win_path "${f}")"
			esc="${win//\'/\'\'}"
			echo "[install-winui3-runtime] Add-AppxPackage $(basename "${f}")"
			if ! winui3_ps "Add-AppxPackage -LiteralPath '${esc}' -ForceUpdateFromAnyVersion"; then
				return 1
			fi
		done
	done

	return 0
}

winui3_try_install_runtime() {
	if winui3_widgets_ready; then
		return 0
	fi

	stage_winui3_runtime_for_admin || return 1

	local exe="${WINUI3_ADMIN_STAGING}/WindowsAppRuntimeInstall-x64.exe"
	if [[ -f "${exe}" ]]; then
		echo "[install-winui3-runtime] running WindowsAppRuntimeInstall-x64.exe ..."
		if "$(to_win_path "${exe}")" --quiet --force; then
			winui3_widgets_ready && return 0
		fi
	fi

	echo "[install-winui3-runtime] trying MSIX packages ..."
	winui3_install_staged_msix || true
	winui3_widgets_ready
}

winui3_stop_missing_packages() {
	local -a missing=()
	if ! winui3_has_framework; then
		missing+=('Microsoft.WindowsAppRuntime.2 (x64) framework')
	fi
	if ! winui3_has_main_package; then
		missing+=('MicrosoftCorporationII.WinAppRuntime.Main.* (x64)')
	fi
	if ! winui3_has_singleton_package; then
		missing+=('MicrosoftCorporationII.WinAppRuntime.Singleton (x64)')
	fi
	stage_winui3_runtime_for_admin || true
	write_winui3_stop_banner "${missing[@]}"
	exit 1
}

require_winui3_widgets_runtime() {
	if [[ "${WINUI3_SKIP_RUNTIME_INSTALL:-}" == 1 ]]; then
		echo "[build-win] WinUI3 runtime check skipped (WINUI3_SKIP_RUNTIME_INSTALL=1)"
		return 0
	fi

	clear_winui3_runtime_stop
	winui3_log_runtime_status
	return 0
}
