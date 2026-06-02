#!/bin/sh
# Emit generated vapi into the Meson build dir and diff against committed vapi/win32-ui.generated.vapi.
set -eu
"$1" --metadata "$2" --filter "$3" --out "$4" --basename "$(basename "$5")"
diff -u "$5" "$4/$(basename "$5")"
