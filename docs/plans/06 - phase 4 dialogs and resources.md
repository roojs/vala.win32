# 06 — Phase 4: Dialogs and resources

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **After:** [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) (**✅** closed)

---

## Scope discipline

Phase 4 is **binding + demos** for dialogs, menus, resources, and generator error mapping — **not** ergonomic **`Win32.*`** widget wrappers for those APIs (stay vapi + Track A-style demos, same as Phase 3 Track A).

**Tight** means **ordered slices (4a–4d)** — not skipping dialogs, menus, `.rc`, or error mapping.

**Widget class emission** is **[Phase 5](07%20-%20phase%205%20widget%20emit.md)** — not Phase 4.

---

## Purpose

| In scope **✅** | Out of scope **💩** |
|----------------|---------------------|
| **`MessageBoxW`** / modal APIs — vapi gap pass + demo | Ergonomic **`Win32.MessageBox`** (etc.) widget classes |
| **File / color / font** common dialogs — vapi + demo coverage as gaps allow | Full dialog UI framework; every COMDLG variant |
| **Menus**, **icons**, **cursors** — vapi + optional **`.rc`** story | GTK/Qt-style menu widget layer |
| **Win32 error → Vala `Error`** in **generator** (when designed) | Hand-mapping errors in every app |
| Extend **`metadata/win32json-api.files`** when gap trace requires | Monolith `win32-ui.vapi` regen |
| Regen **per-shard** `vapi/win32-*.vapi` | **Phase 5** widget table emit; template growth |

---

## Phased steps (implement in order)

| Step | Scope | Deliverable |
|------|--------|-------------|
| **4a — MessageBox** | Gap pass + emit | `dialog-demo.vala` — MessageBox smoke (Wine) |
| **4b — Common dialogs** | File / color / font APIs in vapi | Extend demo or `common-dialog-demo.vala` |
| **4c — Menus & resources** | Menu APIs; icons/cursors; **`.rc`** approach documented + minimal spike | Demo or doc spike; vendored JSON only if traced |
| **4d — Error mapping** | Generator maps selected Win32 errors → Vala **`Error`** | Emit + small test or demo |

Each step gets a **`### Changes`** block when **✅** (same rules as Phase 3).

**Phase 4 done when:** 4a–4d criteria met (or 4b/4c explicitly scoped down in **Changes** with reason — prefer completing the list above).

---

## Intended files

- `metadata/win32json-api.files` — extend per gap trace (dialogs, menus, …)
- `src/Generate/VapiEmitter.vala` — dialog symbols, **error mapping**
- `vapi/win32-*.vapi` — regen
- `examples/dialog-demo.vala` — **4a**
- `examples/*-demo.vala` — **4b / 4c** as needed
- `meson.build` — demo targets
- **`.rc`** tooling / docs — **4c** (if spike lands in-repo)

---

## Tasks

- [ ] **🔷** **4a** — Gap trace MessageBox; regen vapi; `dialog-demo.vala` + Wine smoke
- [ ] **🔷** **4b** — File / color / font common dialogs in vapi + demo
- [ ] **🔷** **4c** — Menu + icon/cursor; **`.rc`** story (spike or doc + minimal compile)
- [ ] **🔷** **4d** — Generator Win32-error → Vala **`Error`** mapping

---

## Hand-off

- **Next:** [07 - phase 5 widget emit.md](07%20-%20phase%205%20widget%20emit.md) — convention table + emit `Win32.*` classes.
- **Then:** [08 - phase 6 polish and ci.md](08%20-%20phase%206%20polish%20and%20ci.md) — Valadoc, CI, README.
