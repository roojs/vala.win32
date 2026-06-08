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
| Build `webview2-host-native` | No | Yes (`scripts/build-win.sh`) |
| Run WebView2 in a window | No | Yes (Evergreen runtime) |

## Host layers (Phase 7i)

| File | Role |
|------|------|
| `src/win32-ui-webview2-sdk.h` | `#pragma GCC system_header` wrapper — silences IID warnings from `WebView2.h` |
| `src/win32-ui-webview2-loader.c` | `WebView2Loader.dll` + `CoInitializeEx` |
| `src/win32-ui-webview2-com-glue.c` | Async env/controller completed-handler vtables; initial `put_Bounds` + `Navigate` |
| `src/win32-ui-webview2-host.vala` | Glue API (`Win32.Ui.WebView`); calls generated vapi on stored COM refs |

**What is generated:** COM types in [`vapi/win32-ui-webview2.vapi`](../vapi/win32-ui-webview2.vapi). Sync COBJMACROS wrappers in [`generated/win32-ui-webview2-com-sync.c`](../generated/win32-ui-webview2-com-sync.c) and glue methods in [`generated/win32-ui-webview2-host-glue.vala`](../generated/win32-ui-webview2-host-glue.vala) are driven by **`WebView2MethodCatalog`**: walks [`metadata/webview2/api/WebView2.json`](../metadata/webview2/api/WebView2.json) + [`metadata/filters/webview2.filter`](../metadata/filters/webview2.filter), with skip/async/`vala_call` overrides in [`metadata/webview2-host-overrides.json`](../metadata/webview2-host-overrides.json). Vala glue calls the wrappers (interface method calls do not vtable-dispatch on MinGW).

**Overrides (small):** `skip` (no emit), `glue_hand` (COM sync only — e.g. `navigate` in host shell), `async_stub_glue` (stub Vala glue, no COM sync), `vala_call` (non-default argument expression, e.g. `put_bounds` → `g_host.bounds`).

**What stays hand-written C:** Loader bootstrap and async completed-handler vtables only.

**What is hand baseline vs generated (glue Vala):** Most of `win32-ui-webview2-host.vala` is repetitive on purpose — it is the **generator template** for glue methods, not logic that should stay hand-maintained long term.

| Region in `host.vala` | Stay hand? | Why |
|-----------------------|------------|-----|
| `HostState`, `g_host` | Yes | Singleton host refs + async state |
| `create_*`, `finish_setup`, `destroy`, `navigate` queue | Yes | WebView2 async bootstrap |
| `apply_bounds`, `set_bounds*`, `on_size` | Yes | Layout + native resize |
| `take_com_string`, `CoTaskMemFree` | Yes (or shared util) | COM string ownership |
| `reload`, `go_back`, `get_source`, … | **No — generate** | Same pattern: ready check → vapi call |

`WebView2MethodCatalog` emits glue, COM sync, and ergo methods/properties from JSON; `ergo_native_map` holds widget shell only (ctor, layout, lifecycle, signals):


```vala
// ergo (generated/win32-ergo-webview2.vala) — generated
public void reload () { Ui.WebView.reload (); }

// glue (win32-ui-webview2-host) — generated
public bool reload () {
    if (!webview_ready ()) return false;
    return com_ok (com_webview_reload (g_host.webview));
}
```

## File naming

| Prefix | Layer | Examples |
|--------|-------|----------|
| `win32-ui-webview2-*` | Glue / COM bindings | `win32-ui-webview2-host.vala`, `vapi/win32-ui-webview2.vapi` |
| `win32-ergo-webview2*` | Ergonomic widget | `generated/win32-ergo-webview2.vala`, `examples/webview2-demo.vala`, future `vapi/win32-ergo-webview2.vapi` |
| `webview2-host-native` | Native Track A demo | `examples/native/webview2-host-native.vala` |
| `webview2-demo` | Track B demo | `examples/webview2-demo.vala` |

**Ergo (generated):** [`generated/win32-ergo-webview2.vala`](../generated/win32-ergo-webview2.vala) — shell from [`src/Generate/templates/win32-ergo-webview2-shell.vala`](../src/Generate/templates/win32-ergo-webview2-shell.vala) (ctor, layout, lifecycle helpers); catalog methods/properties spliced at `@WEBVIEW2_CATALOG@`.

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
| **Ergo widget (generated)** | `generated/win32-ergo-webview2.vala` | `Win32.WebView` — **layout (x,y,w,h)** + navigate API (see table) |

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
| signal `navigation_completed` | `generated/win32-ui-webview2-events.c` + bridge | `add_NavigationCompleted` | done |
| signal `navigation_starting` | generated event handlers | `add_NavigationStarting` | done |
| signal `document_title_changed` | generated event handlers | `add_DocumentTitleChanged` | done |

**Generator rule:** glue/COM sync/ergo from `WebView2.json` method signatures (classify `get_*`/`put_*`/LPCWSTR/void). Ergo delegates `Ui.WebView.<glue_name>(…)`; put/get pairs become properties (`get_is_visible` → `visible`). Overrides: `ergo_skip`, `ergo_bool_methods`, `ergo_property`. Hand shell: `src/win32-ui-webview2-host.vala` (host state, async bootstrap, `navigate` queue).

WinMD is optional upstream input; today we scrape the **vendored `WebView2.h`** so Linux can regen the JSON without .NET.

## Regenerating vapi (Phase 7i)

```bash
./scripts/regen-webview2-vapi.sh
```

Or: `meson compile -C build regen-webview2-vapi`

Writes [`vapi/win32-ui-webview2.vapi`](../vapi/win32-ui-webview2.vapi) from committed JSON via `generate-binding` (`Kind: Com` emit). Filter: [`metadata/filters/webview2.filter`](../metadata/filters/webview2.filter).

## Event wiring (Phase C)

`ergo_events` in [`metadata/webview2-host-overrides.json`](../metadata/webview2-host-overrides.json) drives `WebView2EventEmitter` (C handler vtables + `win32-ui-webview2-events-bridge.vala` delegates). `finish_setup` registers handlers; ergo `WebView` ctor binds delegates to GObject signals.

## Still open

- Expand `metadata/filters/webview2.filter` as apps need more SDK surface.
- More `add_*` events via `ergo_events` rows (e.g. `WebMessageReceived`).

See [9. phase 7 webview2 research and integration.md](plans/9.%20phase%207%20webview2%20research%20and%20integration.md).
