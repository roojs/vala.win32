# 08 — Phase 6: Full API coverage and testing

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **After:** [07-DONE - phase 5 widget emit.md](07-DONE%20-%20phase%205%20widget%20emit.md) (**✅**) · **Before:** [09 - phase 7 polish and ci.md](09%20-%20phase%207%20polish%20and%20ci.md) (Valadoc/CI — only after we know what API is worth documenting)

---

## Purpose

Phase 5 proved **WidgetCodegen** (catalog + profiles + emit). Phase 6 answers the product question: **how much of the vendored win32json GUI surface can we actually use from Vala** — vapi shards, generated widgets, Track A demos, and compile/runtime gaps.

This is **exploration and testing**, not polish. Do not treat “7 profiled widgets” or “16 catalog shells” as the ceiling.

| In scope **✅** | Out of scope **💩** |
|----------------|---------------------|
| **Coverage matrix** — shard × symbol × compile × (optional) Wine run | GitHub Actions / Valadoc (Phase 7) |
| **Filter expansion** — widen `gui.filter` / `win32json-api.files` with measured tradeoffs | Monolith vapi |
| **Profile growth** — more `widget-conventions.json` entries where Track B pays off | Gtk hybrid |
| **Track A spikes** — raw vapi for controls not yet profiled (`ListView`, `TreeView`, …) | Hand-editing `vapi/` |
| **Relay gaps** — document or emit missing `commctrl` / `WM_*` / init (e.g. `InitCommonControlsEx`) | Full win32json (42k-line) bind |

---

## Starting point (Phase 5 exit)

| Layer | Today | Phase 6 stretches |
|-------|--------|-------------------|
| **Vapi shards** | Filtered `vapi/win32-*.vapi` from `generate-binding` | More JSON files + symbols; compile-check per shard |
| **Control strings** | All filtered `WC_*` in `generated/win32-ui-control-strings.vala` | Same pipeline; grows with filter |
| **Widgets** | **16** catalog classes; **7** Track B profiles | Profiles + dispatch for high-value controls; shell-only → exercised |
| **Demos** | hello, button, dialog, menu, ergonomic twins | One demo per major control family where feasible |

---

## Phased steps

| Step | Deliverable |
|------|-------------|
| **6a — Inventory** | Coverage spreadsheet: metadata symbol → vapi? → widget class? → demo? → Wine OK? |
| **6b — Filter / shard trials** | Incremental `gui.filter` / api-list changes; regen + `compile-check` after each bump |
| **6c — Widget profiles** | Add conventions + emit for controls beyond button-demo parity (e.g. `ListView`, `TreeView`, `TabControl`) |
| **6d — Track A reference apps** | Minimal `.vala` per family using raw vapi (baseline before Track B) |
| **6e — Gap report** | What blocks full API (missing relay, Vala types, init order, ANSI-only symbols, …) |

**Phase 6 done when:** We have a **maintained coverage picture** and **compile-checked** examples for substantially more than the Phase 3/5 demo set; clear list of **hard blockers** vs **next profile work**.

---

## Intended files

- `metadata/filters/gui.filter` — widen as trials succeed
- `metadata/win32json-api.files` — optional extra API JSON basenames
- `metadata/widget-conventions.json` — new profiles from 6c
- `examples/` — Track A + ergonomic spikes per control family
- `docs/plans/08 - phase 6 full api coverage.md` — matrix + gap notes (this doc)
- `scripts/check-regen.sh` / `meson compile -C build compile-check` — already; use heavily

---

## Tasks

- [ ] **🔷** **6a** — Build coverage matrix (vapi / widget / demo / runtime)
- [ ] **🔷** **6b** — Trial filter expansion; record shard size and compile time
- [ ] **🔷** **6c** — Profile + emit next N high-value `WC_*` (not hand class bodies)
- [ ] **🔷** **6d** — Track A demo per major missing family
- [ ] **🔷** **6e** — Publish gap report (relay, generator, Vala limits)
- [ ] **⏳** **6f** — Wine smoke for new demos (best-effort)

### Success metrics (guidance)

- **Vapi:** document % of targeted win32json GUI symbols that compile through shards (not “all of Windows”)
- **Widgets:** catalog count tracks filter; profiled count grows with demos that need signals
- **Honesty:** Phase 7 Valadoc only documents APIs we stand behind from Phase 6 evidence

---

## Hand-off

- **After Phase 6:** [09 - phase 7 polish and ci.md](09%20-%20phase%207%20polish%20and%20ci.md) — Valadoc, CI, README, examples index (polish **after** API truth is known).
