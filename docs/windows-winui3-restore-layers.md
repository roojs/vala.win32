# WinUI3 incremental restore layers

**Strategy:** diff back to **known-good hello** (`cf233c0`), prove each layer on `C:\msys64\tmp\vala.win32\build-win`, then add the next commit’s changes only when the previous layer passes.

**Do not** re-apply `d801516` or toggle manifest/bootstrap fields without a changelog entry and log proof.

Method: [windows-winui3-method.md](windows-winui3-method.md) · History: [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md)

---

## Layers (git commits)

| Layer | `WINUI3_LAYER` | Git anchor | What it adds | Proof before next layer |
|-------|----------------|------------|--------------|-------------------------|
| **0 — Hello** | `hello` (**default**) | `cf233c0` | Bootstrap only; no sparse MSIX; no embedded `<msix>`; no widgets | `winui3-hello-native.exe` window on Windows; log past bootstrap |
| **1 — Widgets (labels)** | `widgets` | `f9bad4e` | Sparse + embed + `winui3-widgets-native`; `themed=0` skips TextBox/Button | Window with TextBlock labels; log `OnLaunched complete (themed=0)` |
| **2 — Sparse** | `sparse` | (alias) | Same as `widgets` | — |

**Broken — do not use as a layer:** `d801516` (*winui3 totally broken*).

---

## Current repo state

**Layer 0 (hello)** — `cf233c0`:

- `src/win32-ui-winui3-host.cpp` — `winui3_run_hello_window()` is cf233c0 (no sparse); widgets entry is separate
- `src/win32-ui-winui3-host.h`
- `meson.build` — `winui3-hello-native` + bootstrap copy only (no embed, no widgets targets)

Kept from forward port (infrastructure, not launch logic):

- Agent rsync, `C:` paths, MinGW DLL copy, runtime install scripts, docs

**Layer 1 (widgets labels)** — `f9bad4e` host + sparse + embed; `WINUI3_LAYER=widgets`

Gated off when `WINUI3_LAYER=hello`:

- sparse vendor/register/embed not run
- only `winui3-hello-native` compiled

---

## Build commands

**Agent (Linux) — default hello layer:**

```bash
./scripts/agent-remote-build.sh build
# same as AGENT_WINUI3_LAYER=hello
```

**Widgets labels milestone (after hello proven):**

```bash
AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build
```

Requires restoring `meson.build` widgets + embed targets from `f9bad4e` first (not done automatically yet).

**Windows UCRT64:**

```bash
WINUI3_LAYER=hello ./scripts/build-win.sh
```

---

## How to add the next layer

1. `git diff <prev-commit> <next-commit> -- <files>` — list exact deltas.
2. Apply **only** that commit’s launch-critical changes (not whole `d801516`).
3. Set `WINUI3_LAYER` and restore any meson targets needed.
4. `./scripts/agent-remote-build.sh build` → read `build-win/winui3-debug.log`.
5. Append [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) with evidence.

### Layer 1 checklist (`d6ac214`)

- [ ] `git diff cf233c0 d6ac214 -- src/win32-ui-winui3-host.cpp meson.build examples/native/winui3-widgets.vala`
- [ ] Re-add `winui3-widgets-native` meson target (no embed yet)
- [ ] `WINUI3_LAYER=widgets`
- [ ] Prove widgets + hello on C:

### Layer 2 checklist (`f9bad4e`)

- [ ] `git diff d6ac214 f9bad4e -- metadata/winui3-sparse/ scripts/embed-winui3-manifest.sh scripts/register-winui3-sparse.sh scripts/vendor-winui3-sparse.sh src/win32-ui-winui3-host.cpp meson.build`
- [ ] Re-add embed-manifest meson targets
- [ ] `WINUI3_LAYER=sparse`
- [ ] Prove register (`agent-winui3-setup.log`) then hello with labels

---

## Diff commands (copy-paste)

```bash
# What changed since hello worked?
git diff cf233c0 --stat

# Layer 1 delta only
git diff cf233c0 d6ac214 -- src/win32-ui-winui3-host.cpp meson.build examples/

# Layer 2 delta only
git diff d6ac214 f9bad4e -- metadata/winui3-sparse/ scripts/embed-winui3-manifest.sh \
  scripts/register-winui3-sparse.sh scripts/vendor-winui3-sparse.sh src/win32-ui-winui3-host.cpp meson.build
```
