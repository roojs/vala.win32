# 05 — Phase 3: Common controls

**Status:** **✅** Track A complete · **🌗** Track B — B0–B3 done; **B4 next**

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **Depends on:** [04 - phase 2 ergonomic vapi.md](04%20-%20phase%202%20ergonomic%20vapi.md) (hello-window on generated vapi)

---

## Progress at a glance

| Step / area | Status | Notes |
|-------------|--------|-------|
| Step 0 — Button spike | **✅** | app + build only |
| Step 1 — Gap pass (generator) | **✅** | `WC_*` → generated `.vala`; `loword`/`hiword` in vapi |
| Step 2 — Edit spike | **✅** | `WC_EDIT`, `set_window_text` / `get_window_text` in button-demo |
| Step 3 — Static / ListBox / ComboBox / ScrollBar / ProgressBar | **✅** | full common-controls demo |
| Step 4 — plain UTF-8 strings | **✅** | **`win32-wide-strings.vala`** |
| Track B — ergonomic wrappers | **🌗** | B0–B3 done; **gobject profile**; widgets **regen** from template; **B4** ScrollBar/ProgressBar next |

**Legend:** **✅** done · **⏳** open / partial · **❌** blocked

### Step completion block (use on every **✅** step)

Each finished step gets a **`### Changes`** subsection **before** behaviour notes. Answer these in order — that is how you tell generator work from demo hacks:

1. **Generator** — `src/Generate/*` changed? (yes/no + one line)
2. **Generated vapi** — `vapi/win32-*.vapi` regen diff? (yes/no + which symbols landed)
3. **Generated vala** — `generated/*.vala` regen diff? (yes/no — when Vala vapi cannot hold const values, e.g. `WC_*`)
4. **Hand vapi / stubs** — new or edited hand `.vapi`? (yes/no)
5. **Header relay** — new `cheader_filename` / `#include` workarounds? (yes/no — separate from “namespace already points at `windows.h`”)
6. **Metadata / vendor** — `win32json-api.files`, filters, vendor script? (yes/no)
7. **Files changed** — bullet list of paths touched this step
8. **App workarounds** — symbols or logic living **only** in example source because vapi is not ready yet (empty if none)
9. **Binding surface used** — what the demo imports from generated/hand vapi (unchanged counts if prior phase)

Optional follow-ups (polish, not step blockers) go **outside** a step’s **`### Changes`** — use a parent bullet plus one nested **suggested** bullet (see **`BN_*`** under “What we already have”).

**⏳** steps omit **`### Changes`** until done; list intended touch points in the step body instead.

---

## Purpose

Prove that **generated vapi** is enough to build real child controls — not just a top-level window.

**Approach:** one control at a time. Start with **Button**, write a tiny example, see what breaks or is missing in the generator/metadata, fix that, then move to **Edit**, then the rest.

**🚫** No `src/win32/*.vala` monolith library. **🚫** No per-control `.c` in the binding repo unless Vala truly cannot relay (same rule as Phase 2).

---

## Two tracks (same idea as Phase 2)

| Track | Goal | Phase 3 required? | Status |
|-------|------|-------------------|--------|
| **A — raw Win32 controls** | `examples/button-demo.vala`: all standard child controls | **Yes** | **✅** Step 3 complete |
| **B — ergonomic wrappers** | `Win32.*` classes, Vala `signal`s, `--profile=gobject` + MinGW GLib | **No** — after Track A works | **🌗** B0 + B1 done |

Track A is “use the vapi we already generate.” Track B is Gtk-*like* sugar on top — only after we know the raw surface is right.

---

## What we already have (before Phase 3 starts)

| Item | Status |
|------|--------|
| `UI.Controls.json` vendored | **✅** in `win32json-api.files` → `win32-ui-controls.vapi` |
| `UI.WindowsAndMessaging.json` | **✅** → `create_window_ex`, message loop, `WM_COMMAND`, `BN_CLICKED` (declaration-only const) |
| Enum emit (`WindowStyle`, …) | **✅** Phase 2 |
| Control class strings (`WC_BUTTON`, `WC_EDIT`, …) | **✅** — `generated/win32-ui-control-strings.vala` from `UI.Controls.json` (`WC_*` only; Vala vapi cannot hold string const values) |
| `BN_*` as enums | **⏳** metadata has them as constants (not blocking Track A demos) |
| `LOWORD` / `HIWORD` helpers | **✅** — `loword` / `hiword` in `win32-ui-windowsandmessaging.vapi` (inline; not in win32metadata) |

So Phase 3 is **not** “vendor more JSON first.” It is mostly **make a demo, list gaps, extend the generator**, repeat.

**Optional later (not blocking any Track A step):**

- **`BN_*` notification enum** — metadata exposes these as declaration-only constants today; demos use `BN_CLICKED` directly.
  - Emit a small notification enum in the generator if we want nicer `WM_COMMAND` unpacking (readability only; defer).

---

## Step 0 — Button spike (Track A entry point) **✅ Done**

### Changes

- **Generator:** **No** — `src/Generate/*` untouched.
- **Generated vapi:** **No** — no regen diff; uses Phase 2 shards as committed.
- **Hand vapi / stubs:** **No** — same pkgs as hello (`win32-ui-windowsandmessaging`, `win32-system-stub`).
- **Header relay:** **No new** — demo does not add `#include` or extra `[CCode (cheader_filename = …)]`; existing generated namespace already relays declaration-only consts to `windows.h`.
- **Metadata / vendor:** **No**.

