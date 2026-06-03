# 06 — Phase 4: Dialogs and resources

**Status:** **✅** Phase 4 complete (4a–4d)

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01-DONE - project overview.md](01-DONE%20-%20project%20overview.md) · **After:** [05-DONE - phase 3 common controls.md](05-DONE%20-%20phase%203%20common%20controls.md) (**✅** closed)

---

## Scope discipline

Phase 4 is **binding + demos** for dialogs, menus, resources, and generator error mapping — **not** ergonomic **`Win32.*`** widget wrappers for those APIs (stay vapi + Track A-style demos, same as Phase 3 Track A).

**Tight** means **ordered slices (4a–4d)** — not skipping dialogs, menus, `.rc`, or error mapping.

**Widget class emission** is **[Phase 5](07%20-%20phase%205%20widget%20emit.md)** — not Phase 4.

---

## Progress at a glance

| Step | Status | Notes |
|------|--------|-------|
| **4a** MessageBox | **✅** | `dialog-demo.vala`; `MESSAGEBOXRESULT` return type |
| **4b** Common dialogs | **✅** | `common-dialog-demo.vala` — open file + color; font deferred (LOGFONT face field) |
| **4c** Menus & `.rc` | **✅** | `menu-demo.vala`; [docs/win32-rc.md](../win32-rc.md) + `examples/resources/minimal.rc` |
| **4d** Error mapping | **✅** | `generated/win32-errors.vala`; `error-demo.vala` (POSIX `out uint`, not `throws`) |

---

## 4a — MessageBox **✅**

### Changes

- **Generator:** **Yes** — `VapiEmitter`: ApiRef → qualified types (`MESSAGEBOXRESULT`, `MESSAGEBOXSTYLE` params), Foundation stub mapping, In+Out → `ref` struct params.
- **Generated vapi:** **Yes** — regen; `message_box` returns `MESSAGEBOXRESULT`.
- **Generated vala:** **No** (beyond existing companions).
- **Hand vapi / stubs:** **Yes** — `win32-foundation-stub.vapi` (`Point`, `Rect`, `Size`).
- **Header relay:** **No new**.
- **Metadata / vendor:** **No**.

**Files changed:** `src/Generate/VapiEmitter.vala`, `vapi/win32-foundation-stub.vapi`, `examples/dialog-demo.vala`, `meson.build`, `README.md`

**App workarounds:** none

**Binding surface:** `message_box`, `MESSAGEBOXSTYLE`, `MESSAGEBOXRESULT`

---

## 4b — Common dialogs **✅**

### Changes

- **Generator:** **Yes** (same pass as 4a) — `OPENFILENAME`, `CHOOSECOLOR`, dialog `FLAGS` enums on structs; `get_open_file_name (ref OPENFILENAME)`.
- **Generated vapi:** **Yes** — `win32-ui-controls-dialogs.vapi` regen.
- **Hand vapi:** **No**.
- **Metadata / vendor:** **No** (`UI.Controls.Dialogs.json` already listed).

**Files changed:** `examples/common-dialog-demo.vala`, `meson.build` (`-lcomdlg32`, `--pkg win32-ui-controls-dialogs`)

**App workarounds:** **Choose font** not in demo — `LOGFONT.lfFaceName` emitted as `void*` (cannot assign wide string into C array field). Open + color dialogs use generated structs/enums.

**Binding surface:** `OPENFILENAME`, `get_open_file_name`, `CHOOSECOLOR`, `choose_color`, `OPENFILENAMEFLAGS`, `CHOOSECOLORFLAGS`

---

## 4c — Menus & resources **✅**

### Changes

- **Generator:** **No** (menus already in `UI.WindowsAndMessaging.json`).
- **Generated vapi:** **Yes** (regen collateral) — `append_menu` uses `MENUITEMFLAGS`.
- **Hand vapi:** **No**.
- **`.rc` story:** **Yes** — [docs/win32-rc.md](../win32-rc.md), `examples/resources/minimal.rc` (windres spike documented, not wired in default `meson.build`).

**Files changed:** `examples/menu-demo.vala`, `docs/win32-rc.md`, `examples/resources/minimal.rc`, `meson.build`, `README.md`

**App workarounds:** `IDC_ARROW = 32512` literal (`IDC_ARROW` const not emitted as Vala `const`).

**Binding surface:** `create_menu`, `append_menu`, `set_menu`, `load_cursor`, `MENUITEMFLAGS`

---

## 4d — Error mapping **✅**

### Changes

- **Generator:** **Yes** — `ErrorEmitter.vala`; `generate-binding` writes `generated/win32-errors.vala`.
- **Generated vala:** **Yes** — `win32_bool_ok` / `win32_pointer_ok` (POSIX-safe; no `throws`).
- **Hand vapi:** **Yes** — `get_last_error` in `win32-system-stub.vapi`.
- **Metadata / vendor:** **No**.

**Files changed:** `src/Generate/ErrorEmitter.vala`, `tools/generate-binding.vala`, `generated/win32-errors.vala`, `examples/error-demo.vala`, `meson.build`

**App workarounds:** `error-demo` avoids `CreateWindowExW` (Wine can raise SEH/crash dialog on bogus class even when HWND is NULL); uses `cbSize = 0` + `UnregisterClassW` instead.

**Binding surface:** `Win32.win32_bool_ok`, `Win32.win32_pointer_ok`, `Win32.System.get_last_error`

---

## Tasks

- [x] **4a** — Gap trace MessageBox; regen vapi; `dialog-demo.vala` + Wine smoke
- [x] **4b** — File / color common dialogs in vapi + demo (font deferred — see 4b Changes)
- [x] **4c** — Menu + icon/cursor; **`.rc`** story (spike or doc + minimal compile)
- [x] **4d** — Generator Win32-error → Vala helpers (`win32-errors.vala`)

---

## Hand-off

- **Next:** [07-DONE - phase 5 widget emit.md](07-DONE%20-%20phase%205%20widget%20emit.md) — **✅** done.
- **Then:** [08 - phase 6 full api coverage.md](08%20-%20phase%206%20full%20api%20coverage.md) → [09 - phase 7 polish and ci.md](09%20-%20phase%207%20polish%20and%20ci.md).
