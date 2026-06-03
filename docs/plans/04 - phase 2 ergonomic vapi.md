# 04 — Phase 2: Generated vapi + hello-window

**Status:** **✅** Track A mostly done — see progress table below

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md) · **Depends on:** [03 - phase 1 metadata and generator.md](03%20-%20phase%201%20metadata%20and%20generator.md)

---

## Progress at a glance

| Area | Status | Notes |
|------|--------|-------|
| Per-json vapi shards + pkg ids | **✅** | `win32-ui-windowsandmessaging.vapi`, … |
| P0 emitter (WndProc, Msg out/ref, uint scalars) | **✅** | hello compiles |
| `GetModuleHandleW` stub | **✅** | `vapi/win32-system-stub.vapi` |
| Unicode-only (skip `*A`) | **✅** | `NameMapper.skip_ansi_name` |
| `hello-window.vala` + `meson.build` migrated | **✅** | generated pkgs, not spike |
| Spike archived | **✅** | `vapi/archive/win32-ui-native.vapi` |
| Default build | **✅** | `meson compile -C build` → regen + `build/hello-window.exe` |
| Run under Wine | **⏳** | `wine build/hello-window.exe` |
| P1 enums (`WindowStyle`, `SysColorIndex`) | **✅** | hello uses generated names, not hex literals |
| Track B ergonomic layer | **⏳** | Phase 3+ stretch |

**Legend:** **✅** done · **⏳** open / partial · **❌** blocked

---

## Purpose (two tracks)

**Track A — hello-window (required for Phase 2 closure)**

- **🔷** Make generated vapi **usable** for `examples/hello-window.vala`: same behaviour as today, no spike `win32-ui-native.vapi`.
- **🔷** Point **`compile-check`** and cross **`hello-window`** at generated bindings (or a thin curated slice — see package split below).
- **🔷** Keep relay-only: app `.vala` → C → Win32 DLLs; no binding library.

**Track B — ergonomic layer (stretch / overlaps Phase 3)**

- **🔷** Gtk-*like* **`[Compact]`** types + **`signal`s** emitted from generator where designed.
- **🔷** **`win32-plumbing.c`** only if vapi cannot express `WndProc` / delegate lifetime safely.
- **🔷** Extra demos (`clicked` / `destroyed`) — not required for hello-window.

**🚫** No `metadata/generator/*.toml`, no `src/win32/*.vala` monolith library.

---

## Generated file today (Phase 2)

- **App shards:** `vapi/win32-ui-windowsandmessaging.vapi`, … — one file per line in `metadata/win32json-api.files`
- **Vala namespace:** `Win32.Ui.WindowsAndMessaging { … }` (not flat `Win32 { … }`, not spike `Win32Ui.Native`)
- **Hand stub:** `vapi/win32-system-stub.vapi` — `GetModuleHandleW` until loader JSON vendored
- **Monolith (Phase 1 only):** `vapi/win32-ui.generated.vapi` — `meson compile -C build regen-monolith`; not used by hello
- **Not emitted yet:** `Enum`, numeric const values, full `TypeRef` coverage

---

## What `hello-window.vala` actually needs

Spike today: `--pkg win32-ui` + `--pkg win32-ui-native`, plus **local `const`** literals in the example (Vala limitation with `[CCode]` relay).

**Types**

- `WndProc` delegate (assignable from app `window_proc`)
- `WndClassEx` — `cbSize`, `style`, `lpfnWndProc`, `hInstance`, `hbrBackground`, `lpszClassName`, …
- `Msg` — `out` / `ref` in message loop

**Functions (Unicode / `W` suffix in C)**

- `get_module_handle`
- `register_class_ex` (`ref WndClassEx`)
- `create_window_ex`
- `get_message` (`out Msg`)
- `translate_message` / `dispatch_message` (`ref Msg`)
- `def_window_proc`
- `post_quit_message`

**Constants (today in example source, not spike vapi)**

- `WM_DESTROY`, `WS_OVERLAPPEDWINDOW`, `WS_VISIBLE`, `CW_USEDEFAULT`, `COLOR_WINDOW`

**App-only (unchanged)**

- UTF-16 `CLASS_NAME` / `WINDOW_TITLE` arrays with `[CCode (array_null_terminated = true)]`

