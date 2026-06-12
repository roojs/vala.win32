# WinUI3 / Windows build — changelog

**Source of truth for what changed.**

**Agent loop:** [windows-winui3-method.md](windows-winui3-method.md) § Agent loop — **changelog entry BEFORE any edit**; if already in this file or SITREP **Tried**, do not apply again.

**Process:** [WINUI3-SITREP.md](WINUI3-SITREP.md) (per-error tried/rejected)

---

## Baseline

| Item | Value |
|------|--------|
| Git anchor — labels window once worked | `f9bad4e` (`x64`, `PackageDependency`, `asm.v3` embed) — **user machine** |
| Git anchor — hello without sparse | `cf233c0` |
| Rejected wholesale | `d801516` |
| Agent register (2026-06-11) | **MS sparse-identity `AppxManifest`** (`neutral`, no `PackageDependency`) — **not** `f9bad4e` shape |

### Two manifests, two stories (do not merge)

| | `f9bad4e` (user) | Working tree (agent register) |
|--|------------------|-------------------------------|
| `AppxManifest` arch | `x64` | `neutral` |
| `PackageDependency` | present | **removed** |
| Embedded `<msix>` | `asm.v3` | `msix.v1` (in current source + built exe) |
| Register on agent C: | **FAIL** `0x80073D2E` | **PASS** 14:43 |
| Launch on agent | unknown / not reproduced | **FAIL** SxS 14:44 |

**Do not** claim “back to f9bad4e” while using MS sparse manifest for register. See SITREP §11.

### Frozen (host — not manifest)

| File | Value | Why |
|------|-------|-----|
| `winui3_run_hello_window` | `hello_layer` / cf233c0, no sparse | §6 / §9 |
| Widgets bootstrap | `OnPackageIdentity_NOOP` when sparse identity OK | `None` → `0x80070032` (§4) |

### Manifest toggles — stop the loop (§11)

Do **not** flip again without `sxstrace` or user `f9bad4e` register evidence:

`neutral` ↔ `x64` · `PackageDependency` on/off · `uap10` in ignorable · `asm.v3` ↔ `msix.v1`

---

## Unreleased

*Last updated: 2026-06-11*

### 2026-06-11 — unpackaged widgets: StackPanel + labels, no sparse (PLANNED)

**Intent:** Try one extra control on **hello-style** path (`bootstrap None`, no `winui3_ensure_package_identity`, no embed). `WINUI3_UNPACKAGED_WIDGETS=1` selects path.

**Dedup:** sparse path exhausted on agent; unpackaged widgets **not tried**. **Proceed.**

| File | Change |
|------|--------|
| `src/win32-ui-winui3-host.cpp` | `unpackaged_widgets_layer::LabelDemoApp` (StackPanel + 2× TextBlock); env gate in `winui3_run_widgets_demo` |
| `scripts/build-win.sh` | Skip sparse + embed when `WINUI3_UNPACKAGED_WIDGETS=1` |

**Expected:** `OnLaunched complete (unpackaged=1)` without register/setup.

**Result:** FAIL bootstrap — path runs, no sparse.

| Log | Value |
|-----|-------|
| With `WINUI3_UNPACKAGED_WIDGETS=1` | `unpackaged widgets path (no sparse)` |
| Bootstrap | **`0x80070520`** (hello path may still work — agent runtime state TBD) |

**Verified:** `WINUI3_UNPACKAGED_WIDGETS=1 AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build` + SSH launch 2026-06-11 ~15:46.

**Use:** `set WINUI3_UNPACKAGED_WIDGETS=1` then `winui3-widgets-native.exe` (no setup/register).

---

### 2026-06-11 — §5 Layer D: `DeploymentManager::Initialize` after NOOP bootstrap (PLANNED)

**Intent:** `bootstrap OK (noop)` then `Application::Start` **`0x80040154`**. MS deploy guide: Main/Singleton must be in process graph. Call `DeploymentManager::Initialize()` after bootstrap — host only.

**Dedup:** not in SITREP **Tried**. **Proceed.**

| File | Change |
|------|--------|
| `src/win32-ui-winui3-host.cpp` | `#include` + `DeploymentManager::Initialize()` + log status before `Application::Start` |

