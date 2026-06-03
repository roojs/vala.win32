#!/usr/bin/env bash
# Fetch MinGW64 libraries from MSYS2 into a local tree for cross-linking Vala on Linux.
#
# This follows the approach described by emrevit/vala-win32:
#   https://github.com/emrevit/vala-win32#building
#
# It is NOT "install Fedora RPMs into mingw". Fedora is only mentioned there as a
# distro that ships mingw-*-glib2 in its own repos. On Ubuntu we download the
# same kind of binaries from the MSYS2 package repository and extract them here.
#
# Usage:
#   ./scripts/setup-mingw-libs.sh
#   export MINGW_LIBDIR="$PWD/mingw-libs"
#   export PKG_CONFIG_LIBDIR="$MINGW_LIBDIR/mingw64/lib/pkgconfig"
#
# Requires: curl, tar, zstd (for tar --zstd), sed

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBDIR="${MINGW_LIBDIR:-$ROOT/mingw-libs}"
MSYS2_REPO="${MSYS2_REPO:-https://repo.msys2.org/mingw/mingw64}"
PREFIX="mingw-w64-x86_64"

# Runtime + pkg-config for default Vala (gobject profile). Add more names as needed.
PACKAGE_BASES=(
	glib2
	libffi
	pcre2
	zlib
	libiconv
	gettext-runtime
	libwinpthread
	gcc-libs
)

die() { echo "setup-mingw-libs: $*" >&2; exit 1; }

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

latest_package_file() {
	local base="$1"
	local html name
	html="$(curl -fsSL "$MSYS2_REPO/")" || die "cannot read $MSYS2_REPO (check network)"
	name="$(echo "$html" | grep -oE "${PREFIX}-${base}-[^\"'<> ]+\\.pkg\\.tar\\.zst" | sort -V | tail -1)"
	[[ -n "$name" ]] || die "no package found for base name: $base"
	echo "$name"
}

main() {
	need_cmd curl
	need_cmd tar
	need_cmd sed
	tar --help 2>&1 | grep -q zstd || need_cmd zstd

	mkdir -p "$LIBDIR"
	cd "$LIBDIR"

	echo "Installing MSYS2 MinGW64 packages into: $LIBDIR"
	echo "Repository: $MSYS2_REPO"
	echo

	for base in "${PACKAGE_BASES[@]}"; do
		file="$(latest_package_file "$base")"
		url="$MSYS2_REPO/$file"
		if [[ -f "$file" ]]; then
			echo "  skip (already downloaded): $file"
		else
			echo "  download: $file"
			curl -fsSL -o "$file" "$url"
		fi
	done

	echo
	echo "Extracting packages..."
	for f in ${PREFIX}-*.pkg.tar.zst; do
		[[ -f "$f" ]] || continue
		echo "  extract: $f"
		tar --zstd -xf "$f"
	done

	echo
	echo "Fixing pkg-config prefix paths..."
	while IFS= read -r -d '' pc; do
		sed -E -i "s#^prefix=(/mingw64)#prefix=$LIBDIR\\1#" "$pc"
	done < <(find . -path '*/lib/pkgconfig/*.pc' -print0 2>/dev/null)

	cat <<EOF

Done.

Set these when cross-compiling (see emrevit Makefile):

  export MINGW_LIBDIR="$LIBDIR"
  export PKG_CONFIG_LIBDIR="\$MINGW_LIBDIR/mingw64/lib/pkgconfig"

Example link flags:

  pkg-config --cflags --libs glib-2.0 gobject-2.0

Copy runtime DLLs from \$MINGW_LIBDIR/mingw64/bin next to your .exe when testing with Wine
(meson build does this automatically for ergonomic-button-demo).

If libintl-8.dll was missing, re-run this script after upgrading gettext-runtime
(was: gettext → gettext-tools only, no libintl DLL).

EOF
}

main "$@"
