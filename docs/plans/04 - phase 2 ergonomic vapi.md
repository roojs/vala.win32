# 04 — Phase 2: Generated vapi + hello-window

**Status:** **⏳** Not started

**Layout:** `~/gitlive/OLLMchat/docs/guide-to-writing-plans.md`

**Parent:** [01 - project overview.md](01%20-%20project%20overview.md) · **Depends on:** [03 - phase 1 metadata and generator.md](03%20-%20phase%201%20metadata%20and%20generator.md)

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

## Generated file today (after Phase 1)

- **File (Phase 1 monolith):** `vapi/win32-ui.generated.vapi` — all shards merged; **Phase 2 moves to per-json files under `vapi/generated/`**
- **Namespace (monolith today):** `Win32 { … }` — Phase 2: **one Vala namespace per JSON basename** (spike uses `Win32Ui.Native` until migrated)
- **Rough counts:** ~6.4k `public const`, ~2.2k `extern`, ~734 `struct`, ~87 `delegate`; ~7.5k `void*` type slots.
- **Emitted kinds:** `Struct`, `FunctionPointer` (delegate), top-level `Function`, `Constant` only.
- **Not emitted:** `Enum`, `NativeTypedef`, `Union`, `Com` — enums like `WS_*` flags often live there or as `#define` constants.
- **Known emit quirks:** duplicate/overlapping structs (`WNDCLASSEXW` + `WndClassEx`); Ansi/`A` siblings beside `W`; generic delegate param names (`param0`); dedupe can truncate Vala names (e.g. `CCM_SETNOTIFYWINDO`).

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

- Spike: `Win32Ui.Native`, hand-tuned names (`h_wnd`, `lp_msg`).
- Generated: `Win32`, snake_case from metadata; message APIs use `void*` for struct pointers.
- **Work:** pick one namespace for apps (`Win32Ui.Native` re-export vs migrate hello to `Win32`) and document `--pkg` layout.

### Symbols present in generated vapi (close)

- **✅** `WndProc`, `WndClassEx`, `Msg`, `create_window_ex`, `register_class_ex`, `get_message`, `translate_message`, `dispatch_message`, `def_window_proc`, `post_quit_message` — names exist under `Win32`.
- **✅** `WM_DESTROY`, `CW_USEDEFAULT` — `public const` (declaration-only, no numeric value in vapi).

### Symbols missing or wrong for hello

- **`get_module_handle` — missing**
  - Not in current vendored JSON set (`metadata/win32json-api.files` has no `System.*` / loader namespace).
  - **Work:** add win32json file that defines `GetModuleHandleW` **or** keep one extern in a tiny hand stub until metadata includes it.

- **`WndClassEx.lpfnWndProc` — wrong type**
  - Spike: `WndProc`
  - Generated: `void*` (function-pointer fields not resolved via `TypeRef`)
  - **Work:** when field/param type is `FunctionPointer` / delegate name, emit delegate type not `void*`.

- **`WndClassEx.style` (and similar) — wrong type**
  - Spike: `uint`
  - Generated: `void*`
  - **Work:** map `UInt32` / flags enums; emit enums from metadata `Enum` where needed.

- **Message loop — wrong pointer style**
  - Spike: `get_message (out Msg …)`, `translate_message (ref Msg)`, `dispatch_message (ref Msg)`
  - Generated: `void* lp_msg` everywhere
  - **Work:** honor parameter attrs (`Out`, `In`, `Ref`) and struct types → `out` / `ref` / typed pointer; map `MSG` to generated `Msg`.

- **Constants hello uses**
  - `WS_OVERLAPPEDWINDOW`, `WS_VISIBLE`, `COLOR_WINDOW` — **not found** in current generated output (may be enum-only in JSON or filtered).
  - All generated `public const` are **declaration-only** — app cannot rely on `Win32.WM_DESTROY` as a numeric literal without C values or local consts.
  - **Work (pick one strategy):**
    - Emit `#define` values from JSON `Value` / `ValueText` where Vala allows; or
    - Document continued local consts in app for Phase 2; or
    - Split “literal” constants into a small hand vapi shard.

