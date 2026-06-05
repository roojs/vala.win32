#!/bin/sh
# Phase 6b — compile Track A examples to C (no link). Fails fast on vapi / generated .vala drift.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

valac=valac
vapidir="$root/vapi"
builddir="${COMPILE_CHECK_DIR:-/tmp/vala-win32-compile-check}"
mkdir -p "$builddir"

wide="$root/generated/win32-wide-strings.vala"
controls="$root/generated/win32-ui-control-strings.vala"
errors="$root/generated/win32-errors.vala"
pkgs="--pkg win32-ui-windowsandmessaging --pkg win32-system-stub --pkg win32-foundation-stub --pkg win32-graphics-gdi"
vala_common="--vapidir $vapidir --profile=posix $pkgs -C -d $builddir"

compile() {
	name=$1
	shift
	echo "compile-check: $name"
	# shellcheck disable=SC2086
	$valac $vala_common "$root/examples/native/${name}.vala" "$@"
}

compile hello-window "$wide"
compile dialog-demo "$wide"
compile menu-demo "$wide"
compile button-demo "$wide" "$controls"
compile common-dialog-demo "$wide" "$controls" --pkg win32-ui-controls-dialogs
compile error-demo "$wide" "$errors"

echo "compile-check: ok ($builddir)"
