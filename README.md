# vala.win32

Thin **Vala vapi** bindings for native Win32 GUI. Application code compiles to C that calls Win32 directly—no `libwin32` monolith.

**Prior art (credits only, unrelated codebase):** [emrevit/vala-win32](https://github.com/emrevit/vala-win32)

Design and roadmap: [docs/plans/01-DONE - project overview.md](docs/plans/01-DONE%20-%20project%20overview.md) (phased plans `02`–`07` in `docs/plans/`)

## Phase 2 (apps) + Phase 1 (generator)

**Apps** use **generated vapi shards** (`win32-ui-windowsandmessaging`, …) plus a tiny hand stub (`win32-system-stub`) for `GetModuleHandleW` until loader JSON is vendored. Regen writes one `.vapi` per line in `metadata/win32json-api.files`.

`examples/hello-window.vala`:

- `using Win32.Ui.WindowsAndMessaging` + `Win32.System`
- Registers a window class, creates a top-level window, runs `GetMessage` / `DispatchMessage`
- `WM_DESTROY` → `PostQuitMessage` (clean exit)
- A few Win32 literals remain as local `const` in the example (Vala + `[CCode]` relay limitation)

### Build

```bash
meson setup build          # once
meson compile -C build     # regen vapi + build/hello-window.exe + build/button-demo.exe
wine build/hello-window.exe
wine build/button-demo.exe   # all controls; scroll updates progress bar
wine build/ergonomic-button-demo.exe   # Track B: Win32.Button / Edit + WidgetDispatch
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
examples/             # Consumer apps only
metadata/             # win32json-api.files, gui.filter; win32json/ from vendor script
tools/                # generate-binding (Phase 1+)
scripts/vendor-win32json.sh   # clone win32json → copy filtered api/*.json
docs/plans/           # Project plans
```

Do not hand-edit generated shard vapi; change `src/Generate/` or metadata instead.

## License

MIT — see [LICENSE](LICENSE).