**Result:** FAIL — `DeploymentManager::Initialize()` throws **`0x80040154`** (before `Application::Start`); no status line logged.

**Verified:** SSH ninja+embed+launch 2026-06-11 ~15:22.

---

### 2026-06-11 — §4 Layer C: `OnPackageIdentity_NOOP` (sparse identity already OK) (PLANNED)

**Intent:** Log shows `package identity OK` then `MddBootstrapInitialize2` **`0x80070032`** with `MddBootstrapInitializeOptions_None`. [MS bootstrap API](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/win32/mddbootstrap/nf-mddbootstrap-mddbootstrapinitialize2): when process **already has package identity**, use **`OnPackageIdentity_NOOP`**. Runtime stack **2.1.3.0** aligned (~15:09) — not same session as `d801516` `0x80040154`.

**Dedup:** `d801516` NOOP+no-dep → `0x80040154` listed in §5. **New evidence:** identity OK + `None` → `0x80070032`; MS doc maps that state → NOOP. **Proceed** (Layer C only).

| File | Change |
|------|--------|
| `src/win32-ui-winui3-host.cpp` | `run_winui3_application`: `MddBootstrapInitializeOptions_OnPackageIdentity_NOOP`; hello stays `None` |

| Test | SSH recompile widgets exe only + probe |
|------|----------------------------------------|

**Expected:** `bootstrap OK` or `0x80040154` at `Application::Start` (either is new data).

**Result:** PASS bootstrap — FAIL `Application::Start`.

| Log | Value |
|-----|-------|
| After manifest embed + NOOP | `package identity OK` → `bootstrap OK (… noop)` → `XamlCheckProcessRequirements done` |
| Next | `run_winui3_application (HRESULT 0x80040154)` Class not registered |

**Verified:** SSH ninja + embed + probe 2026-06-11 15:17. **§4 resolved**; active error **§5**.

**Next:** §5 — `PackageDependency` in sparse MSIX with NOOP host (not tried together; prior `neutral`+dep used `None`).

---

### 2026-06-11 — §5: sparse `PackageDependency` + NOOP bootstrap (PLANNED)

**Intent:** `0x80040154` at `Application::Start` — runtime not in package graph. Prior `neutral`+dep failed with **`None`** (`0x80070032`). Host now **NOOP** (bootstrap OK). Add `<PackageDependency>` only; SSH repack/register/probe.

**Dedup:** `neutral`+dep+`None` tried (§4). **`neutral`+dep+NOOP** not tried. **Proceed.**

| File | Change |
|------|--------|
| `metadata/winui3-sparse/AppxManifest.xml` | Add `<PackageDependency Microsoft.WindowsAppRuntime.2 MinVersion="8002.1.3.0">` (keep `neutral`) |

**Expected:** `OnLaunched complete (themed=0)`.

**Result:** FAIL register — cannot test launch.

| Evidence | Value |
|----------|-------|
| `Add-AppxPackage` | **`0x80073D2E`** — external location not indexed with `neutral`+`PackageDependency` |
| AppPackageLog | Same as §1 `x64`+dep failure pattern |

**Verified:** SSH repack+setup 2026-06-11 15:18. Manifest **reverted** to register-PASS (no dep).

**Agent best state:** `neutral`+no dep + **NOOP** host + runtime 2.1.3 → `bootstrap OK`, **`0x80040154`** at `Application::Start`.

---

### 2026-06-11 — §1+§4: exact `f9bad4e` `AppxManifest` — **BLOCKED (§11 repeat)**

**Intent:** *(agent started same manifest loop again — user stop.)*

**Dedup:** **BLOCKED.** `x64` + `PackageDependency` is §11 frozen; changelog already records `0x80073D2E` on agent and `neutral`+dep still `0x80070032`. “Exact f9bad4e bytes” is not a new lever. **Reverted** `AppxManifest.xml` to register-PASS shape (neutral, no dep).

**Result:** Not run. Manifest reverted.

---

### 2026-06-11 — §3 diagnostics: sxstrace + mt.exe extract (PLANNED)

