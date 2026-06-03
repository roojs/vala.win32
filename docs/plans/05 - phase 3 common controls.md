# 05 — Phase 3: Common controls

**Status:** **⏳** Track A step 0 done — gap pass next

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **Depends on:** [04 - phase 2 ergonomic vapi.md](04%20-%20phase%202%20ergonomic%20vapi.md) (hello-window on generated vapi)

---

## Purpose

Prove that **generated vapi** is enough to build real child controls — not just a top-level window.

**Approach:** one control at a time. Start with **Button**, write a tiny example, see what breaks or is missing in the generator/metadata, fix that, then move to **Edit**, then the rest.

**🚫** No `src/win32/*.vala` monolith library. **🚫** No per-control `.c` in the binding repo unless Vala truly cannot relay (same rule as Phase 2).

---

## Two tracks (same idea as Phase 2)

| Track | Goal | Phase 3 required? |
|-------|------|-------------------|
| **A — raw Win32 controls** | `examples/button-demo.vala`: `CreateWindowEx` child `"Button"`, `WM_COMMAND` / `BN_CLICKED`, optional Edit | **Yes** |
| **B — ergonomic wrappers** | `[Compact]` `Button` type, Vala `signal clicked` from generator | **No** — after Track A works |

Track A is “use the vapi we already generate.” Track B is Gtk-*like* sugar on top — only after we know the raw surface is right.

---

## What we already have (before Phase 3 starts)

| Item | Status |
|------|--------|
| `UI.Controls.json` vendored | **✅** in `win32json-api.files` → `win32-ui-controls.vapi` |
| `UI.WindowsAndMessaging.json` | **✅** → `create_window_ex`, message loop, `WM_COMMAND`, `BN_CLICKED` (declaration-only const) |
| Enum emit (`WindowStyle`, …) | **✅** Phase 2 |
| Control class strings (`WC_BUTTON`, `WC_EDIT`, …) | **⏳** in metadata as string constants — **not emitted yet** (emitter skips string `#define`s) |
| `BN_*` as enums | **⏳** metadata has them as constants; may want a small **notification enum** for readable `WM_COMMAND` handling |
| `LOWORD` / `HIWORD` helpers | **❌** not in vapi — demo may use shifts inline or we add tiny helpers |

So Phase 3 is **not** “vendor more JSON first.” It is mostly **make a demo, list gaps, extend the generator**, repeat.

---

## Step 0 — Button spike (Track A entry point)

**Deliverable:** `examples/button-demo.vala` + builds with `meson compile -C build` (same as hello).

**Behaviour:**

1. Top-level window (copy pattern from `hello-window.vala`).
2. Child button: `create_window_ex` with class **`"Button"`** (wide string literal until `WC_BUTTON` is emitted).
3. In `WndProc`, on **`WM_COMMAND`**: if notification is **`BN_CLICKED`**, print or update title (prove click works).
4. Close window → clean exit (`WM_DESTROY`).

**Packages (expected):**

- `win32-ui-windowsandmessaging` — window, messages, `BN_CLICKED`, `WM_COMMAND`
- `win32-system-stub` — `get_module_handle`
- `win32-ui-controls` — only if we need symbols that live only in Controls JSON

**WM_COMMAND unpacking (raw C style in Vala):**

- `LOWORD (w_param)` → notification code (compare to `BN_CLICKED`)
- `HIWORD (w_param)` → control ID
- `l_param` → child `HWND`

Document in the example or a one-line comment; add generator helpers later if we want.

---

## Step 1 — Gap list from Button spike

**Step 0 done:** `build/button-demo.exe` links. Click handler uses `WM_COMMAND` + `BN_CLICKED`; window title becomes `"Clicked!"`.

| Gap | Status |
|-----|--------|
| `WC_BUTTON` string constant | **⏳** — demo uses UTF-16 `"Button"` literal; emitter skips string consts |
| `LOWORD` / `HIWORD` | **⏳** — demo uses inline `wm_command_*` helpers |
| `BN_CLICKED` / `BS_*` | **✅** works — declaration-only const from `windows.h` |
| WndProc assign warning | **✅** same as hello — not a functional blocker |
| Ergonomic `signal clicked` | Track B — later |

Fix generator gaps in Step 1 before Edit spike.

---

## Step 2 — Edit spike

