# 07 — Phase 5: Widget generator emit

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **After:** [06 - phase 4 dialogs and resources.md](06%20-%20phase%204%20dialogs%20and%20resources.md) · **Prerequisite:** [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) Track B (**✅** template + `WidgetEmitter` regen)

---

## Purpose

Replace the **hand-maintained** `src/Generate/templates/win32-widgets.vala` body with **generator output** driven by a **convention table** (control → `WC_*`, signal → `(WM_*, notify)`, styles, dispatch kind).

**Not in this phase:** new Win32 vapi surface (Phase 4), ergonomic wrappers for dialogs/menus, Valadoc/CI (Phase 6).

| In scope **✅** | Out of scope **💩** |
|----------------|---------------------|
| **G1** — convention table in `src/Generate/` | Ergonomic **`Win32.MessageBox`** / menu widgets |
| **G2** — emit `generated/win32-widgets.vala` from table + shared dispatch shell | Phase 4 dialog vapi |
| **`/** … */`** on emitted public **`Win32.*`** types (feeds Phase 6 Valadoc) | Full win32json-driven widget metadata |
| Regen + **`check-regen`** or diff for `generated/win32-widgets.vala` | Monolith vapi |
| **G3** (optional) — `win32-wide-strings.vala` regen; use vapi `ES_*` / `PBM_*` not numeric literals | **B5** `Window.destroyed` (optional **G4** or Phase 6) |

**Source of truth today:** Phase 3 [control → signal map](05%20-%20phase%203%20common%20controls.md#control--signal-map-first-emit-set); B3 only copies the template.

---

## Phased steps

| Step | Deliverable |
|------|-------------|
| **5a — G1 convention table** | Vala data in `WidgetEmitter` or `WidgetCodegen.vala`: `Button`, `Edit`, `ListBox`, `ComboBox`, `ScrollBar`, `Label`, `ProgressBar`, dispatch kind |
| **5b — G2 emit classes** | Generated widget ctors/signals/properties; shared `widget_window_proc` + registries stay one template fragment or emitted once |
| **5c — G3 optional** | `win32-wide-strings.vala` regen; drop `0x0080` / `PBM_*` literals where vapi has symbols |
| **5d — optional G4 / B5** | `Window.destroyed`, app-owned WndProc — only if still wanted |

**Phase 5 done when:** `meson compile -C build regen` produces `generated/win32-widgets.vala` from the table; **`ergonomic-button-demo`** behaviour unchanged (Wine); template file shrinks to dispatch-only or is deleted.

---

## Intended files

- `src/Generate/WidgetEmitter.vala` — extend (or `WidgetCodegen.vala`)
- `src/Generate/templates/` — dispatch shell only, or inline in emitter
- `generated/win32-widgets.vala` — **fully emitted** body (header + table-driven classes)
- `tools/generate-binding.vala` — wire emit
- `meson.build` — generator sources
- `scripts/check-regen.sh` — **⏳** optional diff for `generated/win32-widgets.vala`

**Not in Phase 5:** `VapiEmitter` dialog work (Phase 4), `.github/workflows` (Phase 6).

---

## Tasks

- [ ] **🔷** **5a** — Convention table from Phase 3 map (incl. scroll HWND registry, unboxed `WmCommandEntry` lesson)
- [ ] **🔷** **5b** — Emit widget classes; remove duplicate hand class bodies from template
- [ ] **🔷** **5b** — `/** … */`** on public types, signals, `WidgetDispatch`
- [ ] **💩** **5c** — `win32-wide-strings` generator emit + literal cleanup
- [ ] **💩** **5d** — B5 `Window.destroyed` / plumbing C spike (only if needed)

---

## Hand-off

- **After Phase 5:** [08 - phase 6 polish and ci.md](08%20-%20phase%206%20polish%20and%20ci.md) — Valadoc (uses emitted `/** … */`), CI, README, examples index.
