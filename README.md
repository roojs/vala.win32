# vala.win32

Thin **Vala vapi** bindings for native Win32 GUI. Application code compiles to C that calls Win32 directly—no `libwin32` monolith.

**Prior art (credits only, unrelated codebase):** [emrevit/vala-win32](https://github.com/emrevit/vala-win32)

Design and roadmap: [docs/plans/1. project overview.md](docs/plans/1.%20project%20overview.md) (plans `2`–`7` done; **`9` WebView2** is the current focus; see `docs/plans/`)

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
wine build/ergonomic-widgets-demo.exe   # grouped layout; comctl32 v6 manifest on native Windows
wine build/ergonomic-dialog-demo.exe
wine build/ergonomic-common-dialog-demo.exe
wine build/ergonomic-menu-demo.exe
wine build/ergonomic-error-demo.exe

# Debug WM_COMMAND / WM_NOTIFY (ergonomic-widgets-demo exercises most Track B widgets):
# WIN32_WIDGET_DEBUG=1 wine build/ergonomic-widgets-demo.exe 2>&1 | tee /tmp/ergo-debug.log
```

Or `make` (same as `meson compile -C build` after setup).

**Phase 6 checks:**

```bash
meson compile -C build check-regen      # vapi drift vs metadata
meson compile -C build compile-check    # Track A examples → C (no link)
meson compile -C build coverage-report  # docs/coverage/6a-coverage-matrix.md (ergonomic examples)
# Gap analysis (Phase 6e): docs/coverage/6e-gap-report.md
```

Win32 JSON for regen: run `./scripts/vendor-win32json.sh` once if `metadata/win32json/api/` is empty.

### WebView2 (Phase 7)

**Regenerate API metadata JSON** (Linux or Windows — commit the result):

```bash
./scripts/vendor-webview2-sdk.sh   # if needed
meson setup build
./scripts/regen-webview2-json.sh   # → metadata/webview2/api/WebView2.json
```

Details: **[metadata/webview2/README.md](metadata/webview2/README.md)**

**Linux cross-build** (`build/`):

```bash
./scripts/vendor-webview2-sdk.sh
meson setup build --reconfigure
meson compile -C build webview2-host-demo
wine build/webview2-host-demo.exe https://example.com/   # optional; often blank under Wine
```

**Windows native** (`build-win/` on the Samba share — no `C:` mirror needed):

See **[docs/windows-build.md](docs/windows-build.md)** — **Visual Studio Build Tools** (recommended long-term for WebView2) vs **MSYS2 MinGW** (what Meson uses today). They are not mixed in one link.

On Windows: one PowerShell line runs `scripts/build-win.sh` via `msys2_shell.cmd -ucrt64` (after `setup-msys2-toolchain.sh` for the compiler tools) — [docs/windows-build.md](docs/windows-build.md). Run `build-win\webview2-host-demo.exe` at the desktop.

Ship `WebView2Loader.dll` next to the exe (Meson copies it into the build dir). Runtime must be installed on the Windows machine.

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
docs/windows-build.md # Windows native build-win, SSH, WebView2 runtime
```

Do not hand-edit generated shard vapi or `generated/win32-widgets.vala`; change `src/Generate/` (or `src/Generate/templates/win32-widgets.vala` for Track B widgets) and run `meson compile -C build regen`.

## License

MIT — see [LICENSE](LICENSE).
