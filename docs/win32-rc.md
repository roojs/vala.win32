# Win32 `.rc` resources (Phase 4c)

Vala apps in this repo compile to C and link with MinGW like a normal Win32 program. **Resource scripts** (`.rc`) are compiled with `windres` into a `.o` that you link alongside your Vala-generated `.c`.

## When to use `.rc`

| Approach | Good for |
|----------|----------|
| **Runtime APIs** (`CreateMenu`, `LoadCursor`, …) | Menus/cursors in Track A demos without a resource compiler |
| **`.rc` + `windres`** | Icons, version info, dialog templates, string tables, `IDI_*` / `IDC_*` by name |

Phase 4 Track A demos use **runtime menus** (`examples/menu-demo.vala`). Icons and named cursors in production apps usually come from `.rc`.

## Minimal resource script

`examples/resources/minimal.rc`:

```rc
#include <windows.h>

IDI_APP ICON "app.ico"
IDC_ARROW CURSOR IDC_ARROW
```

(Replace `app.ico` with a real icon path when you add one.)

## Compile and link (cross-build)

```bash
x86_64-w64-mingw32-windres -i examples/resources/minimal.rc -o build/minimal.res.o
x86_64-w64-mingw32-gcc -mwindows -o build/myapp.exe \
  build/track-a-myapp/myapp.c build/minimal.res.o \
  -luser32 -lgdi32 -lcomctl32
```

Load the icon from Vala with `LoadIconW(hInstance, MAKEINTRESOURCE(IDI_APP))` once `IDI_APP` is visible to the linker via the resource object.

## Meson (optional)

A `custom_target` can run `windres` and add the `.o` to the same `custom_target` link line as the Track A demos in `meson.build`. We keep the in-repo spike as **documentation + `minimal.rc`** so the default build does not require `windres` or icon files.

## Metadata note

Constants like `IDC_ARROW` live in `UI.WindowsAndMessaging.json` but are not always emitted as Vala `const` (declaration-only vs enum split). Demos may use the numeric resource id (32512) until the generator exposes the constant.
