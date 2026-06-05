# WebView2 binding architecture

## Regenerating metadata (Linux or Windows)

**Where:** [`metadata/webview2/README.md`](../metadata/webview2/README.md)

```bash
./scripts/regen-webview2-json.sh
```

Writes committed [`metadata/webview2/api/WebView2.json`](../metadata/webview2/api/WebView2.json) from the pinned SDK header via [`tools/generate-webview2-json.vala`](../tools/generate-webview2-json.vala). Bash + Vala only in the repo (no PowerShell scripts, no Python).

| Step | Linux | Windows |
|------|-------|---------|
| Regen JSON | Yes | Yes (MSYS2 bash) |
| Cross-compile `webview2-host-demo` | Yes | Yes |
| Run WebView2 in a window | No (use lab PC) | Yes |

## Why `webview2-plumbing.c` is not the long-term API

Phase **7b** added a **host bootstrap** in C (~280 lines): load `WebView2Loader.dll`, create environment/controller, resize on `WM_SIZE`, navigate. That is a temporary spike host, not the final widget API.

The capture experiment lives in **`src/webview2-capture-spike.c`** only — see [webview2-capture-investigation.md](webview2-capture-investigation.md).

## Target shape (aligned with the rest of vala.win32)

| Layer | Source | Role |
|-------|--------|------|
| **Generated vapi** | `generate-binding` (Phase 7i) | `Navigate`, `ExecuteScript`, `CapturePreview`, … |
| **Committed JSON** | `regen-webview2-json.sh` | win32json-shaped `metadata/webview2/api/WebView2.json` |
| **Thin runtime glue** | Small C | `WebView2Loader.dll`, async “host ready” setup |
| **Ergonomic API** | `Win32.*` widget layer (later) | What application code calls |
| **Native plumbing vapi** | `Win32.Ui.WebView` | Phase 7b host (`webview2.vapi`) |

WinMD is optional upstream input; today we scrape the **vendored `WebView2.h`** so Linux can regen the JSON without .NET.

## Regenerating vapi (Phase 7i)

```bash
./scripts/regen-webview2-vapi.sh
```

Or: `meson compile -C build regen-webview2-vapi`

Writes [`vapi/win32-webview2.vapi`](../vapi/win32-webview2.vapi) from committed JSON via `generate-binding` (`Kind: Com` emit). Filter: [`metadata/filters/webview2.filter`](../metadata/filters/webview2.filter).

## Still open after 7i bootstrap

- Shrink `webview2-plumbing.c` to loader-only; migrate demo to generated `ICoreWebView2*` bindings.
- Expand filter / dep types as apps need more of the SDK surface.

See [9. phase 7 webview2 research and integration.md](plans/9.%20phase%207%20webview2%20research%20and%20integration.md).
