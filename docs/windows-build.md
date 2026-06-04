# Windows build and test (vala.win32)

**WebView2 must run on real Windows** with the [Evergreen WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

**Samba / SSH** (same lab as Snappr): [app.Snappr `windows-ssh-remote.md`](../../app.Snappr/docs/windows-ssh-remote.md) — map **`X:`**, then **`cd vala.win32`**. No `C:` mirror needed for Meson builds on the share.

| | |
|--|--|
| Windows SSH | `192.168.88.244`, user `alan` — `ssh snappr-win` |
| Samba | `\\192.168.88.132\gitlive` → **`X:`** |

**Build dir on Windows (gitignored):** **`build-win/`** — native Meson output on the share.

---

## How to run MSYS2 from PowerShell

Do **not** open the MSYS2 / UCRT64 terminal to paste blocks. That paste path is unreliable on this setup.

**Do not** use repo `.ps1` scripts — Windows PowerShell 5.1 misparses long embedded bash.

**Do** use **bash scripts in `scripts/`** and launch each with **one PowerShell line**:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/SOME-SCRIPT.sh'
```

PowerShell only starts MSYS2; **bash** runs the logic.

Repo on `X:` → path `/x/vala.win32` inside the quotes.

| Script | One PowerShell line |
|--------|---------------------|
| MSYS2 toolchain (§3) | `... -c 'cd /x/vala.win32 && ./scripts/setup-msys2-toolchain.sh'` |
| WebView2 SDK only (§5) | `... -c 'cd /x/vala.win32 && ./scripts/vendor-webview2-sdk.sh'` |
| Full `build-win/` compile | `... -c 'cd /x/vala.win32 && ./scripts/build-win.sh'` |

Optional (once per PowerShell session): `function msys { & C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c $args[0] }` then `msys 'cd /x/vala.win32 && ./scripts/setup-msys2-toolchain.sh'`.

---

## Visual Studio vs MSYS2 MinGW — pick one per build

They are **not mixed** in a single executable. You do not link MSVC `.obj` files with MinGW `.obj` files.

| | **Visual Studio (MSVC)** | **MSYS2 MinGW (GCC)** |
|--|--------------------------|------------------------|
| Compilers | `cl.exe`, `link.exe` | `gcc`, `ld` (via `msys2_shell.cmd -ucrt64`) |
| WebView2 loader | **`WebView2LoaderStatic.lib`** (official, static link) | **`WebView2Loader.dll`** only (GNU cannot use the static `.lib`) |
| Microsoft samples | Yes (HelloWebView, WRL) | Possible with extra work; not the default path |
| **This repo today** | **Not wired in Meson yet** | **Yes** — `build-win/` on Windows |
| Vala (`valac`) | No VS integration; still need `valac` on PATH (from MSYS2) | `pacman -S mingw-w64-ucrt-x86_64-vala` |

**Do they work together?** Only as **two steps in a pipeline**, not as one link:

1. **Vala** turns `.vala` → `.c` (tool is almost always **MSYS2 `valac`**, regardless of final compiler).
2. **Either** MSVC **or** MinGW compiles and links that C + `webview2-plumbing.c`.

Our **current** `meson.build` uses **MinGW-style** flags (`-mwindows`, `-lole32`, …). A **Visual Studio / Meson `cl` backend** is the right target for serious WebView2 on Windows (static loader, fewer DLL copies) — tracked as follow-up, not required to *run* the 7b demo.

**Practical recommendation on this PC:**

| Your goal | Use |
|-----------|-----|
| Build and test WebView2 **here** | PowerShell + `msys2_shell.cmd -ucrt64` → `build-win/` (below) |
| Align with Microsoft WebView2 long-term | **Visual Studio 2022 Build Tools** + Windows SDK (install now; Meson MSVC target later) |

---

## One-time setup on Windows

Do these **in order** the first time on a machine. Each step is **one PowerShell line** (run separately; wait for each to finish).

### 1. WebView2 Runtime (required to *run* demos)

```powershell
winget install -e --id Microsoft.EdgeWebView2Runtime
```

Not the same as the **WebView2 SDK** (§5) used at compile time.

### 2. Visual Studio Build Tools (recommended install)

Install **Visual Studio 2022 Build Tools** (or full VS) with:

- Workload: **Desktop development with C++**
- **Windows 10/11 SDK** (same SDK WebView2 expects)

Use **“x64 Native Tools Command Prompt”** or **Developer PowerShell for VS 2022** when you eventually build with `cl`. Flutter/Snappr on the same machine already uses this stack — see [app.Snappr `windows-build.md`](../../app.Snappr/docs/windows-build.md) (VS / `flutter doctor`).

You do **not** need VS to *run* an exe built with MSYS2 MinGW, only to *compile* with MSVC later.

### 3. MSYS2 + compiler tools (required to *build* on Windows)

`winget` only installs the empty MSYS2 shell. Run **3a**, then **3b** (one PowerShell line).

**3a — Install MSYS2:**

```powershell
winget install -e --id MSYS2.MSYS2
```

When it finishes, MSYS2 lives at `C:\msys64`.

**3b — Toolchain + build deps** (one PowerShell line; installs everything `meson` needs for `build-win/`):

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/setup-msys2-toolchain.sh'
```

Installs via pacman (skipped if already present): **gcc**, **binutils**, **vala**, **python** (for meson), **meson**, **ninja**, **libgee**, **json-glib**, **curl**, **unzip**. Safe to run twice.

If `meson setup` still fails after a partial run, wipe the build dir then rebuild:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && rm -rf build-win && ./scripts/build-win.sh'
```

### 4. Map `X:` (desktop testing)

```cmd
net use X: /delete
net use \\192.168.88.132\gitlive /delete
net use X: \\192.168.88.132\gitlive /user:alan * /persistent:yes
X:
cd vala.win32
```

### 5. Vendor WebView2 SDK (build-time only — not the runtime)

Downloads **`Microsoft.Web.WebView2`** from NuGet.org (`.nupkg` = zip). Does **not** install the Evergreen runtime (§1).

One PowerShell line:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/vendor-webview2-sdk.sh'
```

Output: `build/vendor/webview2/include/WebView2.h`, `x64/WebView2Loader.dll` (gitignored).

---

## Build on Windows (MSYS2 + Meson → `build-win/`)

**Prerequisites:** §1 (runtime), §3 (toolchain), §4 (if using `X:`).

**One PowerShell line** (vendors SDK, compiles `webview2-host-demo`):

`build-win.sh` uses a **local** Meson dir (`C:\msys64\tmp\vala-win32-build-win`) — not on `X:` — then copies the `.exe` to `build-win\`. That avoids Samba slowness, huge logs from `--reconfigure`, and a Vala bug where generated `.c` files vanish on UNC paths.

Options: no Track A/B demos, **no full vapi regen** (uses committed `vapi/` + `generated/`), quiet C warnings.

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/build-win.sh'
```

Or step by step: §5 vendor line, then separate `-c` lines for `meson setup build-win` and `meson compile -C build-win webview2-host-demo`.

**Run the demo** at the **logged-on desktop** (Explorer, or):

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32/build-win && ./webview2-host-demo.exe https://example.com/'
```

Or double-click `X:\vala.win32\build-win\webview2-host-demo.exe` after §1 installed the runtime.

`WebView2Loader.dll` must be next to the `.exe` (Meson copies it into `build-win/`).

Other demo:

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && meson compile -C build-win hello-window'
```

---

## Future: native MSVC build in `build-win/`

When Meson is configured for MSVC on Windows (`cl`/`link`), we can:

- Link **`WebView2LoaderStatic.lib`** from the NuGet package (no loader DLL beside the exe).
- Match Microsoft’s WebView2 Win32 samples more closely.

**Still needed:** `valac` on PATH (MSYS2) to generate C; then Meson compiles with `cl`. That is **Vala + MSVC**, not “VS replaces Vala”.

Until that lands, use **MSYS2 `build-win/`** on this machine.

---

## SSH (compile only)

WebView2 UI needs a **desktop session** to test. From an SSH PowerShell session you can still use the same **one-line** `msys2_shell.cmd -ucrt64 -c '...'` pattern.

See Snappr [§E](../../app.Snappr/docs/windows-ssh-remote.md#e-for-agents--llm-remote-windows-build) for UNC/SSH patterns (substitute `vala.win32` for `app.Snappr`).

---

## When compile fails (debug log)

`build-win.sh` copies **everything** (vendor, setup, compile `-v`) to one file on the share:

**`X:\vala.win32\build-win\last-build.log`**

Open that in an editor after a failed run. On error the script also appends toolchain versions and the tail of `meson-logs\meson-log.txt`, and prints the log path again.

| Also useful | Path |
|-------------|------|
| Meson configure detail | `build-win\meson-logs\meson-log.txt` |

Paste the **last ~80 lines** of `build-win\last-build.log` (around `FAILED:` / `error:`) if you need help debugging.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `webview2-host-demo skipped` | Run the §5 vendor line in PowerShell |
| `LoadLibrary WebView2Loader.dll failed` | Run from `build-win/` where Meson copied the DLL |
| Samba access denied on `build-win/` | Map `X:` as `alan` (Snappr §D), not guest |
| Wanted Visual Studio only | Install VS Build Tools anyway; use MSYS2 path above until MSVC Meson is added |
| `valac` not found in cmd | Use the `msys2_shell.cmd -ucrt64 -c '...'` lines, not bare cmd |
| Meson: `msys/python` in a MinGW environment | Rerun §3b setup script (installs `mingw-w64-ucrt-x86_64-python`) |
| `cannot extract .nupkg` / `FileNotFoundError` on `X:` | Sync repo (extracts to `/tmp`). Install unzip: rerun §3b or `... -c 'pacman -S --needed --noconfirm unzip'` |
| `pacman` 404 on `*.sig` / `failed to commit transaction` | **Pacman mirror error** — rerun §3b setup script |
| `gee-0.8` / `json-glib` not found (pkg-config) | Rerun §3b (full package set in `setup-msys2-toolchain.sh`) |
| Meson `unknown keyword arguments "depends"` | Sync repo (fixed: regen runs via `sources`, not `depends` on Vala targets) |
| Meson cross file `/home/.../cross/mingw-w64.ini` on `build-win/` | `build-win/` was configured on Linux — rerun `build-win.sh` (removes stale cross metadata) |
| Meson `build.dat` / version mismatch on `build-win/` | Rerun `build-win.sh` or `rm -rf build-win` then rerun |

### Pacman mirror error (`404` / `failed to commit transaction`)

Rerun the setup script (one PowerShell line):

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/setup-msys2-toolchain.sh'
```

---

## Related

- [README.md](../README.md) — project overview (includes optional cross-compile from a dev machine)
- [9. phase 7 webview2](plans/9.%20phase%207%20webview2%20research%20and%20integration.md)
- [app.Snappr windows-build.md](../../app.Snappr/docs/windows-build.md) — VS + Flutter on the same PC
