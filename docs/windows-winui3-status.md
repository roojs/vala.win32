# WinUI3 sparse package — status & debugging history

**Last updated:** 2026-06-11

## Do not guess — use the method

**[windows-winui3-method.md](windows-winui3-method.md)** — mandatory process: diff vs `f9bad4e`, read logs, one layer at a time, update [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md).

**[WINUI3-SITREP.md](WINUI3-SITREP.md)** — per-error playbook: what was tried, **do not retry**, allowed next steps.

This status doc is **HRESULT / layer overview**. For anti-loop detail use SITREP; for history use changelog.

This document exists because we spent days **guessing** manifest/bootstrap/register tweaks. Stop that loop: method doc first, then this file for layer identification.

## Forward port (not revert)

Git history stays linear on **`f9bad4e`** (*partly working — window with labels*). Commit **`d801516`** (*totally broken*) was **not** reset onto; instead we **diffed and cherry-picked** what helped:

| Kept from `f9bad4e` (known-good launch path) | Ported from `d801516` (infrastructure) | **Not** re-applied from `d801516` |
|---------------------------------------------|----------------------------------------|-----------------------------------|
| `AppxManifest`: `x64` + `<PackageDependency>` | Signing (`sign-winui3-sparse.sh`), C: pack path | `ProcessorArchitecture="neutral"` |
| `MddBootstrapInitializeOptions_None` in host | MinGW DLL copy, agent `AGENT_REMOTE_BUILD`, STOP banners | `OnPackageIdentity_NOOP` |
| | register hard-fail, agent scripts, signing | `msix.v1` embedded manifest (reverted), `OnPackageIdentity_NOOP`, removing `<PackageDependency>` |

**Surgical manifest fix on top of `f9bad4e`:** `IgnorableNamespaces="uap rescap"` only (drop `uap10`) so `AllowExternalContent` indexes — without touching arch or runtime dependency.

**Bottom line:** Build pipeline and agent workflow are forward-ported. **Local interactive launch** from `C:\msys64\tmp\vala.win32\build-win` (rsync mirror) is the proof — do not claim WinUI3 working until `winui3-hello-native.exe` shows a window and log shows past bootstrap.

---

## Current state (honest)

| Layer | Status | Evidence |
|-------|--------|----------|
| Compile / link WinUI3 demos | **OK** | `build-win/last-build.log` exits 0; exes present |
| Embed application manifest (`mt.exe`) | **OK** | `[embed-winui3-manifest]` in build log |
| Embedded `<msix>` in built exe | **matches `f9bad4e` `asm.v3`** | validate script; not `msix.v1` |
| Pack + sign sparse MSIX | **OK** | `vala.win32.winui3.sparse.msix` beside exe; signtool `/pa` passes |
| `Add-AppxPackage` registration on C: | **FAIL (2026-06-11)** | `0x80073D2E` with `x64` + `PackageDependency` + ignorable fix — see changelog |
| Agent SSH setup (cert + register) | **FAIL until register fixed** | `agent-winui3-setup.log` |
| MinGW runtime DLLs beside exe (agent path) | **OK** | copied in `build-win.sh` |
| Stale `d801516` binary on C: | **PROVEN** | log: `bootstrap noop` but source is `f9bad4e` — see method doc §3 |
| **`winui3-hello-native.exe` launch (agent)** | **OK (2026-06-11)** | hello layer SSH run — see SITREP §6 |
| **`winui3-widgets-native.exe` launch (agent)** | **FAIL** | §1 register → §3 SxS — see SITREP |
| Themed controls (`themed=1`) | **NOT OK** | Blocked until interactive launch succeeds |

`WINUI3-VALIDATION.txt` can say **READY** while the exe still will not start. Do not treat validation alone as “done.”

---

## Two different errors (often conflated)

We spent days mixing these up. They need **different** fixes and diagnostics.

### A — Registration time (`Add-AppxPackage`)

| HRESULT | Symptom | Fix (done) |
|---------|---------|------------|
| `0x800B0109` | Untrusted self-signed cert | Trust `.cer` in `TrustedPeople` (+ often `Root`); cert must be end-entity with AppX lifetime-signing EKU |
| `0x80073D2E` | “does not declare support for an external location” | Sparse `AppxManifest.xml`: `uap10:AllowExternalContent` present, **`uap10` not in `IgnorableNamespaces`**, signed MSIX, `makeappx /nv`. If this returns with `PackageDependency` present, fix indexing/signing first — do not blindly drop the dependency. |

