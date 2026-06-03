# vala.win32

Thin **Vala vapi** bindings for native Win32 GUI. Application code compiles to C that calls Win32 directly—no `libwin32` monolith.

**Prior art (credits only, unrelated codebase):** [emrevit/vala-win32](https://github.com/emrevit/vala-win32)

Design and roadmap: [docs/plans/01-DONE - project overview.md](docs/plans/01-DONE%20-%20project%20overview.md) (plans `02-DONE`–`06-DONE` complete; `07`–`08` in `docs/plans/`)

## Phase 2 (apps) + Phase 1 (generator)

**Apps** use **generated vapi shards** (`win32-ui-windowsandmessaging`, …) plus a tiny hand stub (`win32-system-stub`) for `GetModuleHandleW` until loader JSON is vendored. Regen writes one `.vapi` per line in `metadata/win32json-api.files`.

**Track A** (`hello-window`, `button-demo`, `dialog-demo`, `common-dialog-demo`, `menu-demo`, `error-demo`) — raw vapi, `--profile=posix`, no GLib.

**Track B** (`ergonomic-*-demo`) — hand-maintained `Win32.*` widgets in `src/Generate/templates/win32-widgets.vala` (regen → `generated/win32-widgets.vala`); `--profile=gobject` + MinGW GLib. Includes Phase 4 ergonomic counterparts: `ergonomic-dialog-demo`, `ergonomic-common-dialog-demo`, `ergonomic-menu-demo`, `ergonomic-error-demo` (baseline for Phase 5 generator comparison). After compile, runtime DLLs from `mingw-libs/` are copied next to each `.exe`.

### Build

```bash
meson setup build          # once
./scripts/setup-mingw-libs.sh   # required for Track B ergonomic demos
meson setup build --reconfigure # after mingw-libs
meson compile -C build
wine build/hello-window.exe
wine build/button-demo.exe
wine build/dialog-demo.exe
wine build/common-dialog-demo.exe
wine build/menu-demo.exe
wine build/error-demo.exe
wine build/ergonomic-button-demo.exe
wine build/ergonomic-dialog-demo.exe
wine build/ergonomic-common-dialog-demo.exe
wine build/ergonomic-menu-demo.exe
wine build/ergonomic-error-demo.exe

# Debug WM_COMMAND / signals (ergonomic-button-demo):
# WIN32_WIDGET_DEBUG=1 wine build/ergonomic-button-demo.exe 2>&1 | tee /tmp/ergo-debug.log
```

Or `make` (same as `meson compile -C build` after setup).

Win32 JSON for regen: run `./scripts/vendor-win32json.sh` once if `metadata/win32json/api/` is empty.

### Win32 metadata (JSON)

Filtered subset from [marlersoft/win32json](https://github.com/marlersoft/win32json) (community export of [win32metadata](https://github.com/microsoft/win32metadata)):

```bash
./scripts/vendor-win32json.sh
# → build/vendor/win32json/        shallow clone (gitignored)
# → metadata/win32json/api/        files listed in metadata/win32json-api.files
```

**Include scope** = edit `metadata/win32json-api.files` (which JSON blobs to copy). **Exclude rules** for symbols inside those files = `metadata/filters/gui.filter` (`-` Ansi / Interop / Tests only).

Pin upstream with `metadata/win32json-ref.txt` or `WIN32JSON_REF=…`.

### Layout

```
vapi/
  win32-ui-windowsandmessaging.vapi   # generated (regen)
  win32-system-stub.vapi                # hand stub until loader JSON vendored
  archive/win32-ui-native.vapi          # Phase 0 spike (reference only)
generated/
  win32-ui-control-strings.vala         # WC_* (regen)
  win32-wide-strings.vala               # UTF-8 ↔ UTF-16 (regen from template)
  win32-widgets.vala                    # Win32.* widgets (full WC_* catalog + profiles)
  win32-errors.vala                     # GetLastError helpers (regen)
examples/             # Consumer apps only
metadata/             # win32json-api.files, gui.filter; win32json/ from vendor script
tools/                # generate-binding (Phase 1+)
scripts/vendor-win32json.sh   # clone win32json → copy filtered api/*.json
scripts/setup-mingw-libs.sh   # MSYS2 GLib tree for Track B cross-link
docs/plans/           # Project plans
```

Do not hand-edit generated shard vapi or `generated/win32-widgets.vala`; change `src/Generate/` (or `src/Generate/templates/win32-widgets.vala` for Track B widgets) and run `meson compile -C build regen`.

## License

MIT — see [LICENSE](LICENSE).
