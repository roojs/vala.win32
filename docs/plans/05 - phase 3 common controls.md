# 05 — Phase 3: Common controls

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md) · **Depends on:** [03 - phase 1 …](03%20-%20phase%201%20metadata%20and%20generator.md)

---

## Purpose

- **🔷** **Button, Edit, Static, ListBox, ComboBox, ScrollBar, ProgressBar** in generated vapi + ergonomic classes from generator.
- **🔷** **`BN_CLICKED` / `WM_COMMAND`** → `clicked` via vapi declarations — handlers in app Vala.
- **🔷** Widen **`win32json-api.files`** if needed; extend **`generate-binding.vala`** — no per-control `.c`.

---

## Intended files

- `metadata/win32json-api.files` — extend — ensure control-related JSON blobs vendored
- `tools/generate-binding.vala` — extend — raw + ergonomic emit for each control
- `vapi/win32-ui.vapi` — regenerate — larger API surface
- `examples/button-demo.vala` — create — Button + Edit smoke test

---

## Control priority

- Button — P0 — `BN_CLICKED` → `clicked`
- Edit — P0 — text get/set
- Static — P1 — labels
- ListBox — P1 — selection
- ComboBox — P1
- ScrollBar — P2
- ProgressBar — P2

---

## Tasks

- [ ] **🔷** **⏳** Button + Edit example
- [ ] **🔷** **⏳** P1/P2 controls
- [ ] **🔷** **⏳** Five controls usable with signals from app code