**If registration succeeds, do not keep re-running cert/register unless the cert format stamp changed (`CERT_FORMAT` in `sign-winui3-sparse.sh`) or the MSIX was rebuilt.**

### B — Launch time (SxS)

| Symptom | When | Meaning |
|---------|------|---------|
| SxS / side-by-side configuration incorrect | Running `.exe` | Windows rejected the **embedded application manifest** or sparse identity binding **before** `main` / WinUI starts |

SxS **after** successful registration is **not** “register again.” That loop wasted time.

Possible causes still in play (not all proven on the current built exe):

1. Embedded `<msix>` used wrong xmlns (`asm.v3` vs required `urn:schemas-microsoft-com:msix.v1`) — fixed in **source** `metadata/winui3-sparse/vala.win32.winui3.manifest`; must be **verified inside the built exe** with `mt.exe -inputresource:exe;#1`.
2. `ExternalLocation` at register time must match where you run the exe: **`C:\msys64\tmp\vala.win32\build-win`** (agent rsync path — do not use Samba `X:`).
3. MinGW default manifest conflicting with embedded manifest — mitigated by post-link `embed-winui3-manifest.sh`; still worth confirming only one manifest resource in the PE.
4. Other assembly dependency (CRT, common controls) — needs **`sxstrace.exe`**, not another guess.

### C — Launch time (bootstrap, after `package identity OK`)

| HRESULT | Symptom | Fix | Where |
|---------|---------|-----|-------|
| `0x80070032` (`ERROR_NOT_SUPPORTED`) | Log: `MddBootstrapInitialize2 failed` right after `package identity OK` | Microsoft docs suggest **`OnPackageIdentity_NOOP`**; we **reverted that** because it passed bootstrap but **`Application::Start` failed `0x80040154`** without runtime in the package graph. Current host uses **`MddBootstrapInitializeOptions_None`** (`f9bad4e`). | `src/win32-ui-winui3-host.cpp` |

**Do not toggle bootstrap options and `PackageDependency` in the same debugging pass** — they interact and caused circular “fixes.”

---

## `AppxManifest.xml` — knobs we toggled (read before editing)

This file is **not** a generic WinUI template. Only certain fields are proven for **this** sparse flow.

| Field | Current value (forward port) | Notes |
|-------|------------------------------|-------|
| `IgnorableNamespaces` | `uap rescap` only | **`uap10` must stay out** — `uap uap10 rescap` breaks `AllowExternalContent` indexing → **`0x80073D2E`** |
| `ProcessorArchitecture` | **`x64`** (`f9bad4e` baseline) | `d801516` tried `neutral`; not re-applied — retest register with signing + ignorable fix first |
| `uap10:AllowExternalContent` | `true` | — |
| `<PackageDependency Microsoft.WindowsAppRuntime.2>` | **Present** (`MinVersion="8002.1.3.0"`, `f9bad4e`) | Removing it + `OnPackageIdentity_NOOP` caused `0x80040154`. If register fails with dependency present, fix **`0x80073D2E`** via ignorable/signing — not by deleting dependency as first move |

Embedded exe manifest (`vala.win32.winui3.manifest`) is separate: needs `xmlns="urn:schemas-microsoft-com:msix.v1"` (not `asm.v3`).

**Official sparse identity shape:** [Grant package identity by packaging with external location](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps) — our manifest matches that sample (no `PackageDependency` in the sample).

**Runtime for sparse/unpackaged:** [Deploy unpackaged / external location](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/deploy-unpackaged-apps) — bootstrap API + installed `Microsoft.WindowsAppRuntime.2` on the machine (checked by `install-winui3-runtime.sh` / `winui3-runtime-gate.sh`).

---

## Timeline (why it felt circular)

Rough order of what we tried and what actually changed:

1. **Runtime / theme errors** (`themeresources.xaml`, `themed=0`) → led to sparse package identity work (correct direction for WinUI3 unpackaged).
2. **SxS at launch** → blamed missing sparse register → user still SxS after register worked.
3. **Dual manifest** (MinGW + custom) → `mt.exe` embed after link → build OK, **SxS persisted**.
4. **Build reordering** (sparse before compile) → infrastructure improvement, **did not fix SxS**.
5. **`0x80073D2E` at register** → manifest + cert fixes → **registration actually fixed**.
6. **Agent manual steps** → `agent-remote-winui3-setup.ps1` over SSH → **register automated**.
7. **`msix.v1` namespace** in embedded manifest → verified in built exe (`agent-extracted.manifest`).
8. **`0x80070032` bootstrap** → tried **`OnPackageIdentity_NOOP`** (`d801516`); passed bootstrap, broke **`Application::Start` (`0x80040154`)** — **not kept** in forward port.
9. **`PackageDependency` / arch / ignorable** → toggled in circles — forward port keeps **`f9bad4e` identity + dependency**, only drops `uap10` from ignorable namespaces, adds signing and `msix.v1`.