---

## Gap analysis: spike vs generated

### Package and naming

- Spike: `Win32Ui.Native` + `--pkg win32-ui-native` (archived).
- **✅ Phase 2:** per-json **`--pkg win32-ui-windowsandmessaging`**, Vala **`Win32.Ui.WindowsAndMessaging`**, metadata filter still uses internal `Windows.Win32.*` strings only inside the generator.

### Symbols present in generated vapi (close)

- **✅** `WndProc`, `WndClassEx`, `Msg`, `create_window_ex`, `register_class_ex`, `get_message`, `translate_message`, `dispatch_message`, `def_window_proc`, `post_quit_message` — names exist under `Win32`.
- **✅** `WM_DESTROY`, `CW_USEDEFAULT` — `public const` (declaration-only, no numeric value in vapi).

### Symbols missing or wrong for hello

- **`get_module_handle` — ✅ fixed (stub)**
  - Hand shard `vapi/win32-system-stub.vapi` until loader JSON is vendored.

- **`WndClassEx.lpfnWndProc` — ✅ fixed**
  - Generated: `WndProc` (was `void*`).

- **`WndClassEx.style` (and similar) — ✅ fixed**
  - Generated: `uint` (was `void*`).

- **Message loop — ✅ fixed**
  - `get_message (out Msg …)`, `translate_message (ref Msg)`, `dispatch_message (ref Msg)`.

- **Constants hello uses — ⏳ partial**
  - `WS_OVERLAPPEDWINDOW`, `WS_VISIBLE`, `COLOR_WINDOW` — still **local const** in `hello-window.vala` (P1).
  - Generated `public const` remain declaration-only (no numeric values in vapi).

- **String fields — ✅ acceptable**
  - Generated: `uint16*` (works with string literals).

- **Noise / hazard — ✅ fixed**
  - Ansi `*A` siblings skipped in emitter (`NameMapper.skip_ansi_name`).

### Vala / vapi rules (unchanged from Phase 0)

- Even with perfect emit, **public const with values** in the same package as `[CCode]` bindings is awkward in Vala; hello may still keep a few literals in `.vala` until we have a documented pattern (external const, second namespace, or C header-only values).

---

## Emitter work (prioritized for hello-window)

**P0 — must have**

- **✅** Resolve **function pointer fields** (`lpfnWndProc` → `WndProc`).
- **✅** **Struct parameters:** `MSG` / `Msg` as `out` / `ref`, not `void*`.
- **✅** **Scalar types:** `uint` for `style`, `dw_ex_style`, etc.; reduce wrong `void*`.
- **✅** **Vendor or stub** `GetModuleHandleW`.
- **✅** **Package decision** + switch `hello-window` + `meson.build` `compile-check` to generated (or generated + minimal stub).
- **✅** **Unicode-only** emit or filter so hello does not need `_a` symbols.

**P1 — should have for faithful hello**
  
- **✅** Emit **enum** types for `WS_*`, `COLOR_*` (`WindowStyle`, `SysColorIndex`, …).
- **❌** Emit **numeric values on `public const`** — Vala forbids `= 2` on relay constants; `WM_DESTROY` / `CW_USEDEFAULT` use declaration-only + `windows.h`.
- **✅** **Delegate param names** — `WndProc` → `h_wnd`, `msg`, `w_param`, `l_param`.
- **✅** `unowned` on wide-string **struct fields** (`lpszClassName`, …). Not on function params — Vala already defaults to that and warns if duplicated.

Hello now uses `WindowStyle.WS_*`, `SysColorIndex.COLOR_WINDOW`, `WM_DESTROY`, `CW_USEDEFAULT` from generated vapi — no numeric literals at the top of the file.

**P2 — later / Track B**

- **⏳** `[Compact]` ergonomic wrappers + signals in generator.
- **⏳** `win32-plumbing.c` if delegate marshalling still unsafe.
- **⏳** Broader `TypeRef` (`ApiRef`, pointers, `MemorySize` attrs).
- **✅** **Per-json vapi emit** (see package layout — replaces monolithic `win32-ui.generated.vapi` for apps).

---

## Package layout — mirror win32json files

