# vala.win32

Thin **Vala vapi** bindings for native Win32 GUI. Application code compiles to C that calls Win32 directly—no `libwin32` monolith.

**Prior art (credits only, unrelated codebase):** [emrevit/vala-win32](https://github.com/emrevit/vala-win32)

Design and roadmap: [docs/plans/01 - project overview.md](docs/plans/01%20-%20project%20overview.md) (phased plans `02`–`07` in `docs/plans/`)

## Phase 0 (apps) + Phase 1 (generator)

**Apps** use the hand-written spike `vapi/win32-ui-native.vapi` (+ placeholder `win32-ui.vapi`). **Phase 1** writes `vapi/win32-ui.generated.vapi` via regen; `compile-check` does **not** use the generated file yet.

`examples/hello-window.vala`:

- Registers a window class, creates a top-level window, runs `GetMessage` / `DispatchMessage`
- `WM_DESTROY` → `PostQuitMessage` (clean exit)

### Build

Builds use **[Meson](https://mesonbuild.com/)** with the **[Ninja](https://ninja-build.org/)** backend (`build/build.ninja`). Ninja is cross-platform (Linux, macOS, Windows via MSYS2 or native installs).

```bash
# Debian/Ubuntu
sudo apt install meson ninja-build valac libgee-0.8-dev libjson-glib-dev

meson setup build
meson compile -C build compile-check
meson compile -C build generate-binding
meson compile -C build regen        # refresh vapi/win32-ui.generated.vapi
meson compile -C build check-regen  # drift check on generated vapi (not spike)
```

`make` only wraps `meson` for convenience; **`meson` is the source of truth**. Run `./scripts/vendor-win32json.sh` before regen/check-regen.

**Compile-to-C smoke test** (Linux, no Windows SDK required for this step):

```bash
make check
# Generated C under build/hello-window.vala.c (ninja)
```

**Windows `.exe`** — quick path (Phase 0, no GLib), cross-compile from Linux:

```bash
sudo apt install gcc-mingw-w64-x86-64
make win
# → build-win/hello-window.exe
```

On **Windows** with Meson, Ninja, Vala, and MinGW in `PATH`:

```bash
meson setup build --cross-file cross/mingw-w64.ini
meson compile -C build hello-window
```

`make win` / the cross file use `valac --profile=posix` so they do not need Windows GLib. Compiler flags use `-X` (e.g. `-mwindows`), not bare `valac` options.

**Windows `.exe`** — full Vala / GLib cross-compile ([emrevit/vala-win32](https://github.com/emrevit/vala-win32) style):

Ubuntu does not ship MinGW GLib in apt. The author downloads **MSYS2** packages (not Fedora RPMs) into a local directory, fixes `pkg-config` paths, then runs `valac -C` and links with `x86_64-w64-mingw32-gcc`. On **Fedora** you can skip the download and use distro `mingw*-glib2` packages instead.

```bash
sudo apt install gcc-mingw-w64-x86-64 curl zstd
./scripts/setup-mingw-libs.sh          # creates ./mingw-libs/ from repo.msys2.org
export PKG_CONFIG_LIBDIR="$PWD/mingw-libs/mingw64/lib/pkgconfig"
# valac -C … then x86_64-w64-mingw32-gcc … $(pkg-config --cflags --libs glib-2.0 gobject-2.0)
```

A two-step `Makefile` target for that flow is planned; Phase 0 only documents the script.

On Windows you can also use `meson setup build` (no cross file if `gcc` is MinGW) and `meson compile -C build hello-window` once a native Windows target is wired up; today `cross/mingw-w64.ini` is aimed at Linux → Windows cross builds.

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
vapi/win32-ui.vapi    # Binding declarations (committed; later: generated)
examples/             # Consumer apps only
metadata/             # win32json-api.files, gui.filter; win32json/ from vendor script
tools/                # generate-binding (Phase 1+)
scripts/vendor-win32json.sh   # clone win32json → copy filtered api/*.json
docs/plans/           # Project plans
```

Do not hand-edit generated vapi once the generator owns `vapi/win32-ui.vapi`.

## License

MIT — see [LICENSE](LICENSE).