**Intent:** Fresh iteration — register OK, SxS at launch. **No manifest/host edits.** Collect named assembly from `sxstrace` and embedded manifest from built exe.

**Dedup:** grep changelog — `sxstrace` listed as allowed next step only; **not** previously run with result logged. Not a manifest knob. **Proceed.**

| Action | Planned |
|--------|---------|
| `AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh setup` | Re-register sparse |
| SSH `agent-remote-winui3-probe.ps1` | sxstrace + mt extract → `build-win/agent-probe.txt` |
| Pull | `agent-probe.txt`, `agent-extracted.manifest` |

**Expected:** `agent-probe.txt` names missing assembly or manifest mismatch; **not** another HRESULT guess.

**Result:** FAIL launch (exit 1) but **new layer identified** — not SxS on direct run.

| Evidence | Meaning |
|----------|---------|
| `agent-remote-winui3-run.ps1` / `Start-Process` | SxS error (misleading for SSH agent test) |
| Probe / direct run | `[winui3] package identity OK` then `MddBootstrapInitialize2 failed 0x80070032` |
| `mt.exe` extract | `msix.v1` matches sparse package (`CN=vala.win32`, `vala.win32.WinUI3`, `App`) |
| `Get-AppxPackage` | `vala.win32.WinUI3_1.0.0.0_neutral__…` registered |
| sxstrace parse | No useful lines in probe output (launch failed after main) |

**Verified:** `agent-remote-winui3-probe.ps1` 2026-06-11 14:54; `build-win/winui3-debug.log`, `agent-probe.txt`.

**Next:** §4 — see PLANNED entry below.

---

### 2026-06-11 — §4: `neutral` + restore `<PackageDependency>` — **BLOCKED (process failure)**

**Intent:** *(agent attempted without proper dedup)*

**Dedup:** **SHOULD NOT HAVE PROCEEDED.** Baseline §11 forbids `PackageDependency` on/off; SITREP §4 lists **`neutral`+`PackageDependency`** under “Not … without new register log proof” and **BLOCKED** restoring dependency only. Treat as duplicate knob — not a new experiment.

| File | Change attempted |
|------|------------------|
| `metadata/winui3-sparse/AppxManifest.xml` | Added `<PackageDependency>` — **reverted** to MS sparse (no dep) |

**Result:** FAIL — same bootstrap HRESULT. Register OK; launch unchanged.

| Evidence | Value |
|----------|-------|
| `agent-winui3-setup.log` 14:59 | `OK: registered …_neutral__…` |
| `winui3-debug.log` 14:59 | `package identity OK` → `MddBootstrapInitialize2 failed 0x80070032` |

**Verified:** `AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh run` 2026-06-11 14:59. Manifest reverted before next iteration.

---

### 2026-06-11 — §4 diagnostics: runtime package inventory vs SDK 2.1.3 (PLANNED)

**Intent:** SITREP §4 allowed steps **1–2** — no manifest/host edits. Collect `Get-AppxPackage` for `Microsoft.WindowsAppRuntime.*` / framework / Main / Singleton / DDLM; note installed versions vs vendored **2.1.3** (`vendor-winui3-sdk.sh` / `vendor-winui3-runtime.sh`).

**Dedup:** §3 probe collected sxstrace + embedded manifest only; **runtime inventory not yet logged.** Not a §11 knob. **Proceed.**

| File | Planned change |
|------|----------------|
| `scripts/agent-remote-winui3-probe.ps1` | Append `--- runtime packages ---` section: all WinAppRuntime-related packages (Name, Version, PackageFullName); `winui3_widgets_ready` equivalent flags |

| Action | Planned |
|--------|---------|
| `./scripts/agent-remote-build.sh sync` | Push probe script |
| SSH `agent-remote-winui3-probe.ps1` | Write `build-win/agent-probe.txt` |
| `./scripts/agent-remote-build.sh pull` | Read results |

**Expected:** `agent-probe.txt` shows whether **2.1.3** vs **2.2.x** mismatch explains `0x80070032`; informs next §4 lever (install pin vs user `f9bad4e` story).

**Result:** FAIL launch unchanged; **new evidence** — runtime version skew.

