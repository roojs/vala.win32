# Phase 6e — API gap report

**Parent plan:** [8. phase 6 full api coverage.md](../plans/8.%20phase%206%20full%20api%20coverage.md)  
**Evidence:** [6a-coverage-matrix.md](6a-coverage-matrix.md) · [6b-filter-trials.md](6b-filter-trials.md) · `ergonomic-widgets-demo` (Track B integration)

**Status:** Published after **6a–6c**; **6d (Track A spikes) skipped** by decision below.

---

## Executive summary

vala.win32 can compile a **large filtered slice** of win32json GUI metadata into vapi shards and expose a **growing Track B widget layer** (`Win32.*` classes with signals/properties). We are **not** at “full Windows GUI API coverage,” and we do **not** need Track A reference apps to know that.

| Question | Answer |
|----------|--------|
| Can we bind most GUI symbols we filter? | **Yes** — 12 shards, ~11k filtered symbols (see 6a). |
| Can we ship ergonomic apps without raw `create_window_ex`? | **Yes** for the profiled set + hand helpers (`GroupBox`, `ControlFont`, list/tree/tab helpers). |
| What blocks “full API”? | **Profile/dispatch work**, **runtime/Wine**, **optional shards**, **WebView2**, and **symbols missing from filter/vapi**. |
| Is Track A required? | **No** — see [6d decision](#6d-track-a-reference-apps--skipped). |

---

## What works today (evidence)

### Vapi (Track A surface, generated)

- **12 JSON files** in `metadata/win32json-api.files` → `vapi/win32-*.vapi` (see 6a shard table).
- **`gui.filter`** + ANSI skip policy; regen via `meson compile -C build` / `generate-binding`.
- **`compile-check`** — Track A posix examples + Track B ergonomic exes build under MinGW.

### Generated infrastructure

- `generated/win32-ui-control-strings.vala` — `WC_*` / class name constants.
- `generated/win32-wide-strings.vala` — UTF-16 helpers.
- `generated/win32-widgets.vala` — dispatch shell, `Win32.Window`, **22** catalog widget classes.

### Track B profiles (`metadata/widget-conventions.json`)

**10 profiled** (signals/dispatch): `Button`, `Edit`, `Label`, `ListBox`, `ComboBox`, `ScrollBar`, `ProgressBar`, `ListView`, `TreeView`, `TabControl`.

**Runtime init:** `ensure_common_controls()` → `InitCommonControlsEx` in widget template (6c); used by commctrl profiled widgets.

**Hand-maintained in template (not catalog entries):** `GroupBox`, `ControlFont`, `NativeDialogs`, menu types, `WidgetDispatch` debug.

**Helpers on profiled commctrl:** `ListView.add_column` / `append_row`, `TreeView.add_root` / `add_child`, `TabControl.add_page`.

### Demos

| Track | Count | Role |
|-------|------:|------|
| A | 6 | Historical/raw vapi spikes (`button-demo`, `hello-window`, …) |
| B | **6** | Product-shaped APIs — **`ergonomic-widgets-demo`** exercises profiled + catalog shells |

---

## 6d — Track A reference apps — **skipped**

**Decision:** Do not add “one Track A demo per missing family.”

**Rationale:**

- Track B **`ergonomic-widgets-demo`** already smoke-tests **WM_COMMAND**, **WM_NOTIFY**, catalog shells (toolbar, month calendar, date/time, tooltips), and layout helpers.
- Track A duplicates generator output (`create_window_ex`, `SendMessage`, struct literals) without advancing the product goal.
- Raw vapi remains available for debugging; it is not a deliverable gate.

**If we need more coverage:** extend **profiles** and **ergonomic-widgets-demo**, not parallel Track A apps.

---

## Gap categories

### 1. Catalog shells (12 classes) — **next profile work**

These compile as minimal `Win32.*` wrappers (**no** signals, **no** `WM_*` dispatch):

| WC symbol | Vala class | Typical blocker for profile |
|-----------|------------|-----------------------------|
| `DATETIMEPICK_CLASS` | DateTimePicker | `WM_NOTIFY` codes + value API |
| `MONTHCAL_CLASS` | MonthCalendar | `WM_NOTIFY` / date range API |
| `TOOLBARCLASSNAME` | Toolbar | `TB_*` messages, button structs |
| `TOOLTIPS_CLASS` | ToolTips | `TTM_*` tool info structs |
| `WC_COMBOBOXEX` | ComboBoxEx32 | Ex messages + image lists |
| `WC_HEADER` | SysHeader32 | `HDM_*`, custom draw |
| `WC_IPADDRESS` | SysIPAddress32 | `IPM_*` |
| `WC_LINK` | SysLink | `LM_*` / notify |
| `WC_NATIVEFONTCTL` | NativeFontCtl | font picker messages |
| `WC_PAGESCROLLER` | SysPager | pager + buddy window |
| `WC_LISTVIE` / `WC_TREEVIE` | duplicate shells | metadata aliases; deduped in catalog |

**Not a vapi gap** — symbols are in `win32-ui-controls.vapi`; gap is **Track B profile + dispatch route** (and sometimes helper methods).

### 2. Generator / relay gaps

| Item | Severity | Notes |
|------|----------|-------|
| `WM_SETFONT` | Low | Not in filtered vapi; template uses `0x0030` constant |
| `TVI_ROOT` / `TVI_LAST` | Low | Not in vapi; tree helpers use documented literals (MinGW header clash if mixed with prologue) |
| `IDC_ARROW` | Low | menu-demo uses local const; could emit from metadata |
| `WM_*` notify constants | Medium | Some profiles use `wm_notify_code_expr` hex literals when const not emitted |
| PBM_/LVM_/TVM_ in app code | **Fixed** | Moved into widget helpers / `uint_constant_expr` in emitter |
| comctl32 **v6 manifest** | Medium | Only `ergonomic-widgets-demo` embeds manifest; other exes use older themed behavior |
| **WebView2** | Phase 7 plan | Not in win32json; see [9. phase 7 webview2 research and integration.md](../plans/9.%20phase%207%20webview2%20research%20and%20integration.md) |

### 3. Vala / ergonomics limits

| Limit | Impact |
|-------|--------|
| No layout engine | All demos use manual **x/y/width/height** |
| `void*` HWND in helpers | `add_child` returns parent item handle for trees |
| GObject **signals** only where profiled | Shell widgets are “create-only” |
| GLib required for Track B | `--profile=gobject`; Track A stays posix |
| Wide strings | `WideString` / `window_text_set` in generated layer — apps should not call GDI directly |

### 4. Filter / shard scope

| Item | Notes |
|------|-------|
| **Optional JSON** (Animation, Ribbon, Xaml, …) | Commented in `win32json-api.files` — deliberate narrow scope (6b trial 2 deferred) |
| **RichEdit** shard | Vendored + compiles; **no** demo or widget |
| **Shell** shards | Large surface; only touched by existing app patterns, not control catalog |
| **Accessibility / HiDpi** | In vapi; no widget story |

### 5. Runtime / Wine (**6f** pending)

| Item | Notes |
|------|-------|
| Wine vs Windows | Themed commctrl (manifest) and some shells differ; toolbar/month cal called out in demo status text |
| Automated Wine matrix | Not in CI; manual `wine build/*.exe` (README) |
| `WIN32_WIDGET_DEBUG` | Traces dispatch; useful for WM_NOTIFY tuning |

---

## Hard blockers vs soft gaps

**Hard blockers** (stop claiming “full API”):

1. **Unprofiled catalog shells** — no ergonomic signal story.
2. **WebView2 / modern host** — Phase 7 plan ([9. phase 7 webview2](../plans/9.%20phase%207%20webview2%20research%20and%20integration.md)); hand vapi + C plumbing, not win32json.
3. **Full win32json** — 42k-line monolith explicitly out of scope.

**Soft gaps** (incremental):

1. More `widget-conventions.json` profiles + `WM_NOTIFY` registry entries.
2. Widget helpers (like list/tree/tab) for shells that need repetitive messages.
3. Optional shard trials when a feature traces to a new JSON file.
4. Shared application manifest for themed controls on all Track B exes.
5. Wine smoke notes in matrix (6f).

---

## Recommended next work (priority)

1. **Profiles** for high-value shells: `Toolbar`, `MonthCalendar`, `DateTimePicker` (demo already lays them out).
2. **6f** — Wine pass; record pass/fail in 6a matrix or a short `6f-wine-smoke.md`.
3. **Phase 7** — Valadoc/README only for APIs evidenced here and in demos.
4. **WebView2** — Phase 7: MinGW cross-build + Windows validation; Wine best-effort only ([plan](../plans/9.%20phase%207%20webview2%20research%20and%20integration.md)).

---

## Maintenance

| Artifact | Regenerate |
|----------|------------|
| [6a-coverage-matrix.md](6a-coverage-matrix.md) | `meson compile -C build coverage-report` |
| This report | Update when profiles/demos/decisions change; snapshot counts should match 6a |

**Phase 6 closure (revised):** **6a–6c ✅** · **6d skipped** · **6e ✅ (this doc)** · **6f ⏳**