**Files changed:**

- `examples/button-demo.vala` — new demo
- `meson.build` — `button-demo` in `example_apps`
- `README.md` — build / run lines for `button-demo.exe`
- `docs/plans/05 - phase 3 common controls.md` — this plan

**App workarounds** (example source only — fix in Step 1 generator pass):

- UTF-16 `"Button"` class string — `WC_BUTTON` not emitted yet
- `wm_command_notify()` / `wm_command_id()` — `LOWORD` / `HIWORD` not in vapi

**Binding surface used** (already generated — not added this step):

- `WM_COMMAND`, `BN_CLICKED`, `BS_DEFPUSHBUTTON` — declaration-only `public const` in `win32-ui-windowsandmessaging.vapi`
- `WindowStyle`, `SysColorIndex`, `create_window_ex`, message loop — Phase 2 generator

**Deliverable:** **✅** `examples/button-demo.vala` + builds with `meson compile -C build` (same as hello).

**Behaviour:**

1. **✅** Top-level window (copy pattern from `hello-window.vala`).
2. **✅** Child button: `create_window_ex` with class **`"Button"`** (wide string literal until `WC_BUTTON` is emitted).
3. **✅** In `WndProc`, on **`WM_COMMAND`**: if notification is **`BN_CLICKED`**, update title to `"Clicked!"` (prove click works).
4. **✅** Close window → clean exit (`WM_DESTROY`).

**Packages (expected):**

- **✅** `win32-ui-windowsandmessaging` — window, messages, `BN_CLICKED`, `WM_COMMAND`
- **✅** `win32-system-stub` — `get_module_handle`
- **✅** `win32-ui-controls` — not needed for Step 0 (symbols came from WindowsAndMessaging + `windows.h`)

**WM_COMMAND unpacking (raw C style in Vala):**

- **✅** `LOWORD (w_param)` → notification code — demo uses `wm_command_notify()` (inline shifts)
- **✅** `HIWORD (w_param)` → control ID — demo uses `wm_command_id()`
- **✅** `l_param` → child `HWND` — not needed for this demo

Document in the example or a one-line comment; add generator helpers later if we want.

---

## Step 1 — Gap pass from Button spike **✅ Done**

### Changes

- **Generator:** **Yes** — `VapiEmitter` (string `WC_*` → `.vala`, `loword`/`hiword`, cross-shard delegate refs, skip Ansi struct variants), `NameMapper.skip_ansi_variant_name`, `generate-binding` writes companion `.vala`.
- **Generated vapi:** **Yes** — regen all shards; `loword`/`hiword` at end of `win32-ui-windowsandmessaging.vapi`; `win32-ui-controls.vapi` smaller (Ansi `PROPSHEETPAGEA_*` skipped; `DLGPROC` fields qualified).
- **Generated vala:** **Yes** — `generated/win32-ui-control-strings.vala` (`WC_*` UTF-16 arrays from metadata `ValueText`). **Not vapi** — Vala rejects const values in `.vapi` files (same Phase 2 limitation).
- **Hand vapi / stubs:** **No**.
- **Header relay:** **No new** — `WC_*` are pure Vala literals; `BN_*` / `BS_*` still declaration-only via existing `windows.h` namespace.
- **Metadata / vendor:** **No**.

**Files changed:**

- `src/Generate/VapiEmitter.vala`
- `src/Generate/NameMapper.vala`
- `tools/generate-binding.vala`
- `vapi/win32-*.vapi` — regen
- `generated/win32-ui-control-strings.vala` — regen (new)
- `examples/button-demo.vala` — uses `WC_BUTTON`, `loword`/`hiword`; drops Step 0 workarounds
- `meson.build` — per-app pkgs; button-demo compiles companion `.vala`
- `docs/plans/05 - phase 3 common controls.md` — this plan

**App workarounds removed:**

- UTF-16 `"Button"` literal → **`WC_BUTTON`** from generated `.vala`
- `wm_command_notify` / `wm_command_id` → **`loword` / `hiword`** from vapi

| Gap | Status |
|-----|--------|
| `WC_BUTTON` string constant | **✅** — `generated/win32-ui-control-strings.vala` |
| `LOWORD` / `HIWORD` | **✅** — `loword` / `hiword` in `win32-ui-windowsandmessaging.vapi` |
| `BN_CLICKED` / `BS_*` | **✅** — declaration-only const from `windows.h` |
| WndProc assign warning | **✅** — not a functional blocker |
| Ergonomic `signal clicked` | **⏳** Track B — later |

---

## Step 2 — Edit spike **✅ Done**

### Changes

- **Generator:** **No** — existing `WC_EDIT` in `generated/win32-ui-control-strings.vala`; `set_window_text` / `get_window_text` / `get_window_text_length` already in `win32-ui-windowsandmessaging.vapi`.
- **Generated vapi:** **No** — no regen diff.
- **Generated vala:** **No**.
- **Hand vapi / stubs:** **No**.
- **Header relay:** **No new**.
- **Metadata / vendor:** **No**.

**Files changed:**

- `examples/button-demo.vala` — child Edit (`WC_EDIT`), initial text via `set_window_text`, button click reads edit via `get_window_text` and copies to frame title; fixed `WM_COMMAND` unpack (`LOWORD` = control ID, `HIWORD` = notification)
- `README.md` — button-demo run line
- `docs/plans/05 - phase 3 common controls.md` — this plan