| Package | Installed version | SDK/vendor target |
|---------|-------------------|-------------------|
| `Microsoft.WindowsAppRuntime.2` (framework/DDLM) | **2.2.0.0** x64+x86 | **2.1.3** |
| `MicrosoftCorporationII.WinAppRuntime.Main.2` | 2.1.3.0 | 2.1.3 |
| `MicrosoftCorporationII.WinAppRuntime.Singleton` | 8002.1.3.0 | 2.1.3 |
| `widgets_ready` gate | framework+main+singleton **True** | gate does not check version |

**Verified:** `agent-remote-winui3-probe.ps1` 2026-06-11 15:01 → `build-win/agent-probe.txt`; bootstrap still `0x80070032`.

**Next:** §4 — force vendored **2.1.3** MSIX install (see PLANNED below).

---

### 2026-06-11 — §4: force vendored 2.1.3 runtime MSIX (align framework with SDK) (PLANNED)

**Intent:** Bootstrap links SDK **2.1.3** but framework package is **2.2.0.0** (probe 15:01). `winui3_widgets_ready` skips `install-winui3-runtime.sh`. Re-apply vendored 2.1.3 MSIX via `Add-AppxPackage -ForceUpdateFromAnyVersion` — **not** a manifest/host edit.

**Dedup:** not in changelog/SITREP **Tried**. §11 knobs untouched. **Proceed.**

| File | Planned change |
|------|----------------|
| `scripts/install-winui3-runtime.sh` | Honor `WINUI3_FORCE_RUNTIME_MSIX=1` — vendor + install MSIX even when `widgets_ready` |
| `scripts/agent-remote-build.sh` | Pass `WINUI3_FORCE_RUNTIME_MSIX` to remote build when set |

| Action | Planned |
|--------|---------|
| `WINUI3_FORCE_RUNTIME_MSIX=1 AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build` | Stage + install 2.1.3 MSIX, rebuild, setup, run |
| Probe if still FAIL | `agent-remote-winui3-probe.ps1` → confirm framework version |

**Expected:** `Microsoft.WindowsAppRuntime.2` at **2.1.3.x**; log `bootstrap OK` then `OnLaunched complete (themed=0)`.

**Result:** FAIL — cannot downgrade framework; bootstrap unchanged.

| Evidence | Value |
|----------|-------|
| `last-build.log` 15:03 | `Add-AppxPackage Microsoft.WindowsAppRuntime.2.msix` → **`0x80073D06`** — “higher version 2.2.0.0 already installed”, cannot install 2.1.3.0 |
| `winui3-debug.log` 15:03 | Still `package identity OK` → `MddBootstrapInitialize2 failed 0x80070032` |
| Framework after attempt | Still **2.2.0.0** (downgrade blocked by Windows) |

**Verified:** `WINUI3_FORCE_RUNTIME_MSIX=1 AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build` 2026-06-11 15:03.

**Conclusion:** Pin-to-2.1.3 path **dead** on this machine. Next §4 lever: **upgrade vendored SDK/runtime to 2.2.0** to match installed framework (see PLANNED below).

---

### 2026-06-11 — §4: vendor SDK/runtime 2.2.0 — **SUPERSEDED (not tested)**

**Intent:** Align bootstrap with installed framework 2.2.0.0.

**Result:** **Not run** — build interrupted; user asked to try **remove 2.2 + reinstall 2.1.3** instead (keeps `f9bad4e` / SDK 2.1.3 anchor). `winui3-sdk-ref.txt` reverted to 2.1.3 before next test.

---

### 2026-06-11 — §4: remove framework 2.2 then install vendored 2.1.3 MSIX (PLANNED)

**Intent:** `Add-AppxPackage` alone failed **`0x80073D06`** (cannot downgrade in place). **New experiment:** `Remove-AppxPackage` on `Microsoft.WindowsAppRuntime.2` **≥ 2.2.0.0** (x64+x86), then install vendored **2.1.3** MSIX stack. Keeps SDK **`f9bad4e` / 2.1.3** — not §11 manifest toggle.

**Dedup:** overlay install only (15:03). **Remove-then-reinstall not tried.** **Proceed.**

