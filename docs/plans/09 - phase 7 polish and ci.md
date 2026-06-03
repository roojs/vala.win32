# 09 — Phase 7: Polish and CI

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **Depends on:** [08 - phase 6 full api coverage.md](08%20-%20phase%206%20full%20api%20coverage.md) (know what API we actually ship) · **Win32.*** widget layer ([07-DONE - phase 5 widget emit.md](07-DONE%20-%20phase%205%20widget%20emit.md) **✅**)

**ℹ️** Polish and Valadoc are **deferred to Phase 7** on purpose: Phase 6 establishes how much of the full GUI API is real before we document and CI-freeze it.

---

## Purpose

- **🔷** User-facing **documentation** and **2–3 examples** covering message loop, controls, dialogs.
- **🔷** **Valadoc** — generated, browsable API docs for the binding (especially **`Win32.*`** compact widgets; curated vapi shards as needed).
- **🔷** **CI** on Linux: `vendor-win32json.sh` + `meson compile -C build check-regen` + `compile-check` + cross `hello-window`.
- **🔷** Policy in README: never hand-edit `vapi/`; how to bump `win32json-ref.txt`.

**ℹ️** Valadoc work lives **here**, not in Phase 3/5 — Phase 5 emits **`/** … */`** on widgets; **building and publishing** HTML is Phase 7.

---

## Valadoc (generated API documentation)

**🔷** Once **`generated/win32-widgets.vala`** is **table-emitted** (Phase 5) and core vapi shards are stable, ship **`valadoc`** output so app authors do not read raw vapi or the plan to learn the widget API.

### Scope (prioritized)

| Priority | Source | Valadoc entry points |
|----------|--------|----------------------|
| **P0** | `generated/win32-widgets.vala` | `Win32.Button`, `Win32.Edit`, `Win32.Window`, `Win32.WidgetDispatch`, … |
| **P1** | `generated/win32-ui-control-strings.vala` | `Win32.Ui.Controls.WC_*` (if included — large; may omit or index only) |
| **P1** | `vapi/win32-ui-windowsandmessaging.vapi` | Message loop, `WndProc`, `WM_*` — “raw relay” reference |
| **P2** | Other `vapi/win32-*.vapi` shards | Opt-in per shard; **not** the Phase 1 monolith (`win32-ui.generated.vapi`) |

**🚫** Do not Valadoc the full ~42k-line monolith by default — too slow, low signal. Per-shard or widget-only packages match the app **`--pkg`** model.

### Doc comments (upstream of Valadoc)

- **Phase 5:** **`/** … */`** on emitted public compact types, signals, and **`WidgetDispatch`** — Phase 7 only builds HTML.
- **Raw vapi:** win32json rarely carries user-facing blurbs; Phase 7 may add **minimal** hand **`/** … */`** only on high-traffic relay symbols (hello + button-demo surface) or defer raw vapi docs to Microsoft + shard name.

### Build and layout (intended)

- **`meson.build`** — `custom_target` or `run_target` **`valadoc`** invoking **`valadoc`** with:
  - **`--pkg`** list matching a documented “doc bundle” (widgets + `win32-ui-windowsandmessaging` + stubs)
  - **`--vapidir`** `vapi/` + compiled/generated `.vala` paths for `Win32.*` widgets
  - **`--directory`** → `build/docs/valadoc/` (or `docs/api/` if we commit HTML — **⏳** decide; default gitignore `build/docs/`)
- **`README.md`** — link to generated Valadoc index (`index.htm` / `index.html` depending on valadoc version)
- **CI (optional P1):** `meson compile -C build valadoc` — fail on doc parse errors, not necessarily publish artifacts

### Verification

```bash
meson compile -C build valadoc
# open build/docs/valadoc/index.htm — Win32.Button, signals, WidgetDispatch visible
```

**Phase 7 Valadoc done when:**

- **⏳** `meson compile -C build valadoc` succeeds on Linux
- **⏳** **`Win32.Button`** (and at least one signal) has generated HTML from Phase 5 **`/** … */`**
- **⏳** README points maintainers and app authors at the doc output path

---

## Intended files

- `.github/workflows/ci.yml` — create — `meson compile` `check-regen`, `compile-check`, cross `hello-window`; optional **`valadoc`** target
- `README.md` — extend — full build matrix, regen maintainer flow, examples index, **Valadoc** link
- `docs/` — optional — narrative guides; **API HTML from valadoc stays under `build/docs/`** unless we choose to publish
- `meson.build` — extend — **`valadoc`** target; doc-bundle `--pkg` list
- `examples/*.vala` — maintain — at least hello + control + dialog demos
- `Makefile` — extend — `make vendor`, CI-friendly targets; optional **`make docs`**

---

## Tasks

### CI and README

- [ ] **🔷** **⏳** GitHub Actions (or documented equivalent CI)
- [ ] **🔷** **⏳** README polish and example walkthroughs
- [ ] **🔷** **⏳** Regenerate vapi with one command; CI enforces no drift

### Valadoc

- [ ] **🔷** **⏳** Define doc-bundle **`--pkg`** set (widgets + windowsandmessaging + system-stub minimum)
- [ ] **🔷** **⏳** `meson.build` **`valadoc`** target → `build/docs/valadoc/`
- [ ] **⏳** P1 raw vapi: minimal comments or shard index page in README
- [ ] **⏳** CI: `valadoc` target runs clean (optional artifact upload)

### Success checks (from overview)

- [ ] **🔷** **⏳** Five+ controls with signals (Phase 3)
- [ ] **🔷** **⏳** Documented `valac --pkg` story without `-lwin32` monolith