**App workarounds:**

- **`ES_AUTOHSCROLL`** — local `0x0080` literal (not in filtered vapi yet; standard Win32 value)

**Binding surface used:**

- `WC_EDIT` — `generated/win32-ui-control-strings.vala`
- `set_window_text`, `get_window_text` — `win32-ui-windowsandmessaging.vapi`
- `WindowStyle.WS_BORDER`, `WS_TABSTOP`, … — generated enum

**Deliverable:** **✅** extend `examples/button-demo.vala` (Button + Edit in one demo).

**Behaviour:**

1. **✅** Child **Edit** (`WC_EDIT`) below the button.
2. **✅** **`set_window_text`** sets initial `"Hello, Edit"`.
3. **✅** Button click **`get_window_text`** from edit → **`set_window_text`** on top-level window (title shows edit contents).

---

## Step 3 — Widen controls (priority order) **✅ Done**

### Changes

- **Generator:** **Yes** — `LPARAM` / `LRESULT` → **`int64`** (Win64 pointer fix); emit **`PROGRESS_CLASS`** in `generated/win32-ui-control-strings.vala` (not `WC_*`-prefixed).
- **Generated vapi:** **Yes** — regen (`int64` `LPARAM`/`LRESULT`).
- **Generated vala:** **Yes** — regen; adds **`PROGRESS_CLASS`** UTF-16 literal.
- **Hand vapi / stubs:** **No**.
- **Header relay:** **No new** — `PBM_*` live in `commctrl.h`; demo uses numeric message literals until vapi relays that header.
- **Metadata / vendor:** **No**.

**Files changed:**

- `src/Generate/VapiEmitter.vala` — `LPARAM`/`LRESULT` → `int64`; `PROGRESS_CLASS` in control-class `.vala` emit
- `vapi/win32-*.vapi` — regen
- `generated/win32-ui-control-strings.vala` — regen (`PROGRESS_CLASS`)
- `examples/button-demo.vala` — P1 + P2 controls; scroll → progress sync
- `examples/hello-window.vala` — `WndProc` `int64`
- `meson.build` — link **`comctl32`** (progress bar class)
- `README.md`, `docs/plans/05 - phase 3 common controls.md`

**App workarounds:**

- **`LBS_NOTIFY`**, **`ES_AUTOHSCROLL`** — local style literals (`0x0001`, `0x0080`)
- **`PBM_SETPOS`**, **`PBM_SETRANGE32`**, **`PBS_SMOOTH`** — local `WM_USER` offsets (`0x0402`, …); not in `windows.h` relay path yet

**Binding surface used:**

- `WC_STATIC`, `WC_LISTBOX`, `WC_COMBOBOX`, `WC_SCROLLBAR`, **`PROGRESS_CLASS`** — generated `.vala`
- `SBM_*`, `SBS_HORZ`, `WM_HSCROLL`, list/combo/button messages — `win32-ui-windowsandmessaging.vapi`

**Deliverable:** **✅** all planned Track A controls in `examples/button-demo.vala`.

| Control | Priority | Why | Status |
|---------|----------|-----|--------|
| **Static** | P1 | labels next to inputs | **✅** |
| **ListBox** | P1 | selection model | **✅** |
| **ComboBox** | P1 | common in dialogs | **✅** |
| **ScrollBar** | P2 | less common in minimal apps | **✅** |
| **ProgressBar** | P2 | nice for later polish | **✅** |

**Behaviour:**

1. **✅ Static** — `"Name:"`, `"List:"`, `"Pick:"`, `"Scroll:"`, `"Progress:"` labels.
2. **✅ ListBox** — Red / Green / Blue; **`LBN_SELCHANGE`** → frame title.
3. **✅ ComboBox** — Small / Medium / Large; **`CBN_SELCHANGE`** → frame title.
4. **✅ Button** — copies edit text to title.
5. **✅ ScrollBar** — horizontal `WC_SCROLLBAR`; **`WM_HSCROLL`** updates progress.
6. **✅ ProgressBar** — `PROGRESS_CLASS`; position follows scrollbar via **`PBM_SETPOS`**.

**Optional later (not blocking):**

- Relay **`commctrl.h`** in vapi (or emit `PBM_*` / `InitCommonControlsEx`) so demos drop numeric message literals.
  - Same pattern as `WC_*` → `.vala`; progress messages are not declaration-only in `windows.h`.

---

## Step 4 — Plain UTF-8 strings in examples **✅ Done**

**Problem:** Examples used hand-built **`const uint16[] { 'v', 'a', …, 0 }`** because **`--profile=posix`** has no GLib — no **`string.to_utf16()`**, no **`unichar`**. That noise obscured the actual Win32 API lessons.

**Goal:** Apps pass normal **`string`** literals; conversion to **`LPCWSTR`** lives in one companion file shared by Track A demos and Track B widgets.

**Solution:** **`generated/win32-wide-strings.vala`** (`namespace Win32.Ui`):

| API | Role |
|-----|------|
| **`WideString (text)`** | UTF-8 → UTF-16 buffer; keep alive while Win32 holds **`ptr`** (registered class name) |
| **`wide.ptr`** | Pass to **`create_window_ex`**, **`lpszClassName`**, list/combo add, … |
| **`window_text_get (hwnd)`** | **`GetWindowTextW`** → UTF-8 **`string`** |
| **`window_text_set (hwnd, text)`** | UTF-8 → wide → **`SetWindowTextW`** |

