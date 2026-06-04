# WebView2 metadata (committed JSON)

win32json-shaped input for Phase **7i** (`generate-binding` + Com emit).  
**Regenerate on Linux or Windows** (needs vendored SDK + Meson build). **Running the browser host** still requires real Windows.

| File | Role |
|------|------|
| [`api/WebView2.json`](api/WebView2.json) | `ICoreWebView2*` Com interfaces + `COREWEBVIEW2_*` enums |
| [`../webview2-sdk-ref.txt`](../webview2-sdk-ref.txt) | NuGet SDK pin (must match `build/vendor/webview2/`) |

## Regenerate the JSON

**Linux** (or MSYS2 on Windows), from repo root:

```bash
./scripts/vendor-webview2-sdk.sh    # once, if build/vendor/webview2/ is missing
meson setup build                   # once
./scripts/regen-webview2-json.sh
```

That compiles `tools/generate-webview2-json.vala` and writes `metadata/webview2/api/WebView2.json` from  
`build/vendor/webview2/include/WebView2.h` (same SDK pin as the NuGet — not a live WinMD read).

**Windows one-liner** (Samba `X:\vala.win32`):

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /x/vala.win32 && ./scripts/regen-webview2-json.sh'
```

Commit `api/WebView2.json` after regen when the SDK pin changes.

Optional: `BUILD_WINMD=1 ./scripts/regen-webview2-json.sh` also builds `Microsoft.Web.WebView2.Win32.winmd` (needs `dotnet` + `pwsh` on the machine). **Not required** for the JSON file today.

## More context

- [docs/webview2-binding-architecture.md](../../docs/webview2-binding-architecture.md) — pipeline and Phase 7i
- [docs/windows-build.md](../../docs/windows-build.md) — build/run `webview2-host-demo` on Windows

Last regenerated against SDK pin **1.0.2792.45**.
