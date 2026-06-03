# 05 — Phase 3: Common controls

**Status:** **✅** Step 2 done · **⏳** Step 3 Static / ListBox / ComboBox next

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **Depends on:** [04 - phase 2 ergonomic vapi.md](04%20-%20phase%202%20ergonomic%20vapi.md) (hello-window on generated vapi)

---

## Progress at a glance

| Step / area | Status | Notes |
|-------------|--------|-------|
| Step 0 — Button spike | **✅** | app + build only |
| Step 1 — Gap pass (generator) | **✅** | `WC_*` → generated `.vala`; `loword`/`hiword` in vapi |
| Step 2 — Edit spike | **✅** | `WC_EDIT`, `set_window_text` / `get_window_text` in button-demo |
| Step 3 — Static / ListBox / ComboBox | **⏳** | next |
| Track B — ergonomic wrappers | **⏳** | optional, after Track A |

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
| **A — raw Win32 controls** | `examples/button-demo.vala`: Button + Edit, `WM_COMMAND`, get/set text | **Yes** | **✅** Steps 0–2 · **⏳** Step 3 |
| **B — ergonomic wrappers** | `[Compact]` `Button` type, Vala `signal clicked` from generator | **No** — after Track A works | **⏳** |

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

## Step 3 — Widen controls (priority order) **⏳**

Only after Button + Edit demos work:

| Control | Priority | Why | Status |
|---------|----------|-----|--------|
| **Static** | P1 | labels next to inputs | **⏳** |
| **ListBox** | P1 | selection model | **⏳** |
| **ComboBox** | P1 | common in dialogs | **⏳** |
| **ScrollBar** | P2 | less common in minimal apps | **⏳** |
| **ProgressBar** | P2 | nice for later polish | **⏳** |

Each control: **one small example addition** → evaluate gaps → generator/metadata fix. Do not bulk-implement all six upfront.

---

## Track B — ergonomic layer (optional in Phase 3) **⏳**

From Phase 2 plan / overview PDF:

- **⏳** Generator emits **`[Compact] public class Button`** wrapping `HWND` + `create_window_ex` / `SendMessage`
- **⏳** Vala **`signal clicked`** — wired from app `WndProc` forwarding `WM_COMMAND`, or plumbing C if delegate lifetime is unsafe

**Start Track B only when Track A Button demo is stable.** Otherwise we duplicate hello-window’s Phase 2 mistake (ergonomic layer before raw bindings work).

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
- **✅** Gaps found in Step 1 are either **fixed in generator** or **documented** with a conscious workaround

**Phase 3 Track B done when (optional):**

- **⏳** App code can use a generated `Button` (or similar) with `clicked` instead of manual `WM_COMMAND` parsing

---

## Tasks

### Track A — raw controls (required)

- [x] **✅** **🔷** `button-demo.vala` — child Button + `WM_COMMAND` / `BN_CLICKED`
- [x] **✅** **🔷** Gap pass after Button — `WC_*` generated `.vala`, `loword`/`hiword` in vapi
- [x] **✅** **🔷** Edit spike — `WC_EDIT`, get/set text in `button-demo.vala`
- [ ] **🔷** **⏳** Gap pass after Edit (only if Step 2 surfaces generator gaps)
- [ ] **🔷** **⏳** Static, ListBox, ComboBox (P1) — one at a time
- [ ] **🔷** **⏳** ScrollBar, ProgressBar (P2) — if needed

### Track B — ergonomic (optional)

- [ ] **🔷** **⏳** Generator `[Compact]` `Button` + `signal clicked`
- [ ] **🔷** **⏳** `win32-plumbing.c` only if WndProc/signal wiring needs it
- [ ] **🔷** **⏳** Second demo using ergonomic API (not raw `WM_COMMAND`)

---

## Hand-off to Phase 4

**ℹ️** [06 - phase 4 dialogs and resources.md](06%20-%20phase%204%20dialogs%20and%20resources.md) — MessageBox, common dialogs, menus, `.rc` — builds on controls that already work in a child window.
