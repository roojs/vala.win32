#!/usr/bin/env bash
# Pre-run checks for WinUI3 demos in build-win/ (no GUI launch).
#
# Run on Windows UCRT64 after build (or via agent-remote-build.sh validate):
#   ./scripts/validate-winui3-build-win.sh
#
# Writes build-win/YOUR-TASKS.txt (user steps) and WINUI3-VALIDATION.txt (details).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

BUILD_WIN="${1:-${ROOT}/build-win}"
REPORT="${BUILD_WIN}/WINUI3-VALIDATION.txt"
USER_TASKS="${BUILD_WIN}/YOUR-TASKS.txt"
WINUI3_LAYER="${WINUI3_LAYER:-hello}"
WINUI3_EXES=(winui3-hello-native.exe)
EXE_RUN='C:\msys64\tmp\vala.win32\build-win\winui3-hello-native.exe'
if [[ "${WINUI3_LAYER}" == widgets || "${WINUI3_LAYER}" == sparse ]]; then
	WINUI3_EXES=(winui3-widgets-native.exe)
	EXE_RUN='C:\msys64\tmp\vala.win32\build-win\winui3-widgets-native.exe'
fi
SPARSE_MSIX="${BUILD_WIN}/vala.win32.winui3.sparse.msix"
BOOTSTRAP_DLL="${BUILD_WIN}/Microsoft.WindowsAppRuntime.Bootstrap.dll"
STORE_LOGO="${BUILD_WIN}/Assets/StoreLogo.png"
SPARSE_PACKAGE='vala.win32.WinUI3'

errors=()
warnings=()
oks=()
sparse_registered=0
msix_signed_ok=0

log_ok() { oks+=("$1"); }
log_warn() { warnings+=("$1"); }
log_err() { errors+=("$1"); }

find_mt() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/mt.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/mt.exe; do
		[[ -f "${kit}" ]] || continue
		printf '%s' "${kit}"
		return 0
	done
	return 1
}

find_signtool() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/signtool.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/signtool.exe; do
		[[ -f "${kit}" ]] || continue
		printf '%s' "${kit}"
		return 0
	done
	return 1
}

check_pe_header() {
	local exe="$1"
	local magic
	magic="$(head -c 2 "${exe}" | od -An -tx1 | tr -d ' \n')"
	if [[ "${magic}" != "4d5a" ]]; then
		log_err "${exe}: not a PE file (missing MZ header)"
		return 1
	fi
	log_ok "${exe}: PE header MZ OK"
	if command -v objdump >/dev/null 2>&1; then
		if objdump -f "${exe}" 2>/dev/null | grep -qE 'file format pei-x86-64|x86-64'; then
			log_ok "${exe}: objdump architecture x86-64"
		fi
	fi
}

check_embedded_manifest() {
	local exe="$1"
	local mt="$2"
	local tmp manifest_win exe_win
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/winui3-val-manifest.XXXXXX")"
	trap 'rm -rf "${tmp}"' RETURN
	manifest_win="$(to_win_path "${tmp}/extracted.manifest")"
	exe_win="$(to_win_path "${exe}")"
	if ! MSYS2_ARG_CONV_EXCL='*' "${mt}" -nologo \
		-inputresource:"${exe_win};#1" \
		-out:"${manifest_win}" >/dev/null 2>&1; then
		log_err "${exe}: no embedded application manifest (mt.exe #1 failed)"
		return 1
	fi
	if [[ ! -f "${tmp}/extracted.manifest" ]]; then
		log_err "${exe}: manifest extract produced no file"
		return 1
	fi
	if ! grep -q '<msix' "${tmp}/extracted.manifest"; then
		log_err "${exe}: embedded manifest missing <msix> (sparse identity)"
		return 1
	fi
	if grep -q 'urn:schemas-microsoft-com:msix.v1' "${tmp}/extracted.manifest"; then
		: # msix.v1 (d801516 experiment)
	elif grep -q 'urn:schemas-microsoft-com:asm.v3' "${tmp}/extracted.manifest"; then
		: # asm.v3 child elements (f9bad4e labels milestone)
	else
		log_err "${exe}: embedded <msix> needs msix.v1 or asm.v3 namespace (SxS at launch)"
		return 1
	fi
	if ! grep -q "${SPARSE_PACKAGE}" "${tmp}/extracted.manifest"; then
		log_err "${exe}: embedded manifest missing packageName ${SPARSE_PACKAGE}"
		return 1
	fi
	log_ok "${exe}: embedded <msix> manifest OK (${SPARSE_PACKAGE})"
}

