# vala.win32

> **Work on this repo has stopped.** The WebView2-in-a-GTK-window spike here became **[webview2-gtk](https://git.roojs.com/webview2-gtk)** — a GTK 4 widget library you can ship as a package, with hello and browser demos.
>
> For new programs we **recommend GTK 4** (Linux, macOS, Windows) over native Win32 bindings from this project. Use WebKitGTK on Linux and **webview2-gtk** on Windows for the same Vala/GTK app. vala.win32 remains useful as reference (Win32 metadata, WebView2 COM plumbing, experiments); it is not where we are investing.

Generated **Vala vapi** bindings for native Win32 GUI. Application `.vala` compiles to C that calls Win32 directly—no monolithic `libwin32`. Metadata comes from [win32json](https://github.com/marlersoft/win32json) (filtered Microsoft win32metadata); a small generator emits per-area `.vapi` shards and ergonomic helpers. **WebView2** (Edge Chromium in an HWND) is integrated alongside the Win32 work—host demo and plumbing today, generated COM bindings next.

![hello-window demo (Wine)](https://github.com/user-attachments/assets/23298046-8cf9-4f10-89f9-deabc6e3a738)

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
# Raw generated vapi: wine build/hello-window-native.exe, button-demo-native.exe, …
```

### WebView2 (metadata on Linux; demo on Windows only)

Regenerate API metadata on Linux or Windows (commit the result):

```bash
./scripts/vendor-webview2-sdk.sh   # if needed
./scripts/regen-webview2-json.sh   # → metadata/webview2/api/WebView2.json
./scripts/regen-webview2-vapi.sh   # → vapi/win32-ui-webview2.vapi (COM)
```

Details: [metadata/webview2/README.md](metadata/webview2/README.md)

`webview2-host-native` is **not** built by the Linux cross-compile graph. Build and run on real Windows — see [docs/windows-build.md](docs/windows-build.md) (`./scripts/build-win.sh`).

### Checks (optional)

```bash
meson compile -C build check-regen      # vapi drift vs metadata
meson compile -C build compile-check    # Track A examples → C (no link)
meson compile -C build coverage-report  # docs/coverage/6a-coverage-matrix.md
meson compile -C build valadoc          # generated API docs → build/docs/valadoc/
```

Do not hand-edit generated `.vapi` shards or `generated/win32-widgets.vala`; change `src/Generate/` (or templates) and run `meson compile -C build regen`.

### Generated API docs (Valadoc)

The Valadoc bundle focuses on the generated `Win32.*` widget API (including `Win32.WebView` and `Win32.Ui.WebView`) plus the raw shards those widgets use. It intentionally skips the old monolithic VAPI and the full `Microsoft.Web.WebView2.Win32` COM catalog.

```bash
make docs
# open build/docs/valadoc/vala.win32/index.htm
```

GitHub Pages publishing is automated by `.github/workflows/deploy-docs.yml`, following the OLLMchat pattern: checkout the repo, install the Vala/Valadoc build dependencies, build the docs, upload the Pages artifact, and deploy it with `actions/deploy-pages`.

The workflow runs on pushes to `master` that affect generated Vala/VAPI docs inputs, and can also be started manually with `workflow_dispatch`.

---

## Build on Windows

WebView2 **must** run on real Windows with the [Evergreen WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

Native output lives in **`build-win/`** (gitignored). Meson uses **MSYS2 MinGW** (`WebView2Loader.dll` next to the exe).

**Full steps** (rsync to `C:\msys64\tmp\vala.win32`, MSYS2 from PowerShell, `build-win.sh`): **[docs/windows-build.md](docs/windows-build.md)**

Quick compile after toolchain setup:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /c/msys64/tmp/vala.win32 && ./scripts/build-win.sh'
```

Run at the desktop:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /c/msys64/tmp/vala.win32/build-win && ./webview2-host-native.exe https://example.com/'
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /c/msys64/tmp/vala.win32/build-win && ./gtk-webview2-hello.exe'
```

---

## WinUI3 — not supported (we tried)

We spent a ridiculous amount of time on WinUI 3: sparse MSIX packages, PriGen, `ExpandPriContent`, `themeresources.xaml`, cert trust, Developer Mode, packaging workloads that do not appear in Visual Studio Installer search, and upstream samples that compile but show a blank window until some `.pri` file nobody can generate without half of Microsoft’s build stack. It is a modern UI framework that still behaves like a UWP side quest from 2012.

**WinUI3 is disabled by default** and we are not pursuing it. This repo is for things that actually build and run:

| Supported | Notes |
|-----------|--------|
| **Win32** bindings + demos | Native HWND widgets, dialogs, menus |
| **WebView2** | Edge Chromium in a window (`webview2-host-native`, `Win32.WebView`) |
| **GTK + WebView2** | Spike only — continued in **[webview2-gtk](https://git.roojs.com/webview2-gtk)** |

**Want cross-platform UI?** Use **[GTK 4](https://gtk.org/)**. It runs on Linux, macOS, and Windows without negotiating with `Add-AppxPackage`. For web content inside GTK on Windows, use **[webview2-gtk](https://git.roojs.com/webview2-gtk)** (WebKit-class embedding on the GTK stack).

To turn the experimental WinUI3 path back on (not recommended):

```bash
BUILD_WINUI3=1 ./scripts/build-win.sh
# meson: -Dbuild_winui3=true
```

Archive of what we learned: [docs/windows-winui3-status.md](docs/windows-winui3-status.md), [docs/windows-winui3.md](docs/windows-winui3.md).

---

## Status

| Area | State |
|------|--------|
| Phases 0–5 | Done — win32json vendor, generator, per-shard vapi, common controls, dialogs/menus, widget codegen (`Win32.*` ergonomic layer) |
| Phase 6 | In progress — API coverage, filter expansion, gap reports |
| Phase 7 | In progress — COM vapi `win32-ui-webview2.vapi`; generated ergo `Win32.WebView`; demos `webview2-host-native`, `webview2-demo`, `gtk-webview2-hello` |
| Phase 8 | Started — Valadoc target and GitHub Pages deploy script; CI and packaging polish remain |
| Phase 9 (WinUI3) | **Abandoned** — MSIX/PRI toolchain; off by default (`BUILD_WINUI3=0`) |

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
examples/             # Track B demos (hello-window, webview2-demo, …)
examples/native/      # Track A raw vapi (hello-window-native, webview2-host-native, …)
metadata/             # win32json filter lists; webview2 JSON (committed)
tools/                # generate-binding, generate-webview2-json
src/Generate/         # Generator and widget templates
src/win32-ui-webview2-*.c/h/vala   # WebView2 COM host glue + low-level API
generated/win32-ergo-webview2.vala    # Generated ergo Win32.WebView (catalog + shell profile)
scripts/              # vendor-win32json, setup-mingw-libs, build-win, …
docs/                 # Build guides, architecture, plans, coverage
```

---

## License

MIT — see [LICENSE](LICENSE).
