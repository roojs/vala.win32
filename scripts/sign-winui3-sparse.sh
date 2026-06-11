#!/usr/bin/env bash
# Sign sparse MSIX (openssl + signtool — no PowerShell).
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "usage: $0 <sparse.msix>" >&2
	exit 1
fi

MSIX="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/winui3-runtime-gate.sh
source "${ROOT}/scripts/winui3-runtime-gate.sh"

if [[ ! -f "${MSIX}" ]]; then
	echo "[sign-winui3-sparse] error: not found: ${MSIX}" >&2
	exit 1
fi

find_signtool() {
	local kit
	for kit in \
		"/c/Program Files (x86)/Windows Kits/10/bin"/*/x64/signtool.exe \
		"/c/Program Files/Windows Kits/10/bin"/*/x64/signtool.exe; do
		if [[ -f "${kit}" ]]; then
			printf '%s' "${kit}"
			return 0
		fi
	done
	return 1
}

SIGNTOOL="$(find_signtool || true)"
if [[ -z "${SIGNTOOL}" ]]; then
	echo "[sign-winui3-sparse] error: signtool.exe not found (install Windows 10 SDK)" >&2
	exit 1
fi

# Cert + temp files on C: (Samba may block writes under build/vendor).
CERT_DIR="${LOCAL_SPARSE_CERT_DIR:-/c/msys64/tmp/vala-win32-sparse-cert}"
CERT_PUBLISH="${ROOT}/build/vendor/winui3-sparse"
PFX="${CERT_DIR}/vala.win32.sparse.pfx"
CER="${CERT_DIR}/vala.win32.sparse.cer"
STAMP="${CERT_DIR}/.signing-cert-stamp"
# Bump when openssl -addext layout changes (forces new cert + re-sign MSIX).
CERT_FORMAT=4
PFX_PASS=vala.win32

to_openssl_path() {
	# UCRT64 openssl rejects MSYS /c/... paths; C:/... works.
	to_win_path "$1" | sed 's|\\|/|g'
}

cert_format_ok() {
	[[ -f "${STAMP}" && -f "${PFX}" && -f "${CER}" && "$(cat "${STAMP}")" == "${CERT_FORMAT}" ]]
}

ensure_dev_cert() {
	if cert_format_ok; then
		return 0
	fi
	if ! command -v openssl >/dev/null 2>&1; then
		echo "[sign-winui3-sparse] error: openssl not in PATH (pacman -S openssl)" >&2
		exit 1
	fi
	mkdir -p "${CERT_DIR}"
	rm -f "${CERT_DIR}/.trusted-stamp"
	local key="${CERT_DIR}/key.pem"
	local key_openssl cer_openssl pfx_openssl
	key_openssl="$(to_openssl_path "${key}")"
	cer_openssl="$(to_openssl_path "${CER}")"
	pfx_openssl="$(to_openssl_path "${PFX}")"
	# AppX sparse MSIX needs codeSigning + lifetime-signing EKU (1.3.6.1.4.1.311.10.3.13).
	# Without lifetime signing, Add-AppxPackage -ExternalLocation fails with 0x80073D2E.
	MSYS2_ARG_CONV_EXCL='*' openssl req -x509 -newkey rsa:2048 -nodes \
		-keyout "${key_openssl}" -out "${cer_openssl}" \
		-days 8250 -subj "/CN=vala.win32" \
		-addext "basicConstraints=critical,CA:FALSE" \
		-addext "keyUsage=critical,digitalSignature" \
		-addext "extendedKeyUsage=critical,codeSigning,1.3.6.1.4.1.311.10.3.13"
	MSYS2_ARG_CONV_EXCL='*' openssl pkcs12 -export -out "${pfx_openssl}" \
		-inkey "${key_openssl}" -in "${cer_openssl}" \
		-passout "pass:${PFX_PASS}"
	rm -f "${key}"
	printf '%s\n' "${CERT_FORMAT}" > "${STAMP}"
	mkdir -p "${CERT_PUBLISH}"
	cp -f "${CER}" "${CERT_PUBLISH}/vala.win32.sparse.cer"
	cp -f "${PFX}" "${CERT_PUBLISH}/vala.win32.sparse.pfx" 2>/dev/null || true
	echo "[sign-winui3-sparse] dev cert CN=vala.win32 (AppX extensions) -> ${PFX}"
}

trust_dev_cert() {
	if [[ -f "${CERT_DIR}/.trusted-stamp" ]]; then
		return 0
	fi
	if ! command -v certutil.exe >/dev/null 2>&1 \
		&& [[ ! -x /c/Windows/System32/certutil.exe ]]; then
		echo "[sign-winui3-sparse] warning: certutil.exe not found (trust step skipped)" >&2
		return 0
	fi
	local certutil=/c/Windows/System32/certutil.exe
	local cer_win
	cer_win="$(to_win_path "${CER}")"
	# Self-signed MSIX: TrustedPeople is required for Add-AppxPackage; Root helps signtool /pa verify.
	local trusted=0
	if MSYS2_ARG_CONV_EXCL='*' "${certutil}" -addstore -user TrustedPeople "${cer_win}" >/dev/null 2>&1 \
		|| MSYS2_ARG_CONV_EXCL='*' "${certutil}" -addstore TrustedPeople "${cer_win}" >/dev/null 2>&1; then
		trusted=1
	fi
	if MSYS2_ARG_CONV_EXCL='*' "${certutil}" -addstore -user Root "${cer_win}" >/dev/null 2>&1 \
		|| MSYS2_ARG_CONV_EXCL='*' "${certutil}" -addstore Root "${cer_win}" >/dev/null 2>&1; then
		trusted=1
	fi
	if [[ "${trusted}" -eq 1 ]]; then
		touch "${CERT_DIR}/.trusted-stamp"
		echo "[sign-winui3-sparse] dev cert trusted (TrustedPeople and/or Root)"
	else
		echo "[sign-winui3-sparse] warning: certutil trust failed — register may return 0x800B0109/0x80073D2E" >&2
	fi
}

ensure_dev_cert
trust_dev_cert

MSIX_WIN="$(to_win_path "${MSIX}")"
PFX_WIN="$(to_win_path "${PFX}")"
echo "[sign-winui3-sparse] signing ${MSIX}"
MSYS2_ARG_CONV_EXCL='*' "${SIGNTOOL}" sign /f "${PFX_WIN}" /p "${PFX_PASS}" /fd SHA256 "${MSIX_WIN}"
# Self-signed dev cert: sign succeeds; full-chain /pa verify often fails until trusted.
if ! MSYS2_ARG_CONV_EXCL='*' "${SIGNTOOL}" verify /pa "${MSIX_WIN}" >/dev/null 2>&1; then
	echo "[sign-winui3-sparse] verify: self-signed dev cert (signed OK; trust via certutil if needed)"
fi
echo "[sign-winui3-sparse] OK"
