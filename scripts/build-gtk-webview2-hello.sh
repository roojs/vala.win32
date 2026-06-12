#!/usr/bin/env bash
# Native Windows (MSYS2 UCRT64): GTK window + WebView2 hello — valac + cc link.
# Invoked from meson custom_target; do not run from plain PowerShell.
set -euo pipefail

OUT="${1:?output exe}"
BUILD_DIR="${2:?build dir}"
ROOT="${3:?repo root}"

cd "${MESON_BUILD_ROOT:-.}"

mkdir -p "${BUILD_DIR}/gtk" "${BUILD_DIR}/webview2"

VAPI="${ROOT}/vapi"
WEBVIEW2_INC="${ROOT}/build/vendor/webview2/include"
GEN="${ROOT}/generated"
SRC="${ROOT}/src"

WEBVIEW2_VALA_ARGS=(
	--vapidir "${VAPI}"
	--profile=posix
	--pkg win32-ui-webview2
	--pkg win32-ui-windowsandmessaging
	--pkg win32-system-stub
	--pkg win32-foundation-stub
	--pkg win32-graphics-gdi
)

valac "${WEBVIEW2_VALA_ARGS[@]}" -C -d "${BUILD_DIR}/webview2" \
	"${SRC}/win32-ui-webview2-host.vala" \
	"${GEN}/win32-ui-webview2-host-glue.vala" \
	"${GEN}/win32-ui-webview2-com-sync.vala" \
	"${GEN}/win32-wide-strings.vala" \
	"${GEN}/win32-ui-webview2-events-bridge.vala"

GTK_VALA_ARGS=(
	--vapidir "${VAPI}"
	--profile=gobject
	--pkg gtk+-3.0
)

valac "${GTK_VALA_ARGS[@]}" -C -d "${BUILD_DIR}/gtk" \
	"${ROOT}/examples/gtk-webview2-hello.vala"

GTK_CFLAGS="$(pkg-config --cflags gtk+-3.0)"
GTK_LIBS="$(pkg-config --libs gtk+-3.0)"

WEBVIEW2_C=(
	"${BUILD_DIR}/webview2/win32-ui-webview2-host.c"
	"${BUILD_DIR}/webview2/win32-ui-webview2-host-glue.c"
	"${BUILD_DIR}/webview2/win32-ui-webview2-com-sync.c"
	"${BUILD_DIR}/webview2/win32-wide-strings.c"
	"${BUILD_DIR}/webview2/win32-ui-webview2-events-bridge.c"
	"${GEN}/win32-ui-webview2-com-sync.c"
	"${GEN}/win32-ui-webview2-events.c"
	"${SRC}/win32-ui-webview2-loader.c"
	"${SRC}/win32-ui-webview2-com-glue.c"
)

# shellcheck disable=SC2086
cc -Wno-discarded-qualifiers -Wno-incompatible-pointer-types -Wno-implicit-function-declaration \
	-mwindows \
	-I"${BUILD_DIR}/webview2" -I"${BUILD_DIR}/gtk" -I"${GEN}" -I"${WEBVIEW2_INC}" -I"${SRC}" \
	${GTK_CFLAGS} \
	-o "${OUT}" \
	"${BUILD_DIR}/gtk/gtk-webview2-hello.c" \
	"${WEBVIEW2_C[@]}" \
	-lole32 -luuid -lshell32 -ladvapi32 \
	${GTK_LIBS}