win32json is already split into **distinct namespace JSON files** (`UI.WindowsAndMessaging.json`, `UI.Controls.json`, …). `metadata/win32json-api.files` lists which blobs we vendor. **Phase 2 should emit vapi the same way**, not flatten everything into one ~42k-line file.

**Current (Phase 1):** all vendored JSON → single `vapi/win32-ui.generated.vapi`, one flat `namespace Win32 { … }`. Fine for pipeline proof; wrong shape for apps.

**Target (Phase 2):** **one input JSON → one output `.vapi`** (plus optional umbrella pkg). **Vapi / `--pkg` names follow normal lowercase hyphenated ids**, derived from the JSON basename.

**Naming rule (vapi file + `--pkg` + `.pc`):**

- Start from JSON basename without `.json` (e.g. `UI.WindowsAndMessaging`, `Graphics.Gdi`)
- Replace each `.` with `-`
- Lowercase the whole id
- Prefix `win32-`

Examples:

- `UI.WindowsAndMessaging.json` → **`win32-ui-windowsandmessaging`** (`win32-ui-windowsandmessaging.vapi`, `--pkg win32-ui-windowsandmessaging`)
- `Graphics.Gdi.json` → **`win32-graphics-gdi`**
- `UI.Controls.json` → **`win32-ui-controls`**
- `UI.Controls.Dialogs.json` → **`win32-ui-controls-dialogs`**

Implement in **`NameMapper.json_basename_to_pkg_id()`** (or similar) — single function for vapi filename, pkg-config name, and `check-regen` paths.

Example layout:

```
vapi/
  win32-ui-windowsandmessaging.vapi   # was UI.WindowsAndMessaging.json
  win32-graphics-gdi.vapi             # was Graphics.Gdi.json
  win32-ui-controls.vapi              # Phase 3 — if in win32json-api.files
  …
  win32-ui.vapi                       # optional umbrella / placeholder
```

**Three names for the same shard (do not conflate them):**

- **1. win32json metadata (generator + filter only)** — upstream uses a long prefix: `Windows.Win32.UI.WindowsAndMessaging.CreateWindowExW`. That string exists because win32json mirrors Microsoft’s .NET / metadata layout. **Apps never see it.** We keep `ApiFile.namespace_from_basename()` and `gui.filter` lines that match `Windows.Win32.*` only so the generator can find symbols in JSON — internal plumbing, not vapi design.

- **2. Vala namespace (what app code uses)** — drop the redundant `Windows.` layer. One shard vapi exposes e.g. **`Win32.Ui.WindowsAndMessaging { … }`**, derived from the JSON basename (`UI.WindowsAndMessaging.json` → `Ui` + `WindowsAndMessaging`). Same idea as today’s spike (`Win32Ui.Native`) but split per metadata file. **No `Windows.Win32` in Vala source.**

- **3. `--pkg` / vapi filename (hyphen id)** — `win32-ui-windowsandmessaging` (see naming rule above). Unrelated to Vala dotted namespaces; this is pkg-config / `--pkg` convention only.

```
  UI.WindowsAndMessaging.json          (vendor file)
           │
           ├─► filter: Windows.Win32.UI.WindowsAndMessaging.*   (internal)
           ├─► vapi:   namespace Win32.Ui.WindowsAndMessaging  (app API)
           └─► pkg:    win32-ui-windowsandmessaging            (--pkg)
```

**What hello-window needs (minimal pkgs):**

- `win32-ui-windowsandmessaging` — core loop APIs
- `win32-graphics-gdi` — if `COLOR_WINDOW` / brush constants live there
- Add JSON for loader APIs when vendored (e.g. `System.*` → `win32-system-…`) — **same rule**, not a monolith

Apps then:

```vala
using Win32.Ui.WindowsAndMessaging;

// valac --pkg win32-ui-windowsandmessaging --pkg win32-graphics-gdi …
// create_window_ex (…);  — inside Win32.Ui.WindowsAndMessaging, not Windows.Win32.*
```

**Benefits**

- Matches upstream metadata boundaries — vendor list, filter, and vapi stay aligned
- `valac` only parses shards the app imports
- `check-regen` can diff **per file** (smaller, reviewable)
- Phase 3 widens surface by **adding lines to `win32json-api.files`**, not by growing one blob

**Emitter changes for split output**

