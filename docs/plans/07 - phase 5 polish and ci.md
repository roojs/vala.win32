# 07 — Phase 5: Polish and CI

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **Depends on:** Phases 1–4 materially complete · **Win32.*** widget layer ([05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) Track B) for widget Valadoc

---

## Purpose

- **🔷** User-facing **documentation** and **2–3 examples** covering message loop, controls, dialogs.
- **🔷** **Valadoc** — generated, browsable API docs for the binding (especially **`Win32.*`** compact widgets; curated vapi shards as needed).
- **🔷** **CI** on Linux: `vendor-win32json.sh` + `meson compile -C build check-regen` + `compile-check` + cross `hello-window`.
- **🔷** Policy in README: never hand-edit `vapi/`; how to bump `win32json-ref.txt`.

**ℹ️** Valadoc work lives **here**, not in Phase 3 — Track B only needs **`/** … */`** on emitted symbols where easy; **building and publishing** docs is Phase 5.

---

## Valadoc (generated API documentation)

**🔷** Once **`generated/win32-widgets.vala`** (`Win32.Window`, `Win32.Button`, …) and core vapi shards are stable, ship **`valadoc`** output so app authors do not read raw vapi or the plan to learn the widget API.

### Scope (prioritized)

| Priority | Source | Valadoc entry points |
|----------|--------|----------------------|
| **P0** | `generated/win32-widgets.vala` | `Win32.Button`, `Win32.Edit`, `Win32.Window`, `Win32.WidgetDispatch`, … |
| **P1** | `generated/win32-ui-control-strings.vala` | `Win32.Ui.Controls.WC_*` (if included — large; may omit or index only) |
| **P1** | `vapi/win32-ui-windowsandmessaging.vapi` | Message loop, `WndProc`, `WM_*` — “raw relay” reference |
| **P2** | Other `vapi/win32-*.vapi` shards | Opt-in per shard; **not** the Phase 1 monolith (`win32-ui.generated.vapi`) |

**🚫** Do not Valadoc the full ~42k-line monolith by default — too slow, low signal. Per-shard or widget-only packages match the app **`--pkg`** model.

### Doc comments (upstream of Valadoc)

- **Phase 3 Track B (generator emit):** add **`/** … */`** on public compact types, signals, and **`WidgetDispatch`** when **`win32-widgets.vala`** is generated — keeps Phase 5 from hand-maintaining prose.
- **Raw vapi:** win32json rarely carries user-facing blurbs; Phase 5 may add **minimal** hand **`/** … */`** only on high-traffic relay symbols (hello + button-demo surface) or defer raw vapi docs to Microsoft + shard name.

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

**Phase 5 Valadoc done when:**

- **⏳** `meson compile -C build valadoc` succeeds on Linux
- **⏳** **`Win32.Button`** (and at least one signal) has generated HTML from **`/** … */`** in **`win32-widgets.vala`**
- **⏳** README points maintainers and app authors at the doc output path

---

## Intended files

- `.github/workflows/ci.yml` — create — `meson compile` `check-regen`, `compile-check`, cross `hello-window`; optional **`valadoc`** target
- `README.md` — extend — full build matrix, regen maintainer flow, examples index, **Valadoc** link
- `docs/` — optional — narrative guides; **API HTML from valadoc stays under `build/docs/`** unless we choose to publish
- `meson.build` — extend — **`valadoc`** target; doc-bundle `--pkg` list
- `examples/*.vala` — maintain — at least hello + control + dialog demos
- `Makefile` — extend — `make vendor`, CI-friendly targets; optional **`make docs`**
- `src/Generate/*` — extend (Phase 3 B3+, consumed here) — emit **`/** … */`** on **`Win32.*`** public API

---

## Tasks

### CI and README

- [ ] **🔷** **⏳** GitHub Actions (or documented equivalent CI)
- [ ] **🔷** **⏳** README polish and example walkthroughs
- [ ] **🔷** **⏳** Regenerate vapi with one command; CI enforces no drift

### Valadoc

- [ ] **🔷** **⏳** Define doc-bundle **`--pkg`** set (widgets + windowsandmessaging + system-stub minimum)
- [ ] **🔷** **⏳** `meson.build` **`valadoc`** target → `build/docs/valadoc/`
- [ ] **🔷** **⏳** Generator **`/** … */`** on **`Win32.*`** public types (coordinate with Phase 3 Track B B3 — emit comments in generator, build docs here)
- [ ] **⏳** P1 raw vapi: minimal comments or shard index page in README
- [ ] **⏳** CI: `valadoc` target runs clean (optional artifact upload)

### Success checks (from overview)

- [ ] **🔷** **⏳** Five+ controls with signals (Phase 3)
- [ ] **🔷** **⏳** Documented `valac --pkg` story without `-lwin32` monolith
