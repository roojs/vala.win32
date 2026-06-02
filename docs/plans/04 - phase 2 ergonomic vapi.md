# 04 — Phase 2: Ergonomic vapi (optional)

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md) · **Depends on:** [03 - phase 1 metadata and generator.md](03%20-%20phase%201%20metadata%20and%20generator.md)

---

## Purpose

- **🔷** Review generated **`win32-ui.generated.vapi`** — decide if package split is needed.
- **🔷** When emit quality allows, **point `hello-window.vala` / `compile-check` at generated vapi** (Phase 1 does not do this).
- **🔷** Extend **`generate-binding.vala`** to emit Gtk-*like* **`[Compact]`** declarations (still relay-only).
- **🔷** Add **`win32-plumbing.c`** only if vapi cannot express `WndProc` / delegate lifetime safely.
- **🔷** Example showing **signals** in **app generated C**, not in a binding lib.

---

## Intended files

- `tools/generate-binding.vala` — extend — ergonomic templates (Vala code, not external config)
- `src/win32-plumbing.h` — create (if needed) — C symbols for delegate thunk
- `src/win32-plumbing.c` — create (if needed) — minimal `WndProc` plumbing
- `vapi/win32-ui.vapi` — regenerate — raw + ergonomic in one file unless split decided
- `examples/` — extend — demo `clicked` / `destroyed` ergonomics
- `Makefile` — extend — link plumbing object when present

**🚫** No `metadata/generator/*.toml`, no `src/win32/*.vala` library.

---

## Tasks

- [ ] **🔷** **⏳** Measure vapi size; decide single pkg vs split
- [ ] **🔷** **⏳** Ergonomic emit for `Window` + `Button` in generator
- [ ] **🔷** **⏳** Plumbing C only if proven necessary

---

## Hand-off to Phase 3

**ℹ️** [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) — extend generator + `win32json-api.files`.