**Deliverable:** extend demo or `examples/edit-demo.vala`.

- Child **`"Edit"`** control
- **`set_window_text` / `get_window_text`** (or `SendMessage` with `WM_SETTEXT` / `WM_GETTEXT` if that is what metadata exposes cleanly)
- Optional: read text on button click

Same loop: run → gap list → generator fix.

---

## Step 3 — Widen controls (priority order)

Only after Button + Edit demos work:

| Control | Priority | Why |
|---------|----------|-----|
| **Static** | P1 | labels next to inputs |
| **ListBox** | P1 | selection model |
| **ComboBox** | P1 | common in dialogs |
| **ScrollBar** | P2 | less common in minimal apps |
| **ProgressBar** | P2 | nice for later polish |

Each control: **one small example addition** → evaluate gaps → generator/metadata fix. Do not bulk-implement all six upfront.

---

## Track B — ergonomic layer (optional in Phase 3)

From Phase 2 plan / overview PDF:

- Generator emits **`[Compact] public class Button`** wrapping `HWND` + `create_window_ex` / `SendMessage`
- Vala **`signal clicked`** — wired from app `WndProc` forwarding `WM_COMMAND`, or plumbing C if delegate lifetime is unsafe

**Start Track B only when Track A Button demo is stable.** Otherwise we duplicate hello-window’s Phase 2 mistake (ergonomic layer before raw bindings work).

---

## Metadata / vendor scope

**Default:** keep current `win32json-api.files` — **`UI.Controls.json` is already included.**

Widen the list only when a gap trace shows a symbol lives in a **different** JSON blob (e.g. something only in `UI.Controls.Dialogs.json`). Do not add blobs speculatively.

**Filter:** keep Unicode-first policy (`NameMapper.skip_ansi_name`, `gui.filter` excludes).

---

## Intended files

| File | Action |
|------|--------|
| `examples/button-demo.vala` | create — Track A first demo |
| `examples/edit-demo.vala` | create — optional split from button demo |
| `meson.build` | extend — build demos (same pattern as `hello-window.exe`) |
| `src/Generate/VapiEmitter.vala` | extend — string constants, control enums, any new gaps |
| `src/Generate/NameMapper.vala` | extend — control class names if needed |
| `metadata/win32json-api.files` | extend — **only when** gap analysis requires new JSON |
| `docs/plans/05 - phase 3 common controls.md` | this plan |

**Not:** regenerate a monolith `win32-ui.vapi` — apps use **`win32-ui-controls`**, **`win32-ui-windowsandmessaging`**, etc.

---

## Verification

Same as Phase 2 — one build dir (builds **hello** and **button-demo**):

```bash
meson setup build
meson compile -C build
wine build/button-demo.exe
```

**Phase 3 Track A done when:**

- Button demo opens, click fires handler, window closes cleanly
- Edit demo (or combined demo) gets/sets text
- Gaps found in Step 1 are either **fixed in generator** or **documented** with a conscious workaround

**Phase 3 Track B done when (optional):**

- App code can use a generated `Button` (or similar) with `clicked` instead of manual `WM_COMMAND` parsing

---

## Tasks

### Track A — raw controls (required)

- [x] **🔷** **✅** `button-demo.vala` — child Button + `WM_COMMAND` / `BN_CLICKED`
- [ ] **🔷** **⏳** Gap pass after Button — document + fix emitter (string `WC_*`, styles, …)
- [ ] **🔷** **⏳** Edit demo — text get/set
- [ ] **🔷** **⏳** Gap pass after Edit
- [ ] **🔷** **⏳** Static, ListBox, ComboBox (P1) — one at a time
- [ ] **🔷** **⏳** ScrollBar, ProgressBar (P2) — if needed

### Track B — ergonomic (optional)

- [ ] **🔷** **⏳** Generator `[Compact]` `Button` + `signal clicked`
- [ ] **🔷** **⏳** `win32-plumbing.c` only if WndProc/signal wiring needs it
- [ ] **🔷** **⏳** Second demo using ergonomic API (not raw `WM_COMMAND`)

---

## Hand-off to Phase 4

**ℹ️** [06 - phase 4 dialogs and resources.md](06%20-%20phase%204%20dialogs%20and%20resources.md) — MessageBox, common dialogs, menus, `.rc` — builds on controls that already work in a child window.
