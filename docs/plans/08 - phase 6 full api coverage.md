# 08 — Phase 6: Full API coverage and testing

**Status:** **🔷** In progress — **6a ✅** · **6b ✅** · **6c ✅** · **6d ⏭ skipped** · **6e ✅** · **6f ⏳**

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **After:** [07-DONE - phase 5 widget emit.md](07-DONE%20-%20phase%205%20widget%20emit.md) (**✅**) · **Before:** [09 - phase 7 polish and ci.md](09%20-%20phase%207%20polish%20and%20ci.md) (Valadoc/CI — only after we know what API is worth documenting)

---

## Purpose

Phase 5 proved **WidgetCodegen** (catalog + profiles + emit). Phase 6 answers the product question: **how much of the vendored win32json GUI surface can we actually use from Vala** — vapi shards, generated widgets, Track A demos, and compile/runtime gaps.

This is **exploration and testing**, not polish. Do not treat “7 profiled widgets” or “20 catalog shells” as the ceiling.

| In scope **✅** | Out of scope **💩** |
|----------------|---------------------|
| **Coverage matrix** — shard × symbol × compile × (optional) Wine run | GitHub Actions / Valadoc (Phase 7) |
| **Filter expansion** — widen `gui.filter` / `win32json-api.files` with measured tradeoffs | Monolith vapi |
| **Profile growth** — more `widget-conventions.json` entries where Track B pays off | Gtk hybrid |
| **Track B integration demo** — `ergonomic-widgets-demo` for commctrl + shells | Track A per-family spikes (skipped; see 6e) |
| **Relay gaps** — document or emit missing `commctrl` / `WM_*` / init (e.g. `InitCommonControlsEx`) | Full win32json (42k-line) bind |

---

## Starting point (Phase 5 exit)

| Layer | Today | Phase 6 stretches |
|-------|--------|-------------------|
| **Vapi shards** | Filtered `vapi/win32-*.vapi` from `generate-binding` | More JSON files + symbols; compile-check per shard |
| **Control strings** | All filtered `WC_*` in `generated/win32-ui-control-strings.vala` | Same pipeline; grows with filter |
| **Widgets** | **22** catalog classes; **10** Track B profiles | ListView / TreeView / TabControl + WM_NOTIFY (6c) |
| **Demos** | hello, button, dialog, menu, ergonomic twins | One demo per major control family where feasible |

---

## Phased steps

| Step | Deliverable |
|------|-------------|
| **✅** **6a — Inventory** | **Ergonomic example matrix** — each `ergonomic-*-demo` + widget mapping → **[6a-coverage-matrix.md](../coverage/6a-coverage-matrix.md)** (`meson compile -C build coverage-report`) |
| **✅** **6b — Filter / shard trials** | Catalog scope trial + `compile-check`; filter/api-list unchanged → **[6b-filter-trials.md](../coverage/6b-filter-trials.md)** (trial 2 deferred) |
| **✅** **6c — Widget profiles** | `ListView`, `TreeView`, `TabControl` profiles + `WM_NOTIFY` dispatch + `InitCommonControlsEx` in template |
| **⏭ 6d — Track A reference apps** | **Skipped** — `ergonomic-widgets-demo` covers commctrl; raw vapi remains for debug only |
| **✅ 6e — Gap report** | **[6e-gap-report.md](../coverage/6e-gap-report.md)** — blockers vs next profile work |

**Phase 6 done when:** We have a **maintained coverage picture** and **compile-checked** examples for substantially more than the Phase 3/5 demo set; clear list of **hard blockers** vs **next profile work**.

---

## Intended files

- `metadata/filters/gui.filter` — unchanged in 6b; widen later if needed
- `metadata/win32json-api.files` — optional shards deferred (6b trial 2)
- `metadata/widget-conventions.json` — new profiles from 6c
- `examples/ergonomic-widgets-demo.vala` — Track B commctrl showcase (replaces 6d intent)
- **✅** `docs/coverage/6e-gap-report.md` — published gap analysis (6e)
- **✅** `src/Generate/CoverageReport.vala` + `meson compile -C build coverage-report` — 6a matrix
- **✅** `docs/coverage/6a-coverage-matrix.md` — maintained coverage picture (6a)
- **✅** `docs/coverage/6b-filter-trials.md` — shard / catalog trial log (6b)
- `docs/plans/08 - phase 6 full api coverage.md` — matrix + gap notes (this doc)
- **✅** `scripts/check-regen.sh` · **✅** `scripts/compile-check.sh` / `meson compile -C build compile-check`

---

## Tasks

- [x] **✅** **6a** — Build coverage matrix (vapi / widget / demo / runtime) — [docs/coverage/6a-coverage-matrix.md](../coverage/6a-coverage-matrix.md)
- [x] **✅** **6b** — Trial filter expansion; record shard size and compile time — [docs/coverage/6b-filter-trials.md](../coverage/6b-filter-trials.md)
- [x] **✅** **6c** — Profile + emit next N high-value `WC_*` (not hand class bodies) — `WM_NOTIFY` route; see `metadata/widget-conventions.json`
- [x] **⏭** **6d** — Track A demo per major missing family — **skipped** (see [6e-gap-report.md](../coverage/6e-gap-report.md#6d-track-a-reference-apps--skipped))
- [x] **✅** **6e** — Publish gap report — [docs/coverage/6e-gap-report.md](../coverage/6e-gap-report.md)
- [ ] **⏳** **6f** — Wine smoke for new demos (best-effort)

### Success metrics (guidance)

- **Vapi:** document % of targeted win32json GUI symbols that compile through shards (not “all of Windows”)
- **Widgets:** catalog count tracks filter; profiled count grows with demos that need signals
- **Honesty:** Phase 7 Valadoc only documents APIs we stand behind from Phase 6 evidence

---

## Hand-off

- **After Phase 6:** [09 - phase 7 polish and ci.md](09%20-%20phase%207%20polish%20and%20ci.md) — Valadoc, CI, README, examples index (polish **after** API truth is known).
