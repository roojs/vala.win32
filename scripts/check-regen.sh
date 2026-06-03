#!/bin/sh
# Regen shard vapi into build dir and diff against vapi/win32-*.vapi baselines.
# Baselines come from metadata/win32json-api.files (same pkg ids as generate-binding).
set -eu
generator="$1"
metadata="$2"
filter="$3"
outdir="$4"
api_list="$5"
vapidir="$6"

"$generator" \
	--metadata "$metadata" \
	--filter "$filter" \
	--api-list "$api_list" \
	--out "$outdir" \
	--debug-critical

# UI.WindowsAndMessaging.json → win32-ui-windowsandmessaging.vapi
json_to_pkg_id() {
	stem="${1%.json}"
	printf 'win32-%s' "$(echo "$stem" | tr '[:upper:]' '[:lower:]' | tr '.' '-')"
}

failed=0
while IFS= read -r line || [ -n "$line" ]; do
	line=$(echo "$line" | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
	[ -n "$line" ] || continue
	case "$line" in
	*.json) basename="$line" ;;
	*) basename="${line}.json" ;;
	esac
	pkg_id=$(json_to_pkg_id "$basename")
	base="${pkg_id}.vapi"
	committed="$vapidir/$base"
	generated="$outdir/$base"
	if [ ! -f "$committed" ]; then
		echo "missing baseline $committed (run meson compile -C build regen)" >&2
		failed=1
		continue
	fi
	if [ ! -f "$generated" ]; then
		echo "missing generated $base" >&2
		failed=1
		continue
	fi
	if ! diff -u "$committed" "$generated"; then
		failed=1
	fi
done < "$api_list"
exit "$failed"