**Implementation note:** Pure Vala UTF-8 decoder (byte walk via **`char*`**); no GLib, no extra C.

### Changes

- **Generator:** **No** — hand companion (emit in generator later, same bucket as **`WC_*`** `.vala`).
- **Generated vapi:** **No**.
- **Examples:** **`hello-window.vala`**, **`button-demo.vala`**, **`ergonomic-button-demo.vala`** — drop all **`const uint16[]`** app strings.
- **Track B widgets:** **`Win32.Window` / `Button`** ctors take **`string`**; delegate to **`WideString`** + **`window_text_*`**.

**Files changed:**

- `generated/win32-wide-strings.vala` — new
- `examples/hello-window.vala`, `examples/button-demo.vala`, `examples/ergonomic-button-demo.vala`
- `generated/win32-widgets.vala` — **`string`** ctors; shared text helpers
- `meson.build` — link wide-strings into all examples
- `docs/plans/04 - phase 2 ergonomic vapi.md`, `docs/plans/05 - phase 3 common controls.md`

**Prerequisite for B3:** plain **`string`** at the app call site (this step). **Next Track B step:** **B3** generator emit — not blocked on anything else.

---

## Track B — ergonomic layer (optional in Phase 3) **🌗 B0 + B1 + B2 done**

**Prerequisite:** Track A is **✅** — raw `create_window_ex` + `WM_COMMAND` / `WM_HSCROLL` paths work in `button-demo.vala`. Safe to start Track B.

### Goal

**🔷** Gtk-*like* call sites on top of relay-only vapi — **`public class`** widgets under **`--profile=gobject`**.

