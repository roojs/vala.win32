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
| `src/win32-ui-webview2-sdk.h` | `#pragma GCC system_header` wrapper — silences IID warnings from `WebView2.h` |
| `src/win32-ui-webview2-loader.c` | `WebView2Loader.dll` + `CoInitializeEx` |
| `src/win32-ui-webview2-com-glue.c` | Async env/controller completed-handler vtables; initial `put_Bounds` + `Navigate` |
| `src/win32-ui-webview2-host.vala` | Glue API (`Win32.Ui.WebView`); calls generated vapi on stored COM refs |

**What is generated:** COM interface surface in [`vapi/win32-ui-webview2.vapi`](../vapi/win32-ui-webview2.vapi) — `Navigate`, `GoBack`, `get_DocumentTitle`, etc. Regenerated from committed JSON via `generate-binding`.

**Ergo (7h hand baseline):** [`src/win32-ergo-webview2.vala`](../src/win32-ergo-webview2.vala) — `Win32.WebView` delegates to `Win32.Ui.WebView` glue.

**Call stack (go_back):** `Win32.WebView.go_back` → `Win32.Ui.WebView.go_back` → `ICoreWebView2.go_back` (generated vapi).

**What stays hand-written C:** Loader bootstrap and async completed-handler vtables only (Vala cannot implement raw `IUnknown` vtables). Sync COM calls go through the generated vapi from glue Vala — no per-method C wrappers.

## File naming

| Prefix | Layer | Examples |
|--------|-------|----------|
| `win32-ui-webview2-*` | Glue / COM bindings | `win32-ui-webview2-host.vala`, `vapi/win32-ui-webview2.vapi` |
| `win32-ergo-webview2*` | Ergonomic widget | `src/win32-ergo-webview2.vala`, `examples/webview2-ergo-demo.vala`, future `vapi/win32-ergo-webview2.vapi` |
| `webview2-host-demo` | Native Track A demo | `examples/native/webview2-host-demo.vala` |

**Ergo (7h hand baseline):** [`src/win32-ergo-webview2.vala`](../src/win32-ergo-webview2.vala) — `Win32.WebView` delegates to `Win32.Ui.WebView` glue with aligned names (`navigate`, `create_with_xywh`, …).

**Call stack (navigate):** `Win32.WebView.navigate` → `Win32.Ui.WebView.navigate` → `ICoreWebView2.navigate` (generated vapi).

## Target shape (aligned with the rest of vala.win32)

| Layer | Source | Role |
|-------|--------|------|
| **Generated COM vapi** | `generate-binding` (Phase 7i) | `vapi/win32-ui-webview2.vapi` — raw SDK COM |
| **Generated ergo vapi** | widget codegen (Phase 7h) | `vapi/win32-ergo-webview2.vapi` — app-facing `Win32.WebView` |
| **Committed JSON** | `regen-webview2-json.sh` | win32json-shaped `metadata/webview2/api/WebView2.json` |
| **Thin runtime glue** | `src/win32-ui-webview2-*` | Loader + async host bootstrap |
| **Ergonomic API** | `Win32.*` widget layer (later) | What application code calls |
| **Host Vala module** | `src/win32-ui-webview2-host.vala` | `Win32.Ui.WebView` — glue only (bounds, navigate, async bootstrap) |
| **Ergo widget (hand)** | `src/win32-ergo-webview2.vala` | `Win32.WebView` — **layout (x,y,w,h)** + navigate API (see table) |

**Layout split:** ergo owns `x`, `y`, `width`, `height`, `set_bounds` / `move` / `resize` → glue `set_bounds_xywh` → COM `put_Bounds`. Glue `on_size()` is **native Track A only** (full client rect); ergo uses `resize_with_parent` + `Window.resized` instead.

## Ergo API map (`Win32.WebView` → glue → COM)

Canonical list lives in [`metadata/widget-conventions.json`](../metadata/widget-conventions.json) under `profiles.WebView2.ergo_native_map`. Naming rule: **same snake_case verb as vapi** at ergo and glue layers; glue adds async queue where WebView2 is async.

| Ergo (`Win32.WebView`) | Glue (`Win32.Ui.WebView`) | COM (vapi) | Status |
|------------------------|---------------------------|------------|--------|
| ctor `(parent, x, y, w, h)` | `create_with_xywh` | `CreateCoreWebView2Controller` + `put_Bounds` | done |
| `set_bounds` / `move` / `resize` | `set_bounds_xywh` | `put_Bounds` | done |
| `ready` | `is_ready` | (host state) | done |
| `navigate(url)` | `navigate` | `ICoreWebView2.Navigate` | done |
| `navigate_to_string(html)` | `navigate_to_string` | `NavigateToString` | planned |
| `reload()` | `reload` | `Reload` | planned |
| `stop()` | `stop` | `Stop` | planned |
| `go_back()` / `go_forward()` | `go_back` / `go_forward` | `GoBack` / `GoForward` | planned |
| `execute_script(js)` | `execute_script` | `ExecuteScript` | planned |
| `post_web_message_as_json(json)` | `post_web_message_as_json` | `PostWebMessageAsJson` | planned |
| `source` | `get_source` | `get_Source` | planned |
| `can_go_back` / `can_go_forward` | getters | `get_CanGoBack` / `get_CanGoForward` | planned |
| `document_title` | `get_document_title` | `get_DocumentTitle` | planned |
| `visible` | `put/get_is_visible` | `ICoreWebView2Controller` | planned |
| `zoom_factor` | `put/get_zoom_factor` | `ICoreWebView2Controller` | planned |
| signal `navigation_completed` | COM handler glue | `add_NavigationCompleted` | planned |
| signal `navigation_starting` | COM handler glue | `add_NavigationStarting` | planned |
| signal `document_title_changed` | COM handler glue | `add_DocumentTitleChanged` | planned |

**Generator rule:** ergo method body is one line → `Ui.WebView.<same_name>(…)`. Glue calls generated vapi on stored `ICoreWebView2*` / controller refs. `CoTaskMemFree` for out-string getters lives in glue Vala (`take_com_string`). Event signals need C handler glue in `com-glue.c` (same pattern as env/controller completed handlers).

WinMD is optional upstream input; today we scrape the **vendored `WebView2.h`** so Linux can regen the JSON without .NET.

## Regenerating vapi (Phase 7i)

```bash
./scripts/regen-webview2-vapi.sh
```

Or: `meson compile -C build regen-webview2-vapi`

Writes [`vapi/win32-ui-webview2.vapi`](../vapi/win32-ui-webview2.vapi) from committed JSON via `generate-binding` (`Kind: Com` emit). Filter: [`metadata/filters/webview2.filter`](../metadata/filters/webview2.filter).

## Still open

- Expand `metadata/filters/webview2.filter` as apps need more SDK surface.
- Optional: ergonomic `Win32.WebView` widget (7h/7j).

See [9. phase 7 webview2 research and integration.md](plans/9.%20phase%207%20webview2%20research%20and%20integration.md).
