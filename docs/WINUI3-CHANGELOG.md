# WinUI3 / Windows build — changelog

**Source of truth for what changed.**

**Debugging method (mandatory — do not guess):** [windows-winui3-method.md](windows-winui3-method.md)

Agents: read the method doc and this file **before** any WinUI3 fix. Run `git diff f9bad4e`. Append here after every change.

**Related:** [windows-winui3-status.md](windows-winui3-status.md) (HRESULT layers) · [windows-winui3.md](windows-winui3.md) (setup) · [windows-build.md](windows-build.md)

---

## Baseline

| Item | Value |
|------|--------|
| Last **committed** good WinUI3 launch baseline | `f9bad4e` — *winui3 is partly working - working on buttons and text entry* |
| Known-good at baseline | `winui3-hello-native.exe` showed a window with **TextBlock labels** (`themed=0`); TextBox/Button not working yet |
| Hello **without** sparse | `cf233c0` (2026-06-09) — worked earlier; no sparse MSIX / embedded `<msix>` |
| Sparse identity introduced | **`f9bad4e` same commit** as labels baseline — not in `cf233c0` or `d6ac214` |
| Rejected commit (do not re-apply wholesale) | `d801516` — *winui3 totally broken* |
| Strategy since 2026-06-11 | **Forward port** from `d801516` (infrastructure only), stay on `f9bad4e` for host + sparse identity fields |

### Frozen at baseline (unchanged in working tree)

| File | Value | Why |
|------|-------|-----|
| `src/win32-ui-winui3-host.cpp` | `MddBootstrapInitializeOptions_None` | `OnPackageIdentity_NOOP` (`d801516`) passed bootstrap but `Application::Start` → `0x80040154` |
| `metadata/winui3-sparse/AppxManifest.xml` | `ProcessorArchitecture="x64"` | `neutral` (`d801516`) not re-applied |
| `metadata/winui3-sparse/AppxManifest.xml` | `<PackageDependency Name="Microsoft.WindowsAppRuntime.2" MinVersion="8002.1.3.0">` | Removing it + NOOP broke runtime class registration |

### Windows paths (canonical)