- **`new Win32.Button (…)`**, Vala **`signal`s** (`clicked.connect`, …), **`text` / `title` properties**
- Hidden **`get_module_handle`**, default **`WndProc`**, **`frame.run ()`** message loop
- **`generated/win32-widgets.vala`** — **✅** regen from `src/Generate/templates/win32-widgets.vala` via **`WidgetEmitter`**
- **Requires MinGW GLib** — `./scripts/setup-mingw-libs.sh` (same trade as normal Vala / [emrevit/vala-win32](https://github.com/emrevit/vala-win32))

**Track A** stays **`--profile=posix`** for raw demos. Users who want lean Win32 use Track A, not a second widget layer.

**🚫 `[Compact]` + signals** — Vala rejects signals on compact classes (any profile). Use **`public class`**, not `[Compact]`.

**🚫** No posix struct widget layer — dropped after B-GObject spike (duplicate plumbing, worse API).

**ℹ️** Parent: [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) § architecture · [04 - phase 2 ergonomic vapi.md](04%20-%20phase%202%20ergonomic%20vapi.md) Track B notes.

---

### Target API (what “done” looks like)

Track A today (`button-demo.vala`):

```vala
// WndProc — manual unpack for every control
if (msg == WM_COMMAND) {
    var id = loword (w_param);
    var code = hiword (w_param);
    if (id == ID_CLICK_ME && code == BN_CLICKED) { … }
}
// create_window_ex (0, WC_BUTTON, BUTTON_LABEL, btn_style, …, (void*) ID_CLICK_ME, …);
```

Track B implemented (`examples/ergonomic-button-demo.vala`):

```vala
var frame = new Win32.Window ("ValaWin32Ergo", "vala.win32 ergo", 360, 120);
var name_edit = new Win32.Edit (frame, 72, 12, 260, 24, ID_EDIT);
name_edit.text = "Hello, Edit";
var click_btn = new Win32.Button (frame, 20, 44, 120, 32, ID_CLICK_ME, "Click me");
click_btn.clicked.connect (() => { frame.title = name_edit.text; });
return frame.run ();
```

**🔷** No app **`get_module_handle`**, **`window_proc`**, or manual message loop.

---

### Vala construction syntax (B0–B2 actual)

**✅ GObject `public class`** — `new Win32.Edit (frame, x, y, w, h, id)` creates the HWND in the ctor body.

**✅ Text at call site** — plain **`string`** literals; widgets use **`WideString`** / **`window_text_*`** internally (Step 4):

```vala
var frame = new Win32.Window ("ValaWin32Ergo", "vala.win32 ergo", 360, 300);
var name_edit = new Win32.Edit (frame, 72, 12, 260, 24, ID_EDIT);
name_edit.text = "Hello, Edit";
var click_btn = new Win32.Button (frame, 20, 44, 120, 32, ID_CLICK_ME, "Click me");
var color_list = new Win32.ListBox (frame, 20, 84, 320, 80, ID_LIST);
color_list.add_item ("Red");
color_list.selection_changed.connect (() => { frame.title = color_list.selected_text; });
```

**🚫 Named constructor arguments** — `Edit (parent: frame, x: 72, …)` — **not supported** in Vala **0.56.18** (`Named arguments are not supported yet`).

**✅ Gtk-style properties** — **`text` / `title`** properties on **`Edit`** / **`Window`**; Vala **`signal`s** + **`.connect`**.

**ℹ️** GObject **`construct`** properties and **`Object (prop: val)`** are out of scope per overview.

---

### Namespace — flat **`Win32.*`** for compact layer **✅**

**🔷** User decision: compact widgets live directly under **`Win32`**, not under **`Win32.Ui.Ergonomics`** or any extra tier.

| Layer | Namespace | Fully qualified examples |
|-------|-----------|--------------------------|
| **Compact widgets** | **`Win32`** | `Win32.Window (…)`, `Win32.Button (…)`, `Win32.WidgetDispatch.try_wm_command` |
| Raw relay | **`Win32.Ui.WindowsAndMessaging`** | `WM_COMMAND`, `create_window_ex`, `loword`, `get_message` |
| Control class strings | **`Win32.Ui.Controls`** | `WC_BUTTON`, `WC_EDIT` — **inside** widget constructors only |
| System stub | **`Win32.System`** | `get_module_handle` |

**Why this works:**

- Shortest useful qualified names at the call site: **`Win32.Button`** not **`Win32.Ui.Ergonomics.Button`**
- No collision with vapi shards — they use **`Win32.Ui.*`**, **`Win32.System`**, **`Win32.Graphics.*`**; none define **`Win32.Window`** as a class today
- Clear mental model: **`Win32.*`** = app-facing widgets; **`Win32.Ui.*`** = raw generated relay from metadata

**Generated file:** **`generated/win32-widgets.vala`** — `namespace Win32 { … }` holding widget **`public class`**es + internal **`widget_window_proc`** (B3 regen)

**🚫 Rejected:** **`Win32.Ui.Ergonomics`**, **`Win32.Ui.Ergo`**, **`Win32.Ui.Controls.Widgets`**, mixing widgets into **`Win32.Ui.Controls`** with **`WC_*`**

---

### Architecture (three layers, same as overview PDF)

```
  App .vala
    │  click_btn.clicked (delegate)
    │  WidgetDispatch.try_wm_command (w_param)
    ▼
  generated/win32-widgets.vala   ← widget classes `namespace Win32` (B3 regen from template)
  generated/win32-ui-control-strings.vala   ← WC_* (Track A, already exists)
    ▼
  vapi/win32-ui-*.vapi            ← raw create_window_ex, SendMessage, WM_*, BN_* (Track A)
    ▼
  user32.dll / comctl32.dll
```

| Layer | Emitted by | Holds |
|-------|------------|--------|
| Raw relay | `VapiEmitter` → `vapi/` | extern C API, enums, `loword`/`hiword` |
| String consts | `VapiEmitter` → `generated/win32-ui-control-strings.vala` | `WC_*`, `PROGRESS_CLASS` |
| Ergonomic | **✅** B0–B2 spike → **✅** B3 `WidgetEmitter` → `generated/win32-widgets.vala` | widget **classes**, Vala **signals**, internal WndProc |

**💩** Separate `--pkg` for ergonomic layer — defer; compile companion `.vala` into each example first.

---

### Message routing — how signals fire

Win32 delivers control events to the **parent** `WndProc` (`WM_COMMAND`, `WM_HSCROLL`, …). Delegate callbacks do not magically attach to HWNDs; **`WidgetDispatch`** translates message → **`clicked ()`** / **`changed ()`**.

| Approach | Plumbing C? | App WndProc | Verdict |
|----------|---------------|-------------|---------|
| **A — `WidgetDispatch` registry** | **No** | One call: `try_wm_command (w_param)` (+ `try_wm_hscroll` later) | **✅ default for Track B** |
| **B — Per-control `notify_*` in WndProc** | **No** | `btn.try_notify (w_param); edit.try_notify (w_param);` | **⏳** OK for spike; scales poorly |
| **C — `GWLP_USERDATA` on each HWND** | **No** | Lookup object from `l_param` HWND | **⏳** useful for `WM_HSCROLL` source HWND; optional add-on |
| **D — Subclass proc (`SetWindowSubclass`)** | **Likely yes** | Hidden inside plumbing | **⏳** defer — commctrl + callback thunk |
| **E — Replace top-level `WndProc` entirely** | **Likely yes** | App uses generated `Window.run ()` only | **⏳** Phase 3+ / hello refactor — not first Track B slice |

**Recommended:** central **`WidgetDispatch`** in the **ergonomic namespace** (same file as `Button`, `Edit`, …):

- Each widget registers `(control_id → instance)` at construction
- `Win32.WidgetDispatch.try_wm_command` uses `Win32.Ui.WindowsAndMessaging.loword` / `hiword` internally
- App keeps a thin `window_proc` for **`WM_DESTROY`** / custom logic — same as today

**Why not plumbing C first:** Track A already proves parent `WndProc` + control IDs work. Registry dispatch is pure Vala, testable in Wine, matches “relay-only binding repo.”

**When plumbing C becomes necessary (decision tree):**

1. **⏳** Spike shows Vala **`WndProc` delegate** cannot be stored / forwarded safely for a generated **`Window.run_message_loop()`** — then add **`src/win32-plumbing.c`** (single C callback table, not per-control `.c`)
2. **⏳** We require **automatic** `EN_CHANGE` / `WM_HSCROLL` without parent forwarding — subclass path (D)
3. **⏳** Otherwise — **stay Vala-only**

---

### Control → signal map (first emit set)

Derived from Track A demo behaviour — generator can hardcode this table in Vala (no metadata JSON for signals today).

| Widget | `WC_*` / class | App callback | Win32 notification | Notes |
|--------|----------------|-------------|-------------------|--------|
| **Button** | `WC_BUTTON` | **`clicked (delegate)`** | `BN_CLICKED` via `WM_COMMAND` | **✅** B0 |
| **Edit** | `WC_EDIT` | **`changed (delegate)`** | `EN_CHANGE` via `WM_COMMAND` | **✅** B1 — **`get_text` / `set_text`** |
| **Static** | `WC_STATIC` | — | — | label only; **`text`** property |
| **ListBox** | `WC_LISTBOX` | **`selection_changed`** | `LBN_SELCHANGE` | **✅** B2 — `add_item`, `selected_index`, `selected_text` |
| **ComboBox** | `WC_COMBOBOX` | **`selection_changed`** | `CBN_SELCHANGE` | **✅** B2 — same pattern as list |
| **ScrollBar** | `WC_SCROLLBAR` | `value_changed` | `WM_HSCROLL` / `WM_VSCROLL` | match `l_param` to scrollbar `HWND`; not `WM_COMMAND` |
| **ProgressBar** | `PROGRESS_CLASS` | — | — | property **`value`** / **`range`** via `PBM_*` (literals until `commctrl.h` relay) |

**💩** Top-level **`Window`** with `destroyed` signal — nice for replacing `hello-window.vala` boilerplate; **defer until Button + Edit ergonomic path is proven**.

---

### Widget class shape (B0–B2 actual; generator target for B3)

Namespace **`Win32`** — flat, no **`Ui`** segment. Template: **`src/Generate/templates/win32-widgets.vala`**.

```vala
namespace Win32 {

public class Window {
    public void* handle { get; private set; }
    public Window (string class_name, string title, int width, int height) { … }
    public int run () { … }
    public string title { owned get; set; }
}

public class Button {
    public signal void clicked ();
    public Button (Window parent, …, string label) { … }
}

public class Edit {
    public signal void changed ();
    public string text { owned get; set; }
}

public class ListBox {
    public signal void selection_changed ();
    public void add_item (string text) { … }
    public int selected_index { get; set; }
    public string selected_text { owned get; }
}

public class ComboBox {
    public signal void selection_changed ();
    /* same helpers as ListBox */
}
}
```

**Construction:** **`new Win32.Button (…)`** — gobject **`public class`**. **`WC_*`** stays **`Win32.Ui.Controls`** inside ctor bodies.

**Parent argument:** **`Win32.Window`** — pass **`frame`**, not **`frame.handle`**.

**Dispatch:** internal **`widget_window_proc`** + registry; apps call **`frame.run ()`** only.

**Implementation home:** **`generated/win32-widgets.vala`** (regen). Edit **`src/Generate/templates/win32-widgets.vala`**, then **`meson compile -C build regen`**.

---

### Phased steps (implement in order)

| Step | Scope | Generator? | Deliverable |
|------|--------|------------|-------------|
| **B0 — hand spike** | `Button` + `WidgetDispatch.try_wm_command` | **No** — hand `generated/win32-widgets.vala` | **✅** `examples/ergonomic-button-demo.vala` |
| **B1 — Edit** | `get_text` / `set_text` + `changed (delegate)` | **No** — extend hand file | **✅** same demo: button copies edit like Track A |
| **B2 — ListBox / ComboBox** | `selection_changed` + `add_item` | **No** | **✅** same demo: list/combo → title like Track A |
| **B3 — generator emit** | Move hand file contents into `WidgetEmitter` + template | **Yes** | **✅** `generated/win32-widgets.vala` regen; template `src/Generate/templates/win32-widgets.vala` |
| **B4 — ScrollBar + ProgressBar** | `value_changed`, progress `value` | **Yes** | `try_wm_hscroll`; optional sync like Track A |
| **B5 — Window wrapper** | `destroyed`, message loop helper | **⏳** optional | only after B0–B3 stable; may trigger plumbing C spike |

**🔷** Do **B0 before B3** — validate signal + dispatch ergonomics without locking generator shape too early.

Each finished step gets a **`### Changes`** block (same rules as Track A).

---

### Changes — B0 (hand spike) **✅**

- **Generator:** **No** — hand `generated/win32-widgets.vala`.
- **Widget shape:** **`public class`** under **`--profile=gobject`**; hidden **`widget_window_proc`** + **`frame.run ()`**
- **Demo:** **`examples/ergonomic-button-demo.vala`** — `new Win32.*`, `clicked.connect`, properties

**Files changed:**

- `generated/win32-widgets.vala` — new (hand)
- `examples/ergonomic-button-demo.vala` — new
- `meson.build` — `ergonomic-button-demo` target
- `README.md` — run line
- `docs/plans/05 - phase 3 common controls.md` — this plan

**Spike findings (superseded by gobject decision):**

- **`[Compact]` + `signal`** — **no** (Vala language rule)
- **Posix struct widgets** — dropped; Track A covers lean Win32
- **Gobject `public class`** — **`new`**, **`clicked.connect`**, properties, **`frame.run ()`**

---

### GObject profile decision **✅**

**User decision:** one ergonomic track — **gobject only**. Posix struct/delegate widget layer removed.

| Layer | Profile | Build |
|-------|---------|-------|
| Track A (`hello-window`, `button-demo`) | posix | user32 only |
| Track B (`ergonomic-button-demo`, `win32-widgets.vala`) | gobject | + MinGW GLib (`mingw-libs/`) |

**Files:** `generated/win32-widgets.vala`, `examples/ergonomic-button-demo.vala` — **`public class`**, **`clicked.connect`**, properties, hidden WndProc.

**Removed:** `win32-widgets-gobject.vala`, `ergonomic-button-demo-gobject.vala` (merged into canonical names).

---

### Changes — B1 (Edit) **✅**

- **`Win32.Edit`** — `create_window_ex` + **`text`** property via **`window_text_*`**
- **`changed`** signal — registers **`EN_CHANGE`** in same registry as buttons
- **`Win32.Window`** — **`title`** property for demo title update

**Files changed:**

- `generated/win32-widgets.vala` — `Edit`, edit registry branch
- `examples/ergonomic-button-demo.vala` — edit field + **`frame.title = name_edit.text`** on click

---

### Changes — B2 (ListBox / ComboBox) **✅**

- **`Win32.ListBox`** — **`LBS_NOTIFY`**, **`add_item`**, **`selected_index`**, **`selected_text`**, **`selection_changed`** signal
- **`Win32.ComboBox`** — **`CBS_DROPDOWNLIST`**, same helpers; **`CBN_SELCHANGE`** dispatch
- Registry extended for **`LBN_SELCHANGE`** / **`CBN_SELCHANGE`**

**Files changed:**

- `generated/win32-widgets.vala` — `ListBox`, `ComboBox`, dispatch branches
- `examples/ergonomic-button-demo.vala` — Red/Green/Blue list + Small/Medium/Large combo; selection updates **`frame.title`**

---

### Changes — B3 (generator emit) **✅**

- **`WidgetEmitter`** — reads `src/Generate/templates/win32-widgets.vala`, writes `generated/win32-widgets.vala` with standard generated header
- **`generate-binding`** — emits widgets on every regen (alongside `win32-ui-control-strings.vala`)
- **Template** holds B0–B2 widget layer (dispatch registry fix, `control_id`, debug hooks)

**Files changed:**

- `src/Generate/WidgetEmitter.vala` — new
- `src/Generate/templates/win32-widgets.vala` — new (source of truth)
- `tools/generate-binding.vala` — widget emit
- `meson.build` — `WidgetEmitter.vala` in generator sources
- `generated/win32-widgets.vala` — regen header (`/* Generated by generate-binding … */`)
- `README.md`, `docs/plans/05 - phase 3 common controls.md` — maintainer flow

**Not in B3:** metadata-driven widget codegen; `win32-wide-strings.vala` still hand-maintained.

---

### Generator automation (after B0 spike)

**⏳** No new metadata blobs required — mapping is **convention + hardcoded table** in `src/Generate/`:

- Control name → `WC_*` symbol (already in `win32-ui-control-strings.vala`)
- Signal name → `(WM_*, notification_const)` pairs from Track A demo
- Factory template → `create_window_ex` argument order from `button-demo.vala`

**💩** Parse win32json for “notification enum” emit (`BN_*`, `LBN_*`) — improves raw Track A too; optional polish before or during B3.

**Files (after B3):**

- `src/Generate/WidgetEmitter.vala` — prepend generated header; read template
- `src/Generate/templates/win32-widgets.vala` — source of truth for Track B widgets (B0–B2 body)
- `tools/generate-binding.vala` — writes `generated/win32-widgets.vala` on every regen
- `generated/win32-widgets.vala` — regen output (do not hand-edit)
- `meson.build` — `WidgetEmitter.vala` in `generate-binding` sources
- `src/win32-plumbing.c` — **only if B5 / WndProc spike fails**

---

### Risks and open questions (B0 spike — resolved)

| Question | B0–B2 answer |
|----------|----------------|
| Do Vala **`signal`s on `[Compact]`** compile? | **No** — use **`public class`** under **`--profile=gobject`** |
| Does **`new Button (…)`** work? | **✅** — gobject profile |
| **`Win32.Window`** wrapper in first slice? | **✅** — register class + frame HWND + **`run ()`** |
| **`Gee.HashMap` for dispatch registry?** | **No** — plain fixed array; no extra pkg |
| **Struct array holding widget refs?** | **No** — unboxed `WmCommandEntry` + parallel ref arrays (GBoxed struct copies dropped registry writes) |
| **`get_window_text` → `string`** | **✅** — **`text` / `title` properties** + **`window_text_*`** |
| **ScrollBar** not in `WM_COMMAND` | Separate **`try_wm_hscroll`** — **⏳** B4 |
| **`PBM_*` numeric literals** | Ergonomic **`ProgressBar`** — **⏳** B4 |
| **GC / lifetime** — widgets collected while HWND live? | App holds refs (fields in `main`) — **✅** documented in demo |
| **Replace app `WndProc` entirely** | **Defer** — B5 / plumbing C if needed |

---

### Verification (Track B)

Same build dir; **add** ergonomic demo target:

```bash
meson compile -C build
wine build/ergonomic-button-demo.exe   # GLib DLLs copied into build/ on compile
# wine32:i386 warning is harmless for 64-bit exes; install only if you need 32-bit Wine
# or: ./scripts/run-wine.sh build/ergonomic-button-demo.exe
```

**Phase 3 Track B done when (minimal — B0 + B3):**

- **✅** `ergonomic-button-demo.vala` uses **`click_btn.clicked (delegate)`** — no manual `BN_CLICKED` / `loword` in app
- **✅** `WidgetDispatch.try_wm_command` is the only `WM_COMMAND` unpack in app WndProc
- **✅** `generated/win32-widgets.vala` is **generator output** (B3), not hand-edited
- **✅** `button-demo.vala` unchanged behaviour — raw regression

**Phase 3 Track B stretch (B1–B4):**

- **✅** Edit **`get_text` / `set_text`** + **`changed (delegate)`** in widgets file (demo uses get/set only)
- **⏳** ListBox + ComboBox signals in same or second demo
- **⏳** ScrollBar → ProgressBar via ergonomic API (optional)

---

## Metadata / vendor scope

**Default:** keep current `win32json-api.files` — **✅** **`UI.Controls.json` is already included.**

Widen the list only when a gap trace shows a symbol lives in a **different** JSON blob (e.g. something only in `UI.Controls.Dialogs.json`). Do not add blobs speculatively.

**Filter:** keep Unicode-first policy (`NameMapper.skip_ansi_name`, `gui.filter` excludes).

---

## Intended files

Rolling checklist — each **✅** step’s **`### Changes`** block is the authoritative file list for that step.

| File | Typical role | Step 0 | Step 1+ |
|------|--------------|--------|---------|
| `examples/button-demo.vala` | Track A demo | **✅** new | **✅** drop workarounds |
| `examples/edit-demo.vala` | Edit spike | — | **⏳** |
| `meson.build` | example exes | **✅** | **✅** per-app pkgs |
| `src/Generate/VapiEmitter.vala` | emit fixes | — | **✅** |
| `src/Generate/NameMapper.vala` | naming / skip rules | — | **✅** |
| `vapi/win32-*.vapi` | generated shards | — unchanged | **✅** regen |
| `generated/win32-ui-control-strings.vala` | `WC_*` literals | — | **✅** regen |
| `generated/win32-wide-strings.vala` | UTF-8 ↔ UTF-16 for apps | — | **✅** Step 4 hand → **⏳** generator emit |
| `generated/win32-widgets.vala` | Track B widget layer (`namespace Win32`) | — | **✅** B3 regen (`WidgetEmitter` + template) |
| `examples/ergonomic-button-demo.vala` | Track B demo | — | **✅** B0–B2 |
| `src/win32-plumbing.c` | WndProc thunk if Vala unsafe | — | **⏳** only if B5 spike fails |
| `metadata/win32json-api.files` | vendor list | — unchanged | **⏳** only if gap trace requires |
| Hand stubs (`vapi/win32-system-stub.vapi`, …) | missing JSON symbols | — unchanged | **⏳** only if gap trace requires |

**Not:** regenerate a monolith `win32-ui.vapi` — apps use **`win32-ui-controls`**, **`win32-ui-windowsandmessaging`**, etc.

---

## Verification

Same as Phase 2 — one build dir (builds **hello** and **button-demo**):

```bash
meson setup build
meson compile -C build
wine build/button-demo.exe
```

**✅** `meson compile -C build` produces `build/button-demo.exe`.

**Phase 3 Track A done when:**

- **✅** Button demo opens, click copies edit text to title, window closes cleanly
- **✅** Edit demo (combined with button demo) gets/sets text
- **✅** P1 + P2 controls in demo; scroll bar drives progress bar

**Phase 3 Track B done when (optional — see Track B section for full criteria):**

- **✅** `ergonomic-button-demo.vala`: **`clicked (delegate)`** + `WidgetDispatch.try_wm_command` — no raw `BN_CLICKED` parsing in app
- **✅** `generated/win32-widgets.vala` emitted by generator (B3)

---

## Tasks

### Track A — raw controls (required)

- [x] **✅** **🔷** `button-demo.vala` — child Button + `WM_COMMAND` / `BN_CLICKED`
- [x] **✅** **🔷** Gap pass after Button — `WC_*` generated `.vala`, `loword`/`hiword` in vapi
- [x] **✅** **🔷** Edit spike — `WC_EDIT`, get/set text in `button-demo.vala`
- [x] **✅** **🔷** Gap pass after Edit — no generator gaps (documented style literals only)
- [x] **✅** **🔷** Static, ListBox, ComboBox (P1) — in `button-demo.vala`
- [x] **✅** **🔷** ScrollBar, ProgressBar (P2) — scroll → progress in demo
- [x] **✅** **🔷** **Step 4** — plain **`string`** in examples via **`generated/win32-wide-strings.vala`**

### Track B — ergonomic (optional)

- [x] **✅** **🔷** **B0** — hand `generated/win32-widgets.vala` (`Win32.Button`, `Win32.WidgetDispatch`)
- [x] **✅** **🔷** **B0** — `examples/ergonomic-button-demo.vala` (Track A demo stays raw)
- [x] **✅** **B1** — `Edit` **`get_text` / `set_text`** + **`changed (delegate)`** in widgets file
- [x] **✅** **B2** — ListBox / ComboBox `selection_changed` + demo extension
- [x] **✅** **B3** — `WidgetEmitter` + template → regen `generated/win32-widgets.vala`
- [ ] **⏳** **B4** — ScrollBar / ProgressBar ergonomic API
- [ ] **⏳** **B5** — `Window` wrapper + `win32-plumbing.c` **only if** WndProc spike requires it

---

## Hand-off to Phase 4

**ℹ️** [06 - phase 4 dialogs and resources.md](06%20-%20phase%204%20dialogs%20and%20resources.md) — MessageBox, common dialogs, menus, `.rc` — builds on controls that already work in a child window.