Each step was often presented as “the fix.” Build pipeline, `msix.v1`, MinGW DLL copy, and agent workflow are **ported forward**. **Full interactive UI launch** is still open on the `f9bad4e` bootstrap path.

---

## What validation checks (and misses)

`scripts/validate-winui3-build-win.sh` checks:

- PE / embedded `<msix>` / package name match
- Sparse MSIX present and signed
- `Get-AppxPackage vala.win32.WinUI3` returns a package (from the environment running validate)

It does **not**:

- Launch the exe
- Confirm `xmlns="urn:schemas-microsoft-com:msix.v1"` inside the **built** exe (check added in script; must pass on rebuilt binaries)
- Confirm `ExternalLocation` matches where the user runs the exe
- Confirm interactive desktop session vs SSH session user parity

---

## Proof criteria before claiming “fixed” again

Do not close the WinUI3 launch issue until **all** of:

1. **Extract manifest from built exe** (on Windows):

   ```cmd
   mt.exe -nologo -inputresource:winui3-widgets-native.exe;#1 -out:extracted.manifest
   ```

   Confirm `urn:schemas-microsoft-com:msix.v1` and matching `publisher` / `packageName` / `applicationId`.

2. **Register** (agent or `agent-remote-winui3-setup.ps1`) with `ExternalLocation` = directory containing the exe.

3. **Launch** `winui3-widgets-native.exe` from that same directory — no SxS.

4. **`winui3-debug.log`** shows `package identity OK` and ideally `themed=1` (or at least past `XamlControlsResources`).

If step 3 still fails: run **`sxstrace.exe Trace`**, launch once, **`sxstrace.exe Parse`** — fix what the trace names, not the next manifest guess.

---

## Agent workflow (current)

From Linux:

```bash
./scripts/agent-remote-build.sh build   # sync, build, SSH cert+register, pull, tail logs
./scripts/agent-remote-build.sh setup   # register only
./scripts/agent-remote-build.sh pull    # logs after local run
```

Logs:

| File | Purpose |
|------|---------|
| `build-win/last-build.log` | Compile / vendor |
| `build-win/agent-winui3-setup.log` | SSH cert + `Add-AppxPackage` |
| `build-win/WINUI3-VALIDATION.txt` | Pre-run checks (not launch proof) |
| `build-win/winui3-debug.log` | Runtime (only if exe starts) |

**Do not ask the user to run `certutil` / `Add-AppxPackage` if agent setup succeeded** — see `agent-winui3-setup.log`.

SSH demo run (`agent-remote-winui3-run.ps1`) may still SxS (non-interactive session). **Local interactive run is the real test** until launch works.

---

## Key files

| File | Role |
|------|------|
| `metadata/winui3-sparse/AppxManifest.xml` | Sparse MSIX identity |
| `metadata/winui3-sparse/vala.win32.winui3.manifest` | Embedded in exe (`msix.v1`) |
| `scripts/embed-winui3-manifest.sh` | Post-link `mt.exe` embed |
| `scripts/sign-winui3-sparse.sh` | Dev cert + MSIX sign (`CERT_FORMAT` bump regens cert) |
| `scripts/agent-remote-winui3-setup.ps1` | SSH register |
| `src/win32-ui-winui3-host.cpp` | Bootstrap, optional first-run register + relaunch |

---

## For agents / future sessions

1. **[windows-winui3-method.md](windows-winui3-method.md) first** — diff `f9bad4e`, read logs, no guessing.
2. Then this file for HRESULT layer (A register / B SxS / C bootstrap / D start).
3. Update [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) before and after every edit.
4. Do not mark WinUI3 working without current log proof on a freshly linked `.exe`.

---

## Related

- [windows-winui3-method.md](windows-winui3-method.md) — mandatory debugging process
- [windows-winui3.md](windows-winui3.md) — setup commands
- [windows-build.md](windows-build.md) — MSYS2 / agent rsync
- Plan: [11. phase 9 winui3](plans/11.%20phase%209%20winui3%20winmd%20hand%20binding.md)
