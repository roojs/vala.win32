#!/usr/bin/env bash
# WinUI3 sandbox build launcher. MSVC is primary; MinGW is optional compare path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
SDK="${REPO_ROOT}/build/vendor/winui3"

die() { echo "winui3/build.sh: $*" >&2; exit 1; }

[[ -f "${SDK}/include/MddBootstrap.h" ]] || die "missing ${SDK} — run: ${REPO_ROOT}/scripts/vendor-winui3-sdk.sh"

TOOL="${1:-msvc}"
cd "${ROOT}"

case "${TOOL}" in
msvc)
	powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
		-File "${ROOT}/build-msvc.ps1"
	;;
mingw)
	g++ -std=c++20 -fcoroutines -Wno-deprecated-declarations \
		-I"${SDK}/include" -I"${SDK}/cppwinrt" \
		-o winui3-sandbox-mingw.exe main.cpp \
		-L"${SDK}/lib/x64" -lMicrosoft.WindowsAppRuntime.Bootstrap \
		-lole32 -loleaut32 -lruntimeobject -luuid \
		-mwindows -municode -static-libgcc -static-libstdc++
	cp -f "${SDK}/bin/x64/Microsoft.WindowsAppRuntime.Bootstrap.dll" "${ROOT}/"
	echo "OK: ${ROOT}/winui3-sandbox-mingw.exe"
	;;
run)
	powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
		-File "${ROOT}/build-msvc.ps1" -Run
	;;
*)
	die "usage: $0 {msvc|mingw|run}   (default: msvc)"
	;;
esac