- **String fields**
  - Spike: `unowned uint16*` for class/menu names
  - Generated: `uint16*` (often OK with string literals)
  - **Work:** optional `unowned` for `In` UTF-16 params (nice-to-have).

- **Noise / hazard**
  - Duplicate `create_window_ex_a`, `get_message_a`, extra struct variants — pollute search and risk wrong overload.
  - **Work:** tighten `gui.filter` (drop `*A` / `*Ansi*`) or emit Unicode-only policy in `NameMapper` / filter.

### Vala / vapi rules (unchanged from Phase 0)

- Even with perfect emit, **public const with values** in the same package as `[CCode]` bindings is awkward in Vala; hello may still keep a few literals in `.vala` until we have a documented pattern (external const, second namespace, or C header-only values).

---

## Emitter work (prioritized for hello-window)

**P0 — must have**

- [ ] Resolve **function pointer fields** (`lpfnWndProc` → `WndProc`).
- [ ] **Struct parameters:** `MSG` / `Msg` as `out` / `ref`, not `void*`.
- [ ] **Scalar types:** `uint` for `style`, `dw_ex_style`, etc.; reduce wrong `void*`.
- [ ] **Vendor or stub** `GetModuleHandleW`.
- [ ] **Package decision** + switch `hello-window` + `meson.build` `compile-check` to generated (or generated + minimal stub).
- [ ] **Unicode-only** emit or filter so hello does not need `_a` symbols.

**P1 — should have for faithful hello**
  
- [ ] Emit **enum** types (or const values) for `WS_OVERLAPPEDWINDOW`, `WS_VISIBLE`, `COLOR_WINDOW` if present in metadata.
- [ ] Emit **numeric const values** from JSON where Vala permits; document exceptions.
- [ ] Parameter **names** from metadata (`h_wnd` not `param0`) for delegates used by app code.
- [ ] `unowned` on `In` wide-string parameters (match spike).

**P2 — later / Track B**

- [ ] `[Compact]` ergonomic wrappers + signals in generator.
- [ ] `win32-plumbing.c` if delegate marshalling still unsafe.
- [ ] Broader `TypeRef` (`ApiRef`, pointers, `MemorySize` attrs).
- [ ] Broader `TypeRef` (`ApiRef`, pointers, `MemorySize` attrs).
- [ ] **Per-json vapi emit** (see package layout — replaces monolithic `win32-ui.generated.vapi` for apps).

---

## Package layout — mirror win32json files

win32json is already split into **distinct namespace JSON files** (`UI.WindowsAndMessaging.json`, `UI.Controls.json`, …). `metadata/win32json-api.files` lists which blobs we vendor. **Phase 2 should emit vapi the same way**, not flatten everything into one ~42k-line file.

**Current (Phase 1):** all vendored JSON → single `vapi/win32-ui.generated.vapi`, one flat `namespace Win32 { … }`. Fine for pipeline proof; wrong shape for apps.

**Target (Phase 2):** **one input JSON → one output `.vapi`** (plus optional umbrella pkg).

Example layout:

```
vapi/generated/
  UI.WindowsAndMessaging.vapi   # message loop, WNDCLASS, CreateWindowExW, …
  Graphics.Gdi.vapi             # GDI types/constants hello may need
  UI.Controls.vapi              # Phase 3 — only if listed in win32json-api.files
  …
```

**Mapping (already in parser):**

- `UI.WindowsAndMessaging.json` → filter symbols as `Windows.Win32.UI.WindowsAndMessaging.*`
- Vala namespace per file — e.g. nested `Win32.Ui.WindowsAndMessaging { … }` (exact spelling TBD; align with `ApiFile.namespace_from_basename`)
- `--pkg` name derived from basename — e.g. `win32-ui-UI.WindowsAndMessaging` or a shortened pkg id + `.pc` per shard

**What hello-window needs (minimal pkgs):**

- `UI.WindowsAndMessaging.vapi` — core loop APIs
- `Graphics.Gdi.vapi` — if `COLOR_WINDOW` / brush constants live there
- Add JSON for loader APIs when vendored (e.g. `System.*` for `GetModuleHandleW`) — **same per-file rule**, not a special-case monolith

Apps then:

