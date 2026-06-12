# WinUI3 — situation report (SITREP)

**Purpose:** When you hit a known error, read the matching section **before** changing code. Each section lists what was tried, what failed, and what **not** to retry without new log evidence + a [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) entry.

**Companion docs:**

| Doc | Role |
|-----|------|
| [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) | What changed, when, verification |
| [windows-winui3-method.md](windows-winui3-method.md) | Process: diff, one layer, logs |
| [windows-winui3-status.md](windows-winui3-status.md) | Layer overview, file map |
| [windows-winui3-restore-layers.md](windows-winui3-restore-layers.md) | `WINUI3_LAYER` hello vs widgets |

**Last updated:** 2026-06-11

---

## Agent loop (use every session)

1. **Find error** — HRESULT / symptom from pulled logs → matching § below.
2. **Dedup** — search [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) (Unreleased + Baseline) and this file **Tried** for the exact change. **If listed → do not apply;** use **Allowed next steps** or diagnostics only.
3. **Changelog FIRST** — append **PLANNED** entry ([changelog template](WINUI3-CHANGELOG.md#how-to-maintain--changelog-first-mandatory)). **No code until PLANNED exists.**
4. **One edit** — single layer / file group.
5. **Test** — `AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build` (+ `setup` / `run`).
6. **Complete** — changelog **Result** + this § (**Tried** or **Proof**).
7. **Repeat** until `package identity OK` + `OnLaunched complete (themed=0)`.

Re-applying a change already in changelog or **Tried** is forbidden (§11).

---

## Overall situation (agent C: path)

| Milestone | Status | Evidence |
|-----------|--------|----------|
| Hello (`winui3-hello-native.exe`) | **WORKS** | 2026-06-11 — `winui3-debug.log`: still running after 3s |
| Widgets compile + embed | **WORKS** | `WINUI3-VALIDATION.txt` |
| Sparse register (`Add-AppxPackage`) | **WORKS** (current tree) | `agent-winui3-setup.log` 14:43: `OK: registered vala.win32.WinUI3_1.0.0.0_neutral__…` |
| Sparse register (`f9bad4e` shape: `x64` + `PackageDependency`) | **FAIL** on agent | `0x80073D2E` — AppPackageLog: fails at `Indexed` / external location — §1 |
| Widgets launch (SSH `Start-Process`) | **FAIL** | Reports SxS — §3 note |
| Widgets launch (direct / probe) | **FAIL** §5 | `package identity OK` → `bootstrap OK (noop)` → **`0x80040154`** at `Application::Start` |
| Labels window (`themed=0`) | **NOT PROVEN** | Never reached `OnLaunched` |

**Honest summary (2026-06-11):** Register OK (`neutral`, no dep). **§4 fixed:** `OnPackageIdentity_NOOP` when identity OK → `bootstrap OK`. **§5 active:** `0x80040154` at `Application::Start`; `neutral`+`PackageDependency` breaks register (`0x80073D2E`).

---

## Quick index

| You see… | Section |
|----------|---------|
| `Add-AppxPackage` / `0x80073D2E` / “external location” / “signed namespace” | §1 |
| `0x800B0109` / untrusted cert | §2 |
| SxS / “side-by-side configuration is incorrect” at launch | §3 |
| `MddBootstrapInitialize2 failed 0x80070032` after `package identity OK` | §4 |
| `0x80040154` / Class not registered at `Application::Start` | §5 |
| Hello `MddBootstrapInitialize2 failed 0x80070520` | §6 |
| Log says `bootstrap noop` but source is `f9bad4e` | §7 |
| Agent: `FAIL: exited early` / instant exit | §8 |
| Hello broke after widgets work | §9 |
| Mixing manifest/bootstrap/register tweaks in one pass | §10 |
| Agent keeps flipping `neutral` / `x64` / `PackageDependency` / `msix.v1` / `asm.v3` | §11 |

---

## Section template (for maintainers)

When adding a new error situation, copy this block:

```markdown
## §N — Title (HRESULT / symptom)

**Layer:** A | B | C | D | process

### Symptoms
### Log files / strings
### Current status
### Frozen config (do not change casually)
### Tried — DO NOT RETRY
### Allowed next steps (evidence-based only)
### Proof of fixed
```

---

## §1 — Register: `0x80073D2E` at `Add-AppxPackage`

**Layer:** A (registration)

### Symptoms

- SSH / PowerShell: `Deployment failed with HRESULT: 0x80073D2E`
- Often paired with:
  - “publisher is not in the signed namespace”
  - “does not declare support for an external location”
- `WINUI3-VALIDATION.txt`: `sparse package NOT registered`
- Widgets exe **never reaches** `package identity OK` in `winui3-debug.log`

### Log files / strings

| File | What to look for |
|------|------------------|
| `build-win/agent-winui3-setup.log` | cert import OK, then PowerShell error |
| Agent SSH output | `Add-AppxPackage` at `agent-remote-winui3-setup.ps1:46` |
| `build-win/last-build.log` | `[register-winui3-sparse] skipped` during agent build (register done in setup) |

**Diagnostics (2026-06-11 14:40):** `Get-AppPackageLog` on `x64`+`PackageDependency` failure — signature **valid** (`CN=vala.win32`); real error: *“does not declare support for an external location”* at state `BundleProcessed` → failed before `Indexed`. Developer Mode = 1.

**Register PASS (2026-06-11 14:43):** `AppxManifest.xml` aligned to [Microsoft sparse-identity template](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps): `neutral`, no `<PackageDependency>`, `IgnorableNamespaces="uap uap10 rescap"`. `agent-winui3-setup.log`: `OK: registered vala.win32.WinUI3_1.0.0.0_neutral__e82n2rykaaer4`.

### Current status

| Manifest shape | Register on agent C: |
|----------------|----------------------|
| `f9bad4e` (`x64` + `PackageDependency` + ignorable `uap rescap` only) | **FAIL** `0x80073D2E` |
| MS official sparse identity (`neutral`, no `PackageDependency`) | **PASS** (14:43) |

**Working tree today** uses MS official sparse shape for register. That is **not** the same as `f9bad4e` git anchor.

### Two anchors (do not conflate)

| Anchor | Role |
|--------|------|
| **`f9bad4e`** | User had **labels window** (`themed=0`) — manifest was `x64` + `PackageDependency` + `asm.v3` embed |
| **MS sparse-identity doc (2026)** | Agent **register** only passes with `neutral` + no `PackageDependency` |

We have **not** proven `f9bad4e` launch on agent. We have **not** proven labels window with MS manifest.

### Tried — DO NOT RETRY (without new evidence)

| Attempt | When | Result | Notes |
|---------|------|--------|-------|
| `IgnorableNamespaces="uap rescap"` only (drop `uap10`) + `x64` + `PackageDependency` | 14:22–14:36 | **FAIL** `0x80073D2E` | AppPackageLog: external location not indexed |
| `neutral` + remove `PackageDependency` (stale MSIX / early session) | 14:20 | **FAIL** | Before full MS template; do not treat as same experiment |
| Flip back to `x64`+`PackageDependency` “to match f9bad4e” | — | **Will break register** on agent | Known from 14:36 |
| Re-run register without MSIX rebuild | — | Wastes time | — |

### Allowed next steps (register — only if register regresses)

1. Keep MS official `AppxManifest.xml` for agent register until launch path is understood.
2. `Get-AppPackageLog -ActivityID …` (now logged in `agent-remote-winui3-setup.ps1`).
3. Compare **user machine** where `f9bad4e` worked: how was sparse registered? Same manifest bytes?

**Do not** toggle `neutral`/`x64`/`PackageDependency` again for register — see §11.

### Proof of fixed (register)

```text
agent-winui3-setup.log: OK: registered vala.win32.WinUI3_1.0.0.0_neutral__...
Get-AppxPackage -Name vala.win32.WinUI3  # returns package
```

---

## §2 — Register: cert trust `0x800B0109`

**Layer:** A (registration)

### Symptoms

- `Add-AppxPackage`: untrusted / signature / `0x800B0109`
- Before “external location” errors

### Log files / strings

- `agent-winui3-setup.log`: `Import-Certificate` / `certutil` lines
- `sign-winui3-sparse.sh`: `certutil trust failed` warning

### Current status

**Not the active blocker** — agent imports cert to `TrustedPeople` OK (2026-06-11). Failure moved to §1.

### Frozen config

- Dev cert: `sign-winui3-sparse.sh`, `CERT_FORMAT=4`, EKU lifetime-signing + codeSigning
- Trust: `CurrentUser\TrustedPeople` (+ `Root` via certutil)

### Tried — DO NOT RETRY

| Attempt | Notes |
|---------|-------|
| Unsigned MSIX / skip signtool | Fails register |
| Asking user to run certutil manually | Agent `setup` subcommand handles this |

### Allowed next steps

If §1 errors disappear and §2 returns: bump `CERT_FORMAT`, rebuild MSIX, re-run `setup` only.

### Proof of fixed

`Add-AppxPackage` proceeds past signature check (next error would be different HRESULT).

---

## §3 — Launch: SxS (“side-by-side configuration is incorrect”)

**Layer:** B (launch, before WinUI `main`)

### Symptoms

- Windows dialog or SSH: “side-by-side configuration is incorrect”
- Agent: `agent launch failed over SSH: ... side-by-side configuration is incorrect`
- Process exits before `[winui3] starting application` in log

### Log files / strings

| File | Example (2026-06-11 14:44) |
|------|----------------------------|
| `build-win/winui3-debug.log` | `agent launch failed over SSH: ... side-by-side` |
| `build-win/agent-winui3-setup.log` | `OK: registered vala.win32.WinUI3_1.0.0.0_neutral__…` **same session** |

### Current status

**Partially resolved:** Embedded `msix.v1` + registered neutral package → **direct run** gets `package identity OK` (probe 14:54).

**SSH `Start-Process`** in `agent-remote-winui3-run.ps1` still reports SxS — agent launch metric is **unreliable**; use probe or `winui3-debug.log` from direct run.

**Not the active layer** if log shows `package identity OK` (failure moved to §4).

### Tried — DO NOT RETRY

| Attempt | When | Result |
|---------|------|--------|
| `asm.v3` child-element `<msix>` (`f9bad4e`) + register fail | pre-14:43 | SxS (register also failed) |
| `msix.v1` attribute form + register OK | 14:43–14:44 | **Still SxS** — launch not fixed |
| Register again when already registered | 14:44 | No change |
| Embed `<msix>` in hello exe | earlier | Broke hello — §6 |

### Allowed next steps (NOT more xmlns/arch toggles)

1. **`sxstrace.exe`** on Windows: `agent-remote-winui3-probe.ps1` or manual trace — read **named** missing assembly.
2. **`mt.exe -inputresource:winui3-widgets-native.exe;#1`** — confirm publisher/packageName/applicationId match registered neutral package.
3. Confirm **`ExternalLocation`** at register = `C:\msys64\tmp\vala.win32\build-win` (exact).
4. **Local interactive run** on Windows desktop (SSH launch may differ).
5. Ask user how **`f9bad4e` register** worked on their machine (path, manifest bytes).

### Proof of fixed

```text
winui3-debug.log: [winui3] starting application
winui3-debug.log: [winui3] package identity OK
winui3-debug.log: OnLaunched complete (themed=0)
```

---

## §4 — Bootstrap: `0x80070032` after `package identity OK`

**Layer:** C (bootstrap)

### Symptoms

- Log: `MddBootstrapInitialize2 failed` with `0x80070032` (`ERROR_NOT_SUPPORTED`)
- Only after sparse identity is OK

### Log files / strings

- `winui3-debug.log`: after `package identity OK`

### Current status

**ACTIVE BLOCKER** (2026-06-11 14:54 probe). Direct run after register OK:

```text
[winui3] package identity OK
[winui3] ERROR: MddBootstrapInitialize2 failed 0x80070032
```

Context: MS sparse `AppxManifest` (**no** `<PackageDependency>`). `f9bad4e` had `PackageDependency` in sparse MSIX on user machine.

### Frozen config

- `MddBootstrapInitializeOptions_None` — do **not** switch to NOOP without new evidence (§5)

### Tried — DO NOT RETRY

| Attempt | Result | Why not again |
|---------|--------|----------------|
| `OnPackageIdentity_NOOP` | → `0x80040154` at `Application::Start` | `d801516` |
| NOOP + remove `PackageDependency` | `0x80040154` | Same |
| Flip `msix.v1` / `neutral` / ignorable to fix **this** | N/A | Already at MS shape; still `0x80070032` |
| `neutral` + add `<PackageDependency>` only | 14:59 | Register OK; **same** `0x80070032` — §11 duplicate; **reverted** |
| Force vendored **2.1.3** MSIX (`WINUI3_FORCE_RUNTIME_MSIX=1`) | 15:03 | **`0x80073D06`** — framework 2.2.0.0 blocks downgrade in place |
| Remove stack + reinstall 2.1.3 (SSH `agent-remote-winui3-runtime-pin.ps1`) | ~15:09 | Runtime **aligned 2.1.3.0**; bootstrap **still `0x80070032`** |

### Allowed next steps (dedup-safe)

1. ~~Verify runtime packages~~ — done 15:01.
2. ~~Force overlay 2.1.3 MSIX~~ — `0x80073D06` (15:03).
3. ~~Remove dependents + reinstall 2.1.3~~ — **done ~15:09**; runtime OK, bootstrap still fails.
4. **User input:** how did `f9bad4e` register (`x64`+`PackageDependency`) **and** bootstrap on your machine?
5. **Not** blind `neutral`/`x64`/`PackageDependency` toggles — §11; version skew alone did not fix §4.

**BLOCKED without user/evidence:** restoring `<PackageDependency>` only (register regression risk); `OnPackageIdentity_NOOP`.

### Proof of fixed

`[winui3] bootstrap OK (SDK 0x...)` in log (not `bootstrap noop`).

---

## §5 — WinUI start: `0x80040154` (Class not registered)

**Layer:** D (`Application::Start`)

### Symptoms

- Log / MessageBox: `0x80040154` at `Application::Start`
- Often after NOOP bootstrap experiments

### Current status

**Known from `d801516`** — not current agent failure mode.

### Tried — DO NOT RETRY

| Attempt | Result |
|---------|--------|
| `OnPackageIdentity_NOOP` | `0x80040154` |
| Remove `<PackageDependency>` from sparse MSIX + NOOP | `0x80040154` |
| Remove dependency “because Microsoft sample has none” | Breaks runtime class registration in our graph |
| `DeploymentManager::Initialize()` after NOOP bootstrap | ~15:22 — throws **`0x80040154`** before `Application::Start` |

### Allowed next steps

Agent path **blocked:** register-PASS manifest has no `<PackageDependency>`; adding it breaks register (`0x80073D2E`). Host layers through §5 exhausted on agent without `f9bad4e` register story.

### Proof of fixed

`OnLaunched complete (themed=0)` in `winui3-debug.log`.

---

## §6 — Hello bootstrap: `0x80070520`

**Layer:** C (hello only — no sparse)

### Symptoms

- Hello exe exits immediately; log: `MddBootstrapInitialize2 failed 0x80070520`
- Or instant exit without message loop

### Log files / strings

- `winui3-debug.log`: `hello layer (no sparse)` was from a **bad intermediate** build — cf233c0 hello should **not** need sparse

### Current status

**FIXED** when hello uses `hello_layer` entry (cf233c0) and is **not** embedded with `<msix>`.

### Tried — DO NOT RETRY

| Attempt | Result |
|---------|--------|
| Route hello through `winui3_ensure_package_identity()` | Needs sparse; wrong layer |
| Embed `<msix>` into hello during widgets build | `0x80070520` / SxS |
| Widgets-layer host for hello exe | Same |

### Frozen config

- `winui3_run_hello_window()` → `hello_layer` namespace, **no** sparse, **no** embed
- `WINUI3_LAYER=hello`: no `winui3-widgets-embed-manifest` in build

### Proof of fixed

Hello agent run: still running after 3s (2026-06-11).

---

## §7 — Stale binary (source vs log mismatch)

**Layer:** Process / build

### Symptoms

- Log string **not in** current source at `git show HEAD:...`
- Example: `bootstrap OK (sparse identity; bootstrap noop)` — exists only in `d801516` host

### Tried — DO NOT RETRY

| Attempt | Why wrong |
|---------|-----------|
| “Fix” manifest when binary is stale | Edits wrong problem |
| Skip rebuild after rsync | Ninja may not relink |

### Fix (works)

- Agent: `ninja -t clean winui3-*-native.exe` before compile (`build-win.sh`)
- Rebuild; match log strings to `git show` for **built** commit

### Proof of fixed

Log bootstrap line matches current `host.cpp` (e.g. `bootstrap OK (SDK 0x...)` for widgets, no bootstrap log for minimal hello).

---

## §8 — Agent run: early exit / instant fail

**Layer:** Launch / environment

### Symptoms

- `agent-remote-winui3-run.ps1`: `FAIL: exited early with code N`
- Or `agent launch skipped over SSH`

### Interpretation map

| Exit / message | Likely section |
|----------------|----------------|
| SxS text | §3 (often §1) |
| Code 1, no UI, widgets | §1 + §3 |
| Hello: exit &lt;3s | §6 or §7 |
| `agent launch skipped` | SSH/UI limitation — **not** proof of fix; try local interactive run after §1–§3 clear |

### Tried — DO NOT RETRY

| Attempt | Why |
|---------|-----|
| Claim widgets working from hello agent run | Wrong exe |
| Claim launch proof from `WINUI3-VALIDATION.txt` alone | Validate does not start GUI |

---

## §9 — Process: hello broke while working on widgets

**Layer:** Process (layer mixing)

### Symptoms

- Hello worked; widgets work broke hello (or vice versa)

### Root causes (proven)

1. Hello called sparse gate (`winui3_ensure_package_identity`)
2. Widgets build embedded `<msix>` into hello exe
3. Default build compiled wrong layer

### Tried — DO NOT RETRY

| Attempt | Why |
|---------|-----|
| One shared code path for both without layer discipline | Regresses hello |
| `git reset --hard` to old commits | User forbade destroying history |
| Wholesale re-apply `d801516` | Known broken |

### Frozen rules

| Layer | Build | Hello entry |
|-------|-------|-------------|
| `hello` | compile hello only, no embed, no sparse | `hello_layer` / cf233c0 |
| `widgets` | compile+embed **widgets only** | do not copy widgets exe over hello workflow |

### Proof

Both layers pass **independently**: hello agent run OK; widgets §1 then launch §3.

---

## §10 — Process: circular “fixes” (multi-knob toggles)

**Layer:** Process

### Symptoms

- Same HRESULT after many edits
- Changelog lists opposing manifest changes
- Agent suggests neutral arch **and** noop bootstrap **and** drop dependency

### Tried — DO NOT RETRY

**Any single debugging session that changes more than one of:**

- `ProcessorArchitecture`
- `<PackageDependency>`
- `MddBootstrapInitializeOptions_*`
- `IgnorableNamespaces` / `AllowExternalContent`
- Embedded manifest xmlns (`asm.v3` vs `msix.v1`)

### Required process

1. Identify layer from §1–§8
2. One edit
3. `agent-remote-build.sh build` (+ `setup`/`run` if widgets)
4. Update [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) + this SITREP if new evidence

---

## §11 — Manifest toggle loop (stop repeating)

**Layer:** Process

### What this is

Agents (and humans) have flipped the **same** sparse-manifest fields dozens of times across `d801516`, forward-port, and agent sessions:

- `ProcessorArchitecture` `x64` ↔ `neutral`
- `<PackageDependency Microsoft.WindowsAppRuntime.2>` present ↔ removed
- `IgnorableNamespaces` with ↔ without `uap10`
- Embedded `<msix>` `asm.v3` ↔ `msix.v1`

Each flip was documented as a “fix” then reverted. **That is not progress.**

### What we actually learned (2026-06-11)

| Configuration | Register agent C: | Launch agent |
|---------------|-------------------|--------------|
| `f9bad4e`-like (`x64`, `PackageDependency`, `uap rescap` ignorable) | FAIL | — |
| MS sparse doc (`neutral`, no dep, `uap uap10` ignorable) | **PASS** | **FAIL SxS** |
| + `msix.v1` in embedded exe | PASS | **FAIL SxS** |

So: **register ≠ launch**. Matching `f9bad4e` git diff is **not** sufficient for agent path. More manifest toggles without `sxstrace` / user `f9bad4e` register evidence = **forbidden loop**.

### DO NOT RETRY (until new evidence)

- Another pass of neutral / x64 / PackageDependency / ignorable / msix.v1 / asm.v3 **without** `sxstrace` output or user-confirmed `f9bad4e` register steps
- Claiming “diff back to f9bad4e” while changing sparse manifest to MS template
- “Just one more manifest tweak” after §3 still SxS with register OK

### Allowed next

- Instrumentation (`sxstrace`, `mt.exe` extract, `Get-AppPackageLog`)
- User interview: exact steps when labels window worked
- Host/runtime layer **only after** log shows past SxS (`package identity OK`)

---

## Maintenance

**Order matters:**

| When | Action |
|------|--------|
| **Before edit** | Changelog **PLANNED** + dedup grep; SITREP note if needed |
| **After test** | Changelog **Result**; SITREP **Tried** or **Proof**; Overall situation if changed |

If dedup blocks the idea, changelog entry: `**Dedup:** BLOCKED — cites …` and **no code change**.

**Do not** duplicate long narratives — SITREP = playbook; changelog = history + PLANNED/RESULT; method = procedure.
