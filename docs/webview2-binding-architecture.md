# WebView2 binding architecture

## Regenerating metadata (Linux or Windows)

**Where:** [`metadata/webview2/README.md`](../metadata/webview2/README.md)

```bash
./scripts/regen-webview2-json.sh
```

Writes committed [`metadata/webview2/api/WebView2.json`](../metadata/webview2/api/WebView2.json) from the pinned SDK header via [`tools/generate-webview2-json.vala`](../tools/generate-webview2-json.vala). Bash + Vala only in the repo (no PowerShell scripts, no Python).

| Step | Linux | Windows |
|------|-------|---------|
| Regen JSON / vapi | Yes | Yes (MSYS2 bash) |
| Build `webview2-host-demo` | No | Yes (`scripts/build-win.sh`) |
| Run WebView2 in a window | No | Yes (Evergreen runtime) |

## Host layers (Phase 7i)

| File | Role |
|------|------|
| `src/webview2-loader.c` | `WebView2Loader.dll` + `CoInitializeEx` |
| `src/webview2-com-glue.c` | Async env/controller **completed-handler** vtables only |
| `src/webview2-host.vala` | `Navigate`, `put_Bounds`, `close` via **`win32-webview2.vapi`** |
| `vapi/webview2.vapi` | Capture-spike C hooks; host API from `webview2-host.vala` |

COM event-handler vtables stay in C (Vala cannot satisfy raw `IUnknown` prerequisites). Application-facing WebView2 calls use generated bindings.

The capture experiment lives in **`src/webview2-capture-spike.c`** only — see [webview2-capture-investigation.md](webview2-capture-investigation.md).

## Target shape (aligned with the rest of vala.win32)

| Layer | Source | Role |
|-------|--------|------|
| **Generated vapi** | `generate-binding` (Phase 7i) | `Navigate`, `ExecuteScript`, `CapturePreview`, … |
| **Committed JSON** | `regen-webview2-json.sh` | win32json-shaped `metadata/webview2/api/WebView2.json` |
| **Thin runtime glue** | Small C | `WebView2Loader.dll`, async “host ready” setup |
| **Ergonomic API** | `Win32.*` widget layer (later) | What application code calls |
| **Host Vala module** | `src/webview2-host.vala` | `Win32.Ui.WebView` — uses generated COM vapi |

WinMD is optional upstream input; today we scrape the **vendored `WebView2.h`** so Linux can regen the JSON without .NET.

## Regenerating vapi (Phase 7i)

```bash
./scripts/regen-webview2-vapi.sh
```

Or: `meson compile -C build regen-webview2-vapi`

Writes [`vapi/win32-webview2.vapi`](../vapi/win32-webview2.vapi) from committed JSON via `generate-binding` (`Kind: Com` emit). Filter: [`metadata/filters/webview2.filter`](../metadata/filters/webview2.filter).

## Still open

- Expand `metadata/filters/webview2.filter` as apps need more SDK surface.
- Optional: ergonomic `Win32.WebView` widget (7h/7j).

See [9. phase 7 webview2 research and integration.md](plans/9.%20phase%207%20webview2%20research%20and%20integration.md).
