# 02 — Phase 0: Foundation

**Status:** **✅** Complete

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md)

---

## Purpose

- **🔷** Prove **vapi relay**: app `.vala` → `valac` → C → Win32 with no binding library.
- **🔷** Minimal **message loop** window (`CreateWindowExW`, `GetMessageW`, `WM_DESTROY` → quit).
- **🔷** **Linux smoke test** (`make check`) and **MinGW exe** (`make win`).

---

## Intended files

- `LICENSE` — create — MIT
- `README.md` — create — build instructions, layout
- `Makefile` — create — `check`, `win`, `clean`
- `win32-ui.pc` — create — `pkg-config` for `--pkg win32-ui`
- `.gitignore` — create — `build/`, `mingw-libs/`, vendor paths
- `vapi/win32-ui-native.vapi` — create — **hand-written spike** (apps; kept through Phase 1)
- `vapi/win32-ui.vapi` — create — placeholder `--pkg win32-ui`
- `examples/hello-window.vala` — create — consumer app; UTF-16 literals; `WM_DESTROY`
- `scripts/setup-mingw-libs.sh` — create — optional MSYS2 GLib tree for full cross-link (documented)
- `docs/plans/` — create — planning docs
- `metadata/filters/` — create — Phase 1 symbol filter

**ℹ️** No `tools/generate-binding.vala` in this phase.

---

## Tasks

- [x] **✅** Repo structure, README, license
- [x] **✅** Hand-written spike vapi (`win32-ui-native.vapi`)
- [x] **✅** `examples/hello-window.vala` + `make check`
- [x] **✅** `make win` with `x86_64-w64-mingw32-gcc`, `-X -mwindows`, `--profile=posix`
- [x] **✅** `COLOR_WINDOW + 1` brush fix (client area under Wine)

---

## Verification

```bash
make check
make win   # optional: wine64 build/hello-window.exe
```

---

## Hand-off to Phase 1

**ℹ️** Phase 1 adds **`vapi/win32-ui.generated.vapi`** and `regen` / `check-regen`. **This spike vapi stays** what `hello-window.vala` and `compile-check` use until a later phase switches the app to generated bindings.