| File | Planned change |
|------|----------------|
| `scripts/winui3-runtime-gate.sh` | `winui3_remove_newer_framework()` when `WINUI3_RUNTIME_REMOVE_NEWER=1`; call before `winui3_install_staged_msix` |
| `scripts/install-winui3-runtime.sh` | Document env var |
| `scripts/agent-remote-build.sh` | Pass `WINUI3_RUNTIME_REMOVE_NEWER` to remote build |
| `metadata/winui3-sdk-ref.txt` | Revert to **2.1.3** stack (undo superseded 2.2 edit) |

| Action | Planned |
|--------|---------|
| `WINUI3_FORCE_RUNTIME_MSIX=1 WINUI3_RUNTIME_REMOVE_NEWER=1 AGENT_WINUI3_LAYER=widgets ./scripts/agent-remote-build.sh build` | Remove 2.2 framework, install 2.1.3, rebuild, setup, run |
| Probe | Framework **2.1.3.x**; `bootstrap OK` |

**Expected:** `Microsoft.WindowsAppRuntime.2` at **2.1.3.0**; `OnLaunched complete (themed=0)`.

**Result:** FAIL launch — **runtime aligned** but bootstrap **unchanged**.

| Step | Outcome |
|------|---------|
| Remove framework 2.2 alone | **`0x80073CF3`** — Main/Singleton/DDLM depend on framework |
| Remove stack (Singleton → Main → DDLM → x86 framework) then install 2.1.3 MSIX | **OK** — `Microsoft.WindowsAppRuntime.2` **2.1.3.0**, Main/Singleton **2.1.3** |
| Launch `winui3-widgets-native.exe` (no rebuild) | Still `package identity OK` → **`MddBootstrapInitialize2 failed 0x80070032`** |

**Verified:** SSH `agent-remote-winui3-runtime-pin.ps1` 2026-06-11 ~15:09 — **no full build**.

**Conclusion:** Version skew was **necessary but not sufficient**. `0x80070032` persists with aligned 2.1.3 runtime — blocker is likely **sparse identity / package graph** (e.g. missing `PackageDependency` on register-pass manifest), not MSIX versions alone. Next: user `f9bad4e` register story or evidence-based register path — **not** another blind manifest toggle.

---

### 2026-06-11 — tighten agent loop: changelog-first + dedup (docs only)

**Intent:** User requirement — write planned change here **before** editing code; grep changelog/SITREP; if already tried, pick a different approach.

| File | Change |
|------|--------|
| `docs/WINUI3-CHANGELOG.md` | Changelog-first loop, dedup rule, entry template with PLANNED/RESULT |
| `docs/WINUI3-SITREP.md` | Loop reordered; dedup step |
| `docs/windows-winui3-method.md` | Loop reordered |
| `.cursor/rules/agent-windows-test.mdc` | Changelog-first mandatory |

**Verified:** documentation only — no manifest/host edits this entry.

---

### 2026-06-11 — §11: document manifest toggle loop; stop repeating

**Intent:** User flagged agent re-applied neutral / no-dep / msix.v1 ~30 times. Record honestly; freeze knob-flipping.

| Doc | Change |
|-----|--------|
| `docs/WINUI3-SITREP.md` | §11 manifest loop; §1 register PASS; §3 SxS still FAIL with msix.v1; overall table corrected |
| `docs/WINUI3-CHANGELOG.md` | Two-manifest table; maintenance rule |

**No code change this entry** — documentation only.

---

### 2026-06-11 — §3 attempt: `msix.v1` embedded manifest (launch still FAIL)

**Intent:** After register PASS, fix SxS per Microsoft embedded-manifest sample.

| File | Change |
|------|--------|
| `metadata/winui3-sparse/vala.win32.winui3.manifest` | `asm.v3` child elements → `msix.v1` attributes |

**SITREP:** §3 — register OK + msix.v1 in built exe → **still SxS** (`winui3-debug.log` 14:44).

**Do not retry** msix.v1 ↔ asm.v3 toggle without sxstrace (§11).

---

### 2026-06-11 — §1: MS official sparse `AppxManifest` → register PASS

