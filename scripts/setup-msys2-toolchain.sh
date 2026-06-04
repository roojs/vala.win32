#!/usr/bin/env bash
# MSYS2 UCRT64 packages for native vala.win32 builds (build-win/ on X:).
# Idempotent: pacman -S --needed skips what is already installed.
#
# From Windows PowerShell (one line):
#   C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/setup-msys2-toolchain.sh'
set -euo pipefail

# Matches meson.build: gee/json-glib (generate-binding), gcc/valac/meson/ninja, curl+unzip (vendor script).
readonly PACMAN_PACKAGES=(
	mingw-w64-ucrt-x86_64-gcc
	mingw-w64-ucrt-x86_64-binutils
	mingw-w64-ucrt-x86_64-vala
	mingw-w64-ucrt-x86_64-python
	mingw-w64-ucrt-x86_64-meson
	mingw-w64-ucrt-x86_64-ninja
	mingw-w64-ucrt-x86_64-libgee
	mingw-w64-ucrt-x86_64-json-glib
	mingw-w64-ucrt-x86_64-curl
	unzip
)

disable_qlu_mirror() {
	local f
	for f in /etc/pacman.d/mirrorlist.mingw.ucrt64 /etc/pacman.d/mirrorlist.mingw64; do
		if [[ -f "${f}" ]]; then
			sed -i 's|^Server = https://mirrors.qlu.edu.cn|# &|' "${f}" || true
		fi
	done
}

meson_ok() {
	local out
	command -v meson >/dev/null 2>&1 || return 1
	out="$(meson --version 2>&1)" || return 1
	[[ "${out}" != *ERROR* ]] && [[ "${out}" =~ ^(Meson |[0-9]+\.) ]]
}

verify_ready() {
	local ok=1
	command -v gcc valac meson ninja pkg-config curl unzip >/dev/null 2>&1 || ok=0
	gcc --version >/dev/null 2>&1 || ok=0
	valac --version >/dev/null 2>&1 || ok=0
	meson_ok || ok=0
	pkg-config --exists gee-0.8 2>/dev/null || ok=0
	pkg-config --exists json-glib-1.0 2>/dev/null || ok=0
	[[ "${ok}" -eq 1 ]]
}

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
	echo "error: run in MSYS2 UCRT64 (MSYSTEM=UCRT64)" >&2
	exit 1
fi

if verify_ready; then
	echo '[setup-msys2] Toolchain and build deps already OK.'
	gcc --version | head -1
	valac --version | head -1
	meson --version | head -1
	echo '[setup-msys2] Done.'
	exit 0
fi

echo '[setup-msys2] Disable known-bad mirror (qlu.edu.cn) if present...'
disable_qlu_mirror

echo '[setup-msys2] Refresh package database (pacman -Syy)...'
pacman -Syy --noconfirm

echo '[setup-msys2] Install build packages (one pacman line)...'
pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

if ! verify_ready; then
	echo '[setup-msys2] ERROR: missing tools after install. Check pacman output above.' >&2
	exit 1
fi

echo '[setup-msys2] Verify:'
gcc --version | head -1
valac --version | head -1
meson --version | head -1
pkg-config --modversion gee-0.8
pkg-config --modversion json-glib-1.0
echo '[setup-msys2] Done.'