check_sparse_msix() {
	local signtool="$1"
	if [[ ! -f "${SPARSE_MSIX}" ]]; then
		log_err "missing ${SPARSE_MSIX}"
		return 1
	fi
	local size
	size="$(wc -c < "${SPARSE_MSIX}" | tr -d ' ')"
	if [[ "${size}" -lt 500 ]]; then
		log_err "sparse MSIX suspiciously small (${size} bytes)"
		return 1
	fi
	log_ok "sparse MSIX present (${size} bytes)"
	if [[ -n "${signtool}" ]]; then
		local msix_win
		msix_win="$(to_win_path "${SPARSE_MSIX}")"
		if MSYS2_ARG_CONV_EXCL='*' "${signtool}" verify /pa "${msix_win}" >/dev/null 2>&1; then
			msix_signed_ok=1
			log_ok "sparse MSIX signature verifies (/pa)"
		else
			log_warn "sparse MSIX signtool /pa failed (self-signed OK if cert in user Root store)"
		fi
	fi
}

check_sparse_registered() {
	local out rc=0
	if ! command -v powershell.exe >/dev/null 2>&1; then
		log_warn "powershell.exe not found; cannot check sparse registration"
		return 0
	fi
	if command -v timeout >/dev/null 2>&1; then
		out="$(timeout 20 powershell.exe -NoProfile -NonInteractive -Command \
			"(Get-AppxPackage -Name '${SPARSE_PACKAGE}' -ErrorAction SilentlyContinue | Select-Object -First 1).PackageFullName" \
			2>&1)" || rc=$?
	else
		out="$(powershell.exe -NoProfile -NonInteractive -Command \
			"(Get-AppxPackage -Name '${SPARSE_PACKAGE}' -ErrorAction SilentlyContinue | Select-Object -First 1).PackageFullName" \
			2>&1)" || rc=$?
	fi
	if [[ "${rc}" -eq 124 ]]; then
		log_warn "sparse registration check timed out (run Add-AppxPackage locally)"
		return 0
	fi
	out="$(echo "${out}" | tr -d '\r' | head -1)"
	if [[ -n "${out}" && "${out}" != " " ]]; then
		sparse_registered=1
		log_ok "sparse package registered: ${out}"
	else
		log_warn "sparse package NOT registered — exe will fail SxS until Add-AppxPackage"
	fi
}

