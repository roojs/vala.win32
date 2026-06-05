# vala.win32

Generated **Vala vapi** bindings for native Win32 GUI. Application `.vala` compiles to C that calls Win32 directly—no monolithic `libwin32`. Metadata comes from [win32json](https://github.com/marlersoft/win32json) (filtered Microsoft win32metadata); a small generator emits per-area `.vapi` shards and ergonomic helpers. **WebView2** (Edge Chromium in an HWND) is integrated alongside the Win32 work—host demo and plumbing today, generated COM bindings next.

![hello-window demo (Wine)](https://private-user-images.githubusercontent.com/415282/603186551-b645fe2c-d579-424c-b3d3-0b573e3f4e23.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODA2MjcyNjIsIm5iZiI6MTc4MDYyNjk2MiwicGF0aCI6Ii80MTUyODIvNjAzMTg2NTUxLWI2NDVmZTJjLWQ1NzktNDI0Yy1iM2QzLTBiNTczZTNmNGUyMy5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNjA1JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDYwNVQwMjM2MDJaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1kOGQyYTNmODNiZDJjNGNhMTdiMmJmMDI2YzM1YjhlODhkNTMxYTc1MTVjYWQ2ZGE0N2ZjZjIzMzAwOWYwOWZjJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZwbmcifQ.advJRjj_C2QxgJvkYVXO_OM7XpMQvIRVCa56AqCcA-o)

**Thanks** to [emrevit/vala-win32](https://github.com/emrevit/vala-win32) for the early ideas on Vala, Win32, and cross-compiling with MinGW GLib.

---

## Build on Linux

Cross-compile with **MinGW** (`x86_64-w64-mingw32-gcc`). Run demos under **Wine** for smoke tests. WebView2 rendering is unreliable in Wine; treat Windows as the real runtime for that demo.

### Prerequisites

- Meson, Ninja, Vala, MinGW-w64 cross toolchain
- Wine (to run `.exe` outputs)
- For default **examples/** demos (GLib profile): `./scripts/setup-mingw-libs.sh` once, then `meson setup build --reconfigure`

Win32 JSON for regen (if `metadata/win32json/api/` is empty): `./scripts/vendor-win32json.sh`

### Compile 

```bash
meson setup build          # once
./scripts/setup-mingw-libs.sh   # examples/*.vala (Win32.* widgets) only
meson setup build --reconfigure # after mingw-libs
meson compile -C build
```

Or `make` after setup (same as `meson compile -C build`).

### Run (Wine)

```bash
wine build/hello-window.exe          # start here (ergonomic Win32.Window)
wine build/button-demo.exe
wine build/widgets-demo.exe
# Raw generated vapi: wine build/native-hello-window.exe, native-button-demo.exe, …
```

### WebView2 (metadata on Linux; demo on Windows only)

Regenerate API metadata on Linux or Windows (commit the result):

```bash
./scripts/vendor-webview2-sdk.sh   # if needed
./scripts/regen-webview2-json.sh   # → metadata/webview2/api/WebView2.json
./scripts/regen-webview2-vapi.sh   # → vapi/win32-webview2.vapi
```

Details: [metadata/webview2/README.md](metadata/webview2/README.md)

`webview2-host-demo` is **not** built by the Linux cross-compile graph. Build and run on real Windows — see [docs/windows-build.md](docs/windows-build.md) (`./scripts/build-win.sh`).

### Checks (optional)

```bash
meson compile -C build check-regen      # vapi drift vs metadata
meson compile -C build compile-check    # Track A examples → C (no link)
meson compile -C build coverage-report  # docs/coverage/6a-coverage-matrix.md
```

Do not hand-edit generated `.vapi` shards or `generated/win32-widgets.vala`; change `src/Generate/` (or templates) and run `meson compile -C build regen`.

---

## Build on Windows

WebView2 **must** run on real Windows with the [Evergreen WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

Native output lives in **`build-win/`** (gitignored). Meson uses **MSYS2 MinGW** today (`WebView2Loader.dll` next to the exe). Visual Studio / MSVC is documented for a future path but is not the default Meson backend yet.

**Full steps** (MSYS2 from PowerShell, Samba `X:` share, runtime install, `build-win.sh`): **[docs/windows-build.md](docs/windows-build.md)**

Quick compile after toolchain setup:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/build-win.sh'
```

Run at the desktop:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32/build-win && ./webview2-host-demo.exe https://example.com/'
```

---

## Status

| Area | State |
|------|--------|
| Phases 0–5 | Done — win32json vendor, generator, per-shard vapi, common controls, dialogs/menus, widget codegen (`Win32.*` ergonomic layer) |
| Phase 6 | In progress — API coverage, filter expansion, gap reports |
| Phase 7 | In progress — WebView2 host on Windows; JSON + filtered COM vapi (`win32-webview2.vapi`); plumbing shrink / demo migration still open |
| Phase 8 | Not started — Valadoc, CI, polish |

**Examples:** default **`examples/*.vala`** — `Win32.*` widgets (`--profile=gobject` + MinGW GLib). **`examples/native/`** — raw generated vapi (`native-*` exe names, `--profile=posix`). WebView2 host lives under **`examples/native/`** (`Win32.Ui.WebView` plumbing vapi).

**Technical documentation**

- [docs/plans/1. project overview.md](docs/plans/1.%20project%20overview.md) — roadmap and phase index (`docs/plans/`)
- [docs/webview2-binding-architecture.md](docs/webview2-binding-architecture.md) — WebView2 layers and next steps
- [docs/windows-build.md](docs/windows-build.md) — native Windows build and lab setup
- [docs/coverage/6a-coverage-matrix.md](docs/coverage/6a-coverage-matrix.md) — binding coverage matrix

---

## Repository layout

```
vapi/                 # Generated Win32 shards + small hand stubs
generated/            # Regen helpers (widgets, wide strings, errors, …)
examples/             # Default ergonomic demos (hello-window, button-demo, …)
examples/native/      # Raw vapi + webview2-host-demo (native-* exes)
metadata/             # win32json filter lists; webview2 JSON (committed)
tools/                # generate-binding, generate-webview2-json
src/Generate/         # Generator and widget templates
src/webview2-loader.c     # WebView2Loader.dll bootstrap (C)
src/webview2-com-glue.c   # Async COM completed handlers (C)
src/webview2-host.vala    # Host logic via win32-webview2.vapi (Vala)
scripts/              # vendor-win32json, setup-mingw-libs, build-win, …
docs/                 # Build guides, architecture, plans, coverage
```

---

## License

MIT — see [LICENSE](LICENSE).
