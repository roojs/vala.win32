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

- **File:** `vapi/win32-ui.generated.vapi` (~1 MB, ~42k lines, GUI filter).
- **Syntax:** **✅** Full file passes `valac` (pointer `public const` omitted; scalars are declaration-only).
- **Namespace:** `Win32 { … }` (spike uses `Win32Ui.Native`).
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
- [ ] Split huge vapi vs single pkg (see below).

--- 

## Package layout options

- **Option 1 — Single generated pkg**
  - `win32-ui.generated.vapi` → rename or install as `win32-ui-native.vapi`; hello uses `--pkg win32-ui` only.
  - Pros: one regen artifact. Cons: ~42k lines, slow `valac`, hard review.

- **Option 2 — Curated hello slice**
  - Generator flag or filter profile `hello.filter` emits only message-loop + GDI brush constant symbols into `win32-ui-hello.vapi`.
  - Pros: small, fast, proves pipeline. Cons: two regen targets to maintain.

- **Option 3 — Generated + tiny hand shard**
  - Generated bulk + hand `win32-ui-bootstrap.vapi` for `get_module_handle` and literals until metadata complete.
  - Pros: unblocks hello quickly. Cons: two sources (document clearly).

**🔷** Decide in Phase 2 kickoff; default recommendation: **Option 2 or 3** for first hello switch, **Option 1** when emit quality is stable.

---

## Intended files

- `src/Generate/VapiEmitter.vala` — extend — `TypeRef`, attrs, const values, enum emit
- `src/Generate/NameMapper.vala` — extend — Unicode-only policy, param names
- `metadata/filters/gui.filter` — extend — drop Ansi duplicates if not already
- `metadata/win32json-api.files` — extend — add namespace JSON for `GetModuleHandleW` (if exists in win32json)
- `vapi/win32-ui.generated.vapi` — regen — target artifact
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

- [ ] **🔷** **⏳** Document package option (1/2/3) and namespace
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