| Role | Path |
|------|------|
| Rsync repo on Windows | `C:\msys64\tmp\vala.win32\` |
| Meson objects | `C:\msys64\tmp\vala-win32-build-win\` |
| Shipped exes + logs | `C:\msys64\tmp\vala.win32\build-win\` |
| **Do not use** for builds | Samba `X:\vala.win32\` |

---

## Unreleased (working tree vs `f9bad4e`, not yet committed)

*Last updated: 2026-06-11*

### 2026-06-11 — restore layer 0 (cf233c0 hello)

**Intent:** Diff back to hello that worked; gate sparse/widgets until re-proven layer by layer.

| File | Change |
|------|--------|
| `src/win32-ui-winui3-host.cpp`, `host.h` | **Restored from `cf233c0`** — no sparse register, no package identity gate |
| `meson.build` | Hello + bootstrap only; removed widgets + embed-manifest targets |
| `scripts/build-win.sh` | `WINUI3_LAYER` (`hello`\|`widgets`\|`sparse`); sparse vendor/register only when `sparse` |
| `scripts/agent-remote-build.sh` | Default `AGENT_WINUI3_LAYER=hello`; skip SSH sparse setup unless `sparse` |
| `scripts/validate-winui3-build-win.sh` | Hello layer skips embedded `<msix>` and sparse checks |
| `scripts/agent-remote-winui3-run.ps1` | Runs hello exe unless layer widgets/sparse |
| `docs/windows-winui3-restore-layers.md` | **New** — layer table + checklists |

**Verified:** 2026-06-11 `./scripts/agent-remote-build.sh build` + `run` — compile OK; SSH launch test: **still running after 3s**, killed after 20s (`winui3-debug.log`: `OK: still running after 3s` / `OK: killed after 20s`). No early exit (bootstrap/SxS fail would exit immediately). cf233c0 hello **launches** without sparse. Interactive desktop still needed to see pixels.

### 2026-06-11 — add mandatory debugging method doc

**Intent:** Stop agents guessing manifest/bootstrap toggles; enforce diff + log forensics.

| File | Change |
|------|--------|
| `docs/windows-winui3-method.md` | **New** — anchor `f9bad4e`, `git diff` commands, log string table, one-layer rule, rejected `d801516` changes, agent checklist |
| `docs/WINUI3-CHANGELOG.md` | Link method doc at top |
| `docs/windows-winui3-status.md` | Method doc first; fix stale “register OK / msix.v1 OK” rows to match 2026-06-11 evidence |
| `docs/windows-winui3.md` | Link method doc as mandatory |
| `.cursor/rules/agent-windows-test.mdc` | “Do not guess” block + method doc required read |

### Summary

Forward-ported build/agent infrastructure from `d801516` onto `f9bad4e` baseline. One surgical manifest fix. Docs + agent rsync workflow. **Launch not re-verified** after this port.

### Metadata

| File | Change |
|------|--------|
| `metadata/winui3-sparse/AppxManifest.xml` | `IgnorableNamespaces`: `uap uap10 rescap` → **`uap rescap`** only (fixes `AllowExternalContent` indexing / `0x80073D2E`). **Kept** `x64` + `PackageDependency`. |
| `metadata/winui3-sparse/vala.win32.winui3.manifest` | Brief `msix.v1` experiment **reverted** — file matches `f9bad4e` again (`asm.v3` child elements). |

### Build / scripts (modified tracked files)

| File | Change |
|------|--------|
| `scripts/build-win.sh` | C: rsync path in header; sparse register **hard-fail**; sparse/runtime STOP emission; `copy_mingw_runtime_dlls_to_build_win()`; copy `.cer`; `AGENT_REMOTE_BUILD=1` fast path; agent **`ninja -t clean`** WinUI3 exes before compile (stale `d801516` link); compile `winui3-*-native` then embed-manifest |
| `scripts/vendor-winui3-sparse.sh` | Pack on `C:` (`LOCAL_SPARSE_MSIX`), call **`sign-winui3-sparse.sh`**, copy MSIX + cert to vendor dir |
| `scripts/register-winui3-sparse.sh` | `WINUI3_SKIP_SPARSE_REGISTER`; STOP banners; `Add-AppxPackage -Path` (not `-LiteralPath`); dev-mode log; structured failure reasons |
| `scripts/winui3-runtime-gate.sh` | Sparse STOP helpers; `winui3_build_win_shell_cmd()`; `winui3_register_sparse_ps()`; certutil path uses `ROOT` not hardcoded `X:`; `Add-AppxPackage -Path` in runtime install |
| `scripts/install-winui3-msix.sh` | `-Path` instead of `-LiteralPath` |
| `scripts/install-winui3-runtime.sh` | Better MSYS2 launch hint via `winui3_build_win_shell_cmd` |
| `scripts/setup-msys2-toolchain.sh` | Example path → `/c/msys64/tmp/vala.win32` |
| `scripts/vendor-winui3-sdk.sh` | Auto-download `webview2.nupkg` if missing (instead of hard error) |
| `scripts/vendor-webview2-sdk.sh`, `scripts/regen-webview2-json.sh` | Header examples → C: mirror path |
| `meson.build` | `mkdir -p` for `.exe.p` dirs (ergonomic apps, webview2 targets) — avoids ninja path errors |

### New files (untracked)

| File | Purpose |
|------|---------|
| `scripts/sign-winui3-sparse.sh` | Dev cert (openssl) + `signtool /pa` sign sparse MSIX; `CERT_FORMAT` bump regens cert |
| `scripts/agent-remote-build.sh` | Linux: rsync → remote build → SSH setup → pull `build-win/` |
| `scripts/agent-remote-winui3-setup.ps1` | SSH: trust cert + `Add-AppxPackage` with `ExternalLocation` = `build-win` |
| `scripts/agent-remote-winui3-run.ps1` | SSH: headless demo run + log |
| `scripts/agent-remote-winui3-probe.ps1`, `scripts/agent-remote-winui3-probe.sh` | Diagnostics |
| `scripts/validate-winui3-build-win.sh` | Pre-run checks (does **not** prove exe launch) |
| `docs/windows-winui3.md` | Setup + agent workflow |
| `docs/windows-winui3-status.md` | Symptom layers, anti-loop guide, forward-port table |
| `docs/WINUI3-CHANGELOG.md` | This file |
| `.cursor/rules/agent-windows-test.mdc` | Agent must use C: rsync path |

### Docs / README (path + workflow)

| File | Change |
|------|--------|
| `docs/windows-build.md` | **Primary path:** rsync `C:\msys64\tmp\vala.win32`. Removed Samba `X:` as default workflow. Agent section promoted. |
| `README.md` | Build examples → C: mirror |
| `metadata/webview2/README.md` | Regen example → C: mirror |
| `.cursor/rules/avoid-powershell.mdc` | No Samba builds |

### Explicitly NOT changed (vs `f9bad4e`)

- `src/win32-ui-winui3-host.cpp` — no `OnPackageIdentity_NOOP`
- `AppxManifest.xml` — no `neutral` arch, no removal of `PackageDependency`

### Rejected from `d801516` (do not re-apply without new changelog entry + test)

| Change | Failure observed |
|--------|------------------|
| `ProcessorArchitecture="neutral"` | Part of broken session; not forward-ported |
| Remove `<PackageDependency>` from sparse MSIX | `0x80040154` Class not registered at `Application::Start` |
| `MddBootstrapInitializeOptions_OnPackageIdentity_NOOP` | Bootstrap OK, then `0x80040154` |

### 2026-06-11 — diagnosis (evidence, not guesses)

**Symptom:** hello still broken after forward port.

| Evidence | What it proves |
|----------|----------------|
| `winui3-debug.log`: `bootstrap OK (sparse identity; bootstrap noop)` | Running **binary is `d801516`**, not current source — that string exists only in `git show d801516:src/win32-ui-winui3-host.cpp` |
| `git diff f9bad4e -- src/win32-ui-winui3-host.cpp` empty | Linux source **is** `f9bad4e` (`MddBootstrapInitializeOptions_None`) |
| Agent build log: only `[1/1] Generating winui3-*-embed-manifest` | Ninja did **not** relink host after rsync — stale `.exe` |
| `agent-winui3-setup.log` / SSH: `0x80073D2E` with `x64` + `PackageDependency` + ignorable fix | Register fails on **C:** path; **not observed** at `f9bad4e` (user path unknown — may have been `X:` or unsigned flow) |
| `0x80040154` Class not registered after noop bootstrap | Matches `d801516` session — **expected** with noop + no runtime in package graph |

**Reverted (speculative, no `f9bad4e` anchor):** brief `neutral` arch + remove `PackageDependency` — undone; only `f9bad4e` + ignorable fix remains.

**Next verified step:** `./scripts/agent-remote-build.sh build` with ninja clean — log must show `bootstrap OK (SDK 0x…)` not `noop`. Then re-test register.

### Verification status (as of last changelog update)

| Check | Status |
|-------|--------|
| Agent rsync + remote compile | Runs; **hello not verified** with fresh link |
| Sparse register on C: (`x64` + `PackageDependency`) | **FAIL** `0x80073D2E` in `agent-winui3-setup` SSH output 2026-06-11 |
| Stale `d801516` exe on C: | **PROVEN** by log string mismatch |
| Interactive hello window | **Not confirmed** since forward port |
| `themed=1` / TextBox / Button | **Not working** at baseline; separate issue |

---

## How to maintain this file

**Every agent session that edits WinUI3 manifests, host bootstrap, build scripts, or agent workflow must:**

1. Append a dated entry under **Unreleased** (or move to a dated **Released** section after commit).
2. List **each file** touched and **what** changed (not just “fixed WinUI3”).
3. Note **what was tried and rejected** if reversing a prior entry.
4. Update **Verification status** honestly.
5. If restoring a frozen baseline field, explain **why** with log HRESULT / test evidence.

### Entry template (copy for new changes)

```markdown
### YYYY-MM-DD — short title

**Intent:** one sentence.

| File | Change |
|------|--------|
| `path` | what changed |

**Rejected / reverted:** (if any)

**Verified:** what was run, pass/fail, log file.
```

After `git commit`, move the **Unreleased** block into:

```markdown
## Released YYYY-MM-DD (<commit-hash>) — commit subject
```

and start a fresh empty **Unreleased** section.

---

## Released

*(nothing yet — working tree changes above are pre-commit)*