**Intent:** `Get-AppPackageLog` showed `x64`+`PackageDependency` fails at `Indexed` (external location). Aligned to Microsoft sparse-identity template.

| File | Change |
|------|--------|
| `metadata/winui3-sparse/AppxManifest.xml` | `neutral`; remove `<PackageDependency>`; `IgnorableNamespaces="uap uap10 rescap"` |
| `scripts/agent-remote-winui3-setup.ps1` | Log `Get-AppPackageLog` messages, Developer Mode, cert subject on failure |

**Note:** Same knob set as prior `d801516` / 14:20 attempt — **context differs** (full MS template + AppPackageLog proof on `x64` failure). See §11 — not a “new” fix, a **documented** one.

**Verified:** `agent-winui3-setup.log` 14:43: `OK: registered vala.win32.WinUI3_1.0.0.0_neutral__e82n2rykaaer4`

**Prior FAIL (same day):** `x64` + `PackageDependency` + `uap rescap` only → `0x80073D2E` (AppPackageLog: signature OK, external location not declared at index).

---

### 2026-06-11 — agent loop + SITREP + setup diagnostics

| File | Change |
|------|--------|
| `docs/WINUI3-SITREP.md` | **New** §1–§11 |
| `docs/windows-winui3-method.md` | Mandatory agent loop |
| `scripts/agent-remote-winui3-setup.ps1` | `Get-AppPackageLog` on failure |

---

### 2026-06-11 — hello layer restored; widgets host from `f9bad4e`

| File | Change |
|------|--------|
| `src/win32-ui-winui3-host.cpp` | `hello_layer` (cf233c0) + widgets sparse path |
| `scripts/build-win.sh`, `meson.build` | Layer-gated compile/embed |
| `scripts/validate-winui3-build-win.sh` | Widgets layer checks widgets exe only |

**Verified hello:** SSH run — still running after 3s (14:34).

---

### Verification status

| Check | Status |
|-------|--------|
| Hello SSH launch | **PASS** |
| Widgets compile + embed | **PASS** |
| Register (`f9bad4e` shape on agent) | **FAIL** `0x80073D2E` |
| Register (MS sparse manifest, current tree) | **PASS** 14:43 |
| Widgets launch (SSH agent run) | **FAIL** — misleading SxS |
| Widgets launch (direct / probe) | **FAIL** §5 — `bootstrap OK (noop)` then **`0x80040154`** |
| Labels window `themed=0` | **NOT PROVEN** |

---

## How to maintain — changelog-first (mandatory)

### Before touching any file

1. **Find error** — pulled logs; note HRESULT / § in SITREP.
2. **Dedup** — search this file **and** [WINUI3-SITREP.md](WINUI3-SITREP.md) for the exact change (e.g. `neutral`, `PackageDependency`, `msix.v1`, `OnPackageIdentity_NOOP`).  
   - If **already listed** under Unreleased, Baseline “stop the loop”, or SITREP **Tried — DO NOT RETRY** → **do not apply again**. Choose diagnostics (`sxstrace`, `Get-AppPackageLog`, user interview) or a genuinely new lever.
3. **Append PLANNED entry** below (template) — **then** edit code/scripts.
4. **SITREP** — add matching PLANNED row or note “dedup blocked” if skipping.

### After build/test

5. **Same entry** — add **Result** / **Verified** (PASS/FAIL + log strings).
6. **SITREP** — move to **Tried** or **Proof of fixed**.
7. **Verification status** table — update honestly.

### Entry template

```markdown
### YYYY-MM-DD — title (§N) — PLANNED

**Intent:** one sentence. **Dedup:** grep changelog/SITREP for … — not found | BLOCKED (cite prior entry).

| File | Planned change |
|------|----------------|
| `path` | what you will change |

**Expected log change:**

---

**Result (after test):** PASS | FAIL — …
**Verified:** `AGENT_WINUI3_LAYER=… ./scripts/agent-remote-build.sh …` — log file + key lines
```

Do **not** edit manifests/host until the **PLANNED** block exists.

---

## Released

### 2026-06-11 (`467bdb3`) — rollback to helo

Hello layer + agent infra on top of `d801516`.