- **✅** `VapiEmitter.emit_shard` → write `vapi/<pkg-id>.vapi` where `pkg-id` = `win32-` + basename with `.` → `-`, lowercased
- **✅** `NameMapper` — **`json_basename_to_pkg_id()`** shared by emitter, meson, `check-regen`
- **✅** `generate-binding` reads **`win32json-api.files`** — not “every `.json` in api/”
- **✅** Dedupe policy: **within a shard only**
- **⏳** Optional thin `win32-ui.vapi` umbrella — not required for hello

**Still allowed: tiny hand shard**

- One extern file only for symbols **missing from vendored JSON** until the right namespace JSON is added — not a second full API layer.

**Deprecated for apps**

- **Monolithic** `win32-ui.generated.vapi` — keep temporarily for Phase 1 `check-regen` smoke, or replace check-regen with per-shard diffs; do **not** point `hello-window` at the monolith.

**🔷** Default Phase 2 decision: **per-metadata-file vapi** (this section), not Option 1 monolith rename.

---

## Package layout options (legacy notes)

- ~~**Option 1 — Single generated pkg**~~ — conflicts with win32json file boundaries; avoid for apps.
- ~~**Option 2 — Curated hello slice**~~ — largely superseded by **hello = subset of pkgs** (`WindowsAndMessaging` + `Gdi` + …); only keep a dedicated `hello.filter` if we need fewer symbols *inside* one JSON blob.
- **Option 3 — Generated shards + tiny hand stub** — still valid for `GetModuleHandleW` until metadata includes it.

---

## Intended files

- `src/Generate/VapiEmitter.vala` — extend — `TypeRef`, attrs, const values, enum emit
- `src/Generate/NameMapper.vala` — extend — **`json_basename_to_pkg_id()`**, Unicode-only policy, param names
- `metadata/filters/gui.filter` — extend — drop Ansi duplicates if not already
- `metadata/win32json-api.files` — extend — add namespace JSON for `GetModuleHandleW` (if exists in win32json)
- `tools/generate-binding.vala` — extend — read `win32json-api.files`; emit **`vapi/win32-<shard>.vapi`** per JSON basename
- `vapi/win32-*.vapi` — regen — one file per vendored JSON (replace monolith for apps)
- `win32-*.pc` — create — one pkg-config per shard (or documented aggregate)
- `vapi/win32-ui.generated.vapi` — optional — Phase 1 monolith; retire or concat-only for CI
- `vapi/win32-ui-native.vapi` — remove or replace — after hello migrates
- `examples/hello-window.vala` — update — `using` / packages; fewer local consts as emit improves
- `meson.build` — update — `compile-check` / `hello-window` link generated vapi
- `src/win32-plumbing.c` — create (if needed) — Track B only
- `examples/` — extend — optional ergonomic demo (Track B)

---

## Verification

```bash
meson setup build
meson compile -C build
wine build/hello-window.exe
```

**Pass:** `meson compile` succeeds and `build/hello-window.exe` exists.

---

## Tasks

### Track A — hello-window

- **✅** Per-json vapi emit + `win32-…` pkg ids; hello uses `win32-ui-windowsandmessaging` + `win32-system-stub`
- **✅** P0 emitter: delegate fields, `out`/`ref` Msg, scalar types
- **✅** Metadata/vendor: `GetModuleHandleW` (hand stub until loader JSON)
- **✅** Filter: Unicode-first API surface (`NameMapper.skip_ansi_name`)
- **✅** Migrate `hello-window.vala` + `meson.build`
- **✅** Archive spike `vapi/archive/win32-ui-native.vapi`
- **✅** Default `meson compile -C build` (regen + exe)
- **⏳** Run `.exe` on Windows / Wine (manual)
- **✅** P1 enums + delegate names; hello has no Win32 numeric literals
- **⏳** P1: `unowned` wide strings (optional)

### Track B — ergonomic (stretch)

- **⏳** Measure vapi size; confirm split strategy
- **⏳** Ergonomic emit for `Window` + `Button`
- **⏳** Plumbing C only if proven necessary

---

## Hand-off to Phase 3

**ℹ️** [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) — widen `win32json-api.files`, generator emit for Button/Edit, `BN_CLICKED` → `clicked`, on top of a working hello baseline.