```vala
// using Win32.Ui.WindowsAndMessaging;  // after namespace decision
// valac --pkg win32-ui --pkg win32-ui-UI.WindowsAndMessaging …
```

**Benefits**

- Matches upstream metadata boundaries — vendor list, filter, and vapi stay aligned
- `valac` only parses shards the app imports
- `check-regen` can diff **per file** (smaller, reviewable)
- Phase 3 widens surface by **adding lines to `win32json-api.files`**, not by growing one blob

**Emitter changes for split output**

- [ ] `VapiEmitter.emit_file` → write `vapi/generated/<basename>.vapi` (one namespace block per file)
- [ ] `generate-binding` reads **`win32json-api.files`** (or api dir filtered by that list) — not “every `.json` in api/”
- [ ] Dedupe policy: **within a shard only**; cross-file duplicates become explicit (rare; handle if they appear)
- [ ] Optional thin `win32-ui.vapi` umbrella that `using`-aggregates common pkgs for convenience — not required for hello

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
- `src/Generate/NameMapper.vala` — extend — Unicode-only policy, param names
- `metadata/filters/gui.filter` — extend — drop Ansi duplicates if not already
- `metadata/win32json-api.files` — extend — add namespace JSON for `GetModuleHandleW` (if exists in win32json)
- `tools/generate-binding.vala` — extend — read `win32json-api.files`; emit **one `.vapi` per JSON basename**
- `vapi/generated/*.vapi` — regen — per-shard artifacts (replace monolith for apps)
- `vapi/win32-ui.generated.vapi` — optional — Phase 1 monolith; retire or concat-only for CI
- `vapi/win32-ui-native.vapi` — remove or replace — after hello migrates
- `examples/hello-window.vala` — update — `using` / packages; fewer local consts as emit improves
- `meson.build` — update — `compile-check` / `hello-window` link generated vapi
- `src/win32-plumbing.c` — create (if needed) — Track B only
- `examples/` — extend — optional ergonomic demo (Track B)

---

## Verification

**Generated syntax (regression from Phase 1)**

```bash
meson compile -C build regen
echo 'void main () { uint m = Win32.WM_DESTROY; }' > /tmp/gen-smoke.vala
valac vapi/win32-ui.generated.vapi /tmp/gen-smoke.vala -C -d /tmp
```

**Phase 2 done when (Track A)**

```bash
meson compile -C build compile-check    # uses generated (or slice), not spike
meson setup build-win --cross-file cross/mingw-w64.ini
meson compile -C build-win hello-window # runs on Windows / Wine
```

- `hello-window.vala` has **no** `using Win32Ui.Native` / `--pkg win32-ui-native` dependency on hand spike.
- Behaviour unchanged: window opens, `WM_DESTROY` quits loop.

**Track B** — optional; document in plan when started.

---

## Tasks

### Track A — hello-window

- [ ] **🔷** **⏳** Per-json vapi emit + pkg names; hello uses `UI.WindowsAndMessaging` (+ `Graphics.Gdi`, loader JSON when added)
- [ ] **🔷** **⏳** P0 emitter: delegate fields, `out`/`ref` Msg, scalar types
- [ ] **🔷** **⏳** Metadata/vendor: `GetModuleHandleW`
- [ ] **🔷** **⏳** Filter: Unicode-first API surface for hello path
- [ ] **🔷** **⏳** Migrate `hello-window.vala` + `meson.build`
- [ ] **🔷** **⏳** Remove or archive spike `win32-ui-native.vapi` once redundant
- [ ] **💩** **⏳** P1: const values / `WS_*` / `COLOR_WINDOW` where possible

### Track B — ergonomic (stretch)

- [ ] **🔷** **⏳** Measure vapi size; confirm split strategy
- [ ] **🔷** **⏳** Ergonomic emit for `Window` + `Button`
- [ ] **🔷** **⏳** Plumbing C only if proven necessary

---

## Hand-off to Phase 3

**ℹ️** [05 - phase 3 common controls.md](05%20-%20phase%203%20common%20controls.md) — widen `win32json-api.files`, generator emit for Button/Edit, `BN_CLICKED` → `clicked`, on top of a working hello baseline.
