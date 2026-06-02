# 07 — Phase 5: Polish and CI

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md) · **Depends on:** Phases 1–4 materially complete

---

## Purpose

- **🔷** User-facing **documentation** and **2–3 examples** covering message loop, controls, dialogs.
- **🔷** **CI** on Linux: `vendor-win32json.sh` + `meson compile -C build check-regen` + `compile-check` + cross `hello-window`.
- **🔷** Policy in README: never hand-edit `vapi/`; how to bump `win32json-ref.txt`.

---

## Intended files

- `.github/workflows/ci.yml` — create — `meson compile` `check-regen`, `compile-check`, cross `hello-window`
- `README.md` — extend — full build matrix, regen maintainer flow, examples index
- `docs/` (optional) — create — API notes or link to generated vapi sections
- `examples/*.vala` — maintain — at least hello + control + dialog demos
- `Makefile` — extend — `make vendor`, CI-friendly targets

---

## Tasks

- [ ] **🔷** **⏳** GitHub Actions (or documented equivalent CI)
- [ ] **🔷** **⏳** README polish and example walkthroughs
- [ ] **💩** **⏳** Valadoc or generated API index (only if low cost)

---

## Project success check (from overview)

- [ ] **🔷** **⏳** Regenerate vapi with one command; CI enforces no drift
- [ ] **🔷** **⏳** Five+ controls with signals (Phase 3)
- [ ] **🔷** **⏳** Documented `valac --pkg win32-ui` without `-lwin32` monolith