write_user_tasks() {
	local dir_win msix_win register_line cert_path step=1
	mkdir -p "${BUILD_WIN}"
	dir_win="$(to_win_path "${BUILD_WIN}")"
	msix_win="${dir_win}\\vala.win32.winui3.sparse.msix"
	register_line="Add-AppxPackage -Path '${msix_win}' -ExternalLocation '${dir_win}' -ForceUpdateFromAnyVersion"
	cert_path='C:\msys64\tmp\vala.win32\build-win\vala.win32.sparse.cer'
	if [[ ! -f "${BUILD_WIN}/vala.win32.sparse.cer" ]]; then
		cert_path='C:\msys64\tmp\vala.win32\build\vendor\winui3-sparse\vala.win32.sparse.cer'
	fi

	{
		echo 'WINUI3 — your tasks on Windows'
		echo '================================'
		echo ''

		if [[ ${#errors[@]} -gt 0 ]]; then
			echo '>>> DO NOT RUN THE EXE — build is broken <<<'
			echo ''
			echo 'Tell the agent the build failed. Details: build-win/WINUI3-VALIDATION.txt'
			echo ''
		elif [[ "${WINUI3_LAYER}" == hello ]]; then
			echo '>>> HELLO LAYER (cf233c0) — no sparse register <<<'
			echo ''
			echo 'Run interactively on Windows:'
			echo ''
			echo "   ${EXE_RUN}"
			echo ''
		elif [[ "${WINUI3_LAYER}" == widgets ]]; then
			echo '>>> WIDGETS LAYER (f9bad4e) — labels only, themed=0 (no TextBox/Button) <<<'
			echo ''
			if [[ "${sparse_registered}" -eq 0 ]]; then
				echo 'Sparse register pending — agent: ./scripts/agent-remote-build.sh setup'
				echo ''
			fi
			echo 'Run interactively on Windows:'
			echo ''
			echo "   ${EXE_RUN}"
			echo '   Expect log: OnLaunched complete (themed=0)'
			echo ''
		elif [[ "${sparse_registered}" -eq 0 ]]; then
			if [[ "${AGENT_REMOTE_BUILD:-}" == 1 ]]; then
				echo '>>> Agent will trust cert + register via SSH <<<'
				echo ''
				echo 'Re-run from Linux: ./scripts/agent-remote-build.sh setup'
				echo 'Or full cycle:     ./scripts/agent-remote-build.sh build'
				echo ''
			else
				echo '>>> Manual setup required (non-agent build) <<<'
				echo ''
				echo 'See docs/windows-winui3.md — or use agent:'
				echo '  ./scripts/agent-remote-build.sh setup'
				echo ''
			fi
			echo "${step}. Run the demo (optional — agent can run via SSH):"
			echo ''
			echo "   ${EXE_RUN}"
			echo ''
		else
			echo '>>> READY (build + register checks passed) <<<'
			echo ''
			echo 'Launch may still fail SxS — see docs/windows-winui3-status.md before assuming done.'
			echo ''
			echo 'Optional local UI run:'
			echo ''
			echo "   ${EXE_RUN}"
			echo ''
			echo 'Agent log pull: ./scripts/agent-remote-build.sh pull'
			echo ''
		fi
	} > "${USER_TASKS}"
	rm -f "${BUILD_WIN}/WINUI3-REGISTER-FIRST.txt" 2>/dev/null || true
}

write_report() {
	mkdir -p "${BUILD_WIN}"
	{
		echo "WinUI3 build-win validation — $(date -Iseconds)"
		echo "BUILD_WIN=${BUILD_WIN}"
		echo ""
		if [[ ${#oks[@]} -gt 0 ]]; then
			echo "OK (${#oks[@]}):"
			printf '  %s\n' "${oks[@]}"
			echo ""
		fi
		if [[ ${#warnings[@]} -gt 0 ]]; then
			echo "WARN (${#warnings[@]}):"
			printf '  %s\n' "${warnings[@]}"
			echo ""
		fi
		if [[ ${#errors[@]} -gt 0 ]]; then
			echo "ERROR (${#errors[@]}):"
			printf '  %s\n' "${errors[@]}"
			echo ""
		fi
		if [[ ${#errors[@]} -gt 0 ]]; then
			echo "RESULT: NOT READY — fix errors and rebuild"
		elif [[ ${#warnings[@]} -gt 0 ]]; then
			echo "RESULT: READY AFTER USER STEP — complete warnings before launch"
		else
			echo "RESULT: READY (checks passed) — launch not verified; see docs/windows-winui3-status.md if SxS"
		fi
	} | tee "${REPORT}"
}

main() {
	echo "[validate-winui3] checking ${BUILD_WIN}"

	if [[ ! -d "${BUILD_WIN}" ]]; then
		log_err "build-win directory missing: ${BUILD_WIN}"
		write_report
		exit 1
	fi

	local mt signtool
	mt="$(find_mt || true)"
	signtool="$(find_signtool || true)"
	[[ -n "${mt}" ]] || log_err "mt.exe not found (Windows 10 SDK)"
	[[ -n "${signtool}" ]] || log_warn "signtool.exe not found (skip MSIX verify)"

	for exe_name in "${WINUI3_EXES[@]}"; do
		local exe="${BUILD_WIN}/${exe_name}"
		if [[ ! -f "${exe}" ]]; then
			log_err "missing ${exe_name}"
			continue
		fi
		log_ok "${exe_name} exists ($(wc -c < "${exe}" | tr -d ' ') bytes)"
		check_pe_header "${exe}"
		if [[ "${WINUI3_LAYER}" == hello ]]; then
			log_ok "${exe_name}: hello layer — no embedded <msix> required (cf233c0)"
		elif [[ "${WINUI3_UNPACKAGED_WIDGETS:-}" == 1 ]]; then
			log_ok "${exe_name}: unpackaged widgets — no embedded <msix> required"
		elif [[ -n "${mt}" ]]; then
			check_embedded_manifest "${exe}" "${mt}"
		fi
	done

	if [[ -f "${BOOTSTRAP_DLL}" ]]; then
		log_ok "Microsoft.WindowsAppRuntime.Bootstrap.dll beside exe"
	else
		log_err "missing Microsoft.WindowsAppRuntime.Bootstrap.dll in build-win/"
	fi

	if [[ "${WINUI3_UNPACKAGED_WIDGETS:-}" == 1 ]]; then
		log_ok "WINUI3_UNPACKAGED_WIDGETS=1 — sparse MSIX/register checks skipped"
	elif [[ "${WINUI3_LAYER}" == widgets || "${WINUI3_LAYER}" == sparse ]]; then
		if [[ -f "${STORE_LOGO}" ]]; then
			log_ok "Assets/StoreLogo.png present (sparse external location)"
		else
			log_warn "missing Assets/StoreLogo.png (sparse register may fail)"
		fi
		check_sparse_msix "${signtool}"
		check_sparse_registered
	else
		log_ok "WINUI3_LAYER=${WINUI3_LAYER} — sparse MSIX/register checks skipped"
	fi

	write_user_tasks
	write_report

	if [[ ${#errors[@]} -gt 0 ]]; then
		exit 1
	fi
	exit 0
}

main
