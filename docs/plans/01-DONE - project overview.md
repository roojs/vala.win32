# 01 — Vala Win32 UI binding (overview)

**Status:** **⏳** Active — phased plans below

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Source:** [Vala Win32 Binding Analysis - DeepSeek.pdf](../../Vala%20Win32%20Binding%20Analysis%20-%20DeepSeek.pdf)

**Credits (prior art, unrelated implementation):** [emrevit/vala-win32](https://github.com/emrevit/vala-win32)

---

## Purpose

- **🔷** Thin **generated `.vapi`** so app `.vala` compiles to C that calls Win32 directly — no `libwin32` monolith.
- **🔷** **win32json → generate-binding → `vapi/`** plus optional tiny **plumbing C** only where Vala cannot relay (e.g. `WndProc` lifetime).
- **🔷** **Native Win32 HWND UI only** — not Gtk + Win32 in one process; non-GUI via GLib/GIO.
- **ℹ️** Per-phase work, file list, and tasks live in **one plan per stage** (not this document).

---

## Phase index

- [02-DONE - phase 0 foundation.md](02-DONE%20-%20phase%200%20foundation.md) — **✅** Done
  - Repo, hand spike, `make check` / `make win`
- [03 - phase 1 metadata and generator.md](03%20-%20phase%201%20metadata%20and%20generator.md) — **⏳** In progress
  - win32json vendor, `generate-binding`, `check-regen` (generated vapi separate from spike apps)
- [04 - phase 2 ergonomic vapi.md](04%20-%20phase%202%20ergonomic%20vapi.md) — **✅** Track A done (hello on generated vapi)
  - Per-shard vapi, enums, `hello-window.exe`
- [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) — **⏳** Not started
  - Button-first demos, gap-driven generator fixes; optional ergonomic `clicked`
- [06 - phase 4 dialogs and resources.md](06%20-%20phase%204%20dialogs%20and%20resources.md) — **⏳** Not started
  - MessageBox, file dialogs, menus, `.rc`
- [07 - phase 5 polish and ci.md](07%20-%20phase%205%20polish%20and%20ci.md) — **⏳** Not started
  - Docs, **Valadoc**, examples, cross-compile CI

---

## Architecture (all phases)

```
  Application .vala
        │
        ▼  valac --pkg win32-ui
  Application .c          ← signals, handlers, Win32 call sites
        │
        ├──► user32.dll / gdi32.dll / …
        └──► win32-plumbing.o (optional, tiny)
```

**🔷** Binding repo ships **vapi (+ optional plumbing C)** only — no `src/win32/*.vala`, no per-control `.c` library.

**🔷** Widget feel: **`[Compact]`** types + Vala **`signal`s** (Gtk-*like* usage, not GObject runtime). See analysis PDF.

---

## Metadata pipeline (settled design)

```
  marlersoft/win32json (upstream JSON)
        │
        ▼
  scripts/vendor-win32json.sh
        │  clone → build/vendor/win32json/
        │  copy listed blobs → metadata/win32json/api/
        ▼
  metadata/win32json-api.files     ← which api/*.json to copy (include scope)
  metadata/filters/gui.filter      ← symbol excludes only (- Ansi, Interop, Tests)
        │
        ▼
  tools/generate-binding.vala      ← CLI
  src/Generate/Parser/             ← Generate.Parse JSON models
  src/Generate/{VapiEmitter,…}     ← filter, naming, emit
        ▼
  vapi/win32-ui.generated.vapi     ← generator output; check-regen drift baseline
  vapi/win32-ui-native.vapi        ← Phase 0 spike; apps until generated vapi is ready
```

**ℹ️** Upstream: [win32json](https://github.com/marlersoft/win32json) (community JSON for [win32metadata](https://github.com/microsoft/win32metadata)). Each `api/UI.Foo.json` holds `Constants`, `Types`, `Functions`, `UnicodeAliases`.

**🚫** No hand-maintained `win32-gui.json`, no `.patch` on generated vapi, no `tools/export-metadata` fork, **no TOML config layer** (`naming.toml` / `types.toml` / etc.) — rules live in **`src/Generate/`** Vala.

---

## Repo layout (target)

```
vala.win32/
├── metadata/
│   ├── win32json-api.files      # include: which JSON blobs to vendor
│   ├── win32json-ref.txt        # pin upstream git ref
│   ├── win32json/api/           # copied subset (gitignored)
│   └── filters/gui.filter       # symbol - excludes
├── scripts/
│   ├── vendor-win32json.sh
│   └── setup-mingw-libs.sh
├── src/Generate/
│   ├── Parser/                  # Generate.Parse (win32json JSON)
│   ├── VapiEmitter.vala
│   ├── NameMapper.vala
│   └── SymbolFilter.vala
├── tools/generate-binding.vala
├── meson.build                  # Ninja backend
├── vapi/win32-ui.vapi
├── examples/
├── src/                         # optional win32-plumbing.c only
└── docs/plans/
```

---

## Goals and non-goals (summary)

**🔷** Vapi is the binding; metadata-driven regen; filtered GUI subset (hundreds of symbols, not full Win32).

**🚫** `libwin32`, per-control C trees, binding `.vala` in this repo, GObject base, Gtk+Win32 hybrid.

**ℹ️** Full goal tables and risks were in the original monolith; phase plans own actionable tasks.

---

## Success criteria (project)

- **🔷** Hello window + button with `clicked` and clean shutdown without raw `HWND` in app code for standard cases.
- **🔷** One command regens `vapi/` from vendored JSON + config; CI fails on drift.
- **🔷** At least five common controls usable with signals (Phase 3+).

---

## References

- [microsoft/win32metadata](https://github.com/microsoft/win32metadata) · [marlersoft/win32json](https://github.com/marlersoft/win32json)
- [Vala: Writing a VAPI Manually](https://valadoc.org/vala-write-vapi-manually.html) · [Compact classes](https://valadoc.org/vala-compact-classes.html)
- [emrevit/vala-win32](https://github.com/emrevit/vala-win32) — credits only
