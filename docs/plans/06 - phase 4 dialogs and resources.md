# 06 — Phase 4: Dialogs and resources

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md)

---

## Purpose

- **🔷** **MessageBox**, file/color/font dialogs via generated vapi.
- **🔷** Menus, icons, cursors — optional **`.rc`** story.
- **🔷** Win32 error → Vala **`Error`** mapping in **generator** (when designed).

---

## Intended files

- `metadata/win32json-api.files` — extend — dialog-related JSON blobs
- `tools/generate-binding.vala` — extend — dialog types + error mapping
- `vapi/win32-ui.vapi` — regenerate
- `examples/dialog-demo.vala` — **💩** create — MessageBox / file dialog smoke test

---

## Tasks

- [ ] **🔷** **⏳** Common dialogs in vapi
- [ ] **💩** **⏳** Menu + icon/cursor resources
- [ ] **🔷** **⏳** Error mapping in generator
