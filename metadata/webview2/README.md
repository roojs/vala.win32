# WebView2 metadata (committed JSON)

win32json-shaped input for Phase **7i** (`generate-binding` + Com emit).  
**Regenerate JSON/vapi on Linux or Windows** (needs vendored SDK + Meson build). **`webview2-host-native`** is built only on a Windows host — see [docs/windows-build.md](../../docs/windows-build.md).

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

**Windows one-liner** (`C:\msys64\tmp\vala.win32` rsync mirror):

```powershell
C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c 'cd /c/msys64/tmp/vala.win32 && ./scripts/regen-webview2-json.sh'
```

Commit `api/WebView2.json` after regen when the SDK pin changes.

## Regenerate vapi (COM bindings)

```bash
./scripts/regen-webview2-vapi.sh
```

Writes `vapi/win32-ui-webview2.vapi` (filtered COM subset — see `metadata/filters/webview2.filter`). Ergo widget vapi `win32-ergo-webview2.vapi` is reserved for Phase 7h.

Optional: `BUILD_WINMD=1 ./scripts/regen-webview2-json.sh` also builds `Microsoft.Web.WebView2.Win32.winmd` (needs `dotnet` + `pwsh` on the machine). **Not required** for the JSON file today.

## More context

- [docs/webview2-binding-architecture.md](../../docs/webview2-binding-architecture.md) — pipeline and Phase 7i
- [docs/windows-build.md](../../docs/windows-build.md) — build/run `webview2-host-native` and `webview2-demo` on Windows

Last regenerated against SDK pin **1.0.2792.45**.
