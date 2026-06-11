# WinUI3 debugging method — do not guess

**Mandatory for agents and humans.** If hello/WinUI3 is broken, follow this **before** editing manifests, bootstrap options, or register scripts.

**Incremental restore:** [windows-winui3-restore-layers.md](windows-winui3-restore-layers.md) — default `WINUI3_LAYER=hello` (`cf233c0`); add `d6ac214` / `f9bad4e` only after proof.

**Do not:**
- Toggle `PackageDependency`, `ProcessorArchitecture`, `OnPackageIdentity_NOOP`, or `msix.v1` because a blog post or prior chat said so
- Infer repo state from conversation memory
- Apply fixes from commit `d801516` wholesale (that commit is **known broken**)
- Claim WinUI3 works without log proof on the **current** built `.exe`

**Do:**
- Diff against the known-good commit
- Read pulled logs on disk
- Match log strings to source at a specific commit
- Change **one layer** at a time; append [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md)

Symptom tables (HRESULT layers): [windows-winui3-status.md](windows-winui3-status.md)  
File-level history: [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md)

---

## 1. Anchor — what actually worked

| Item | Value |
|------|--------|
| Git commit | **`f9bad4e`** — *winui3 is partly working - working on buttons and text entry* |
| Proven behavior | `winui3-hello-native.exe` showed a **window with TextBlock labels** (`themed=0`) |
| Not working at anchor | TextBox / Button / `themed=1` |
| Known broken commit | **`d801516`** — do not re-apply its host/manifest toggles without new evidence |

### When sparse identity was introduced (git history)

**Yes — hello worked first, without sparse.** Sparse landed later, in the same commit as the “labels window” baseline.

| Commit | Date | Sparse? | Notes |
|--------|------|---------|--------|
| **`cf233c0`** | 2026-06-09 | **No** | *helo world from winui 3* — bootstrap only (`MddBootstrapInitializeOptions_None`), no `metadata/winui3-sparse/`, no embedded `<msix>`, no `winui3_ensure_package_identity()` |
| **`d6ac214`** | 2026-06-10 AM | **No** | *baby steps on winui* — widgets host work; still no sparse files |
| **`f9bad4e`** | 2026-06-10 PM | **Yes** | *partly working* — **introduces** `metadata/winui3-sparse/*`, `embed-winui3-manifest.sh`, `vendor/register-winui3-sparse.sh`, embedded `<msix>` manifest, `winui3_ensure_package_identity()` (+279 lines in host) |

So sparse was added **after** first hello, to support unpackaged WinUI3 / themed controls (see status doc timeline: theme errors → sparse identity). The known-good **labels window** at `f9bad4e` already **depends on** sparse register + embedded manifest — it is not the same code path as `cf233c0` plain hello.

---

## 2. Diff — what changed since it worked

Run on the Linux git host:

```bash
cd /path/to/vala.win32

# Launch-critical sources only
git diff f9bad4e -- \
  src/win32-ui-winui3-host.cpp \
  metadata/winui3-sparse/AppxManifest.xml \
  metadata/winui3-sparse/vala.win32.winui3.manifest \
  scripts/embed-winui3-manifest.sh

# Infrastructure (build/agent — usually not launch regressions)
git diff f9bad4e --stat -- scripts/ meson.build docs/
```

**Rule:** If a file has **no diff** vs `f9bad4e`, do not blame that file for a new regression until you prove the **built binary** on Windows matches source (see §3).

### Launch-critical files at `f9bad4e` (frozen unless log proof says otherwise)

| File | Shape at anchor |
|------|-----------------|
| `src/win32-ui-winui3-host.cpp` | `MddBootstrapInitializeOptions_None`; log: `bootstrap OK (SDK 0x… tag …)` |
| `vala.win32.winui3.manifest` | Embedded `<msix xmlns="urn:schemas-microsoft-com:asm.v3">` with child elements |
| `AppxManifest.xml` | `ProcessorArchitecture="x64"`, `<PackageDependency Microsoft.WindowsAppRuntime.2>`, `uap10:AllowExternalContent` |

**Only intentional delta in working tree (2026-06-11):** `IgnorableNamespaces="uap rescap"` (drop `uap10`) — tied to `0x80073D2E` at register time. Everything else in those three files should match `f9bad4e` unless changelog says otherwise.

---

## 3. Runtime proof — logs beat theory

After `./scripts/agent-remote-build.sh build` or `pull`, read on Linux:

| Log | Purpose |
|-----|---------|
| `build-win/winui3-debug.log` | Bootstrap, `Application::Start`, HRESULT |
| `build-win/agent-winui3-setup.log` | Cert + `Add-AppxPackage` |
| `build-win/last-build.log` | Compile, sign, register during build |
| `build-win/WINUI3-VALIDATION.txt` | Pre-run checks (**not** launch proof) |

### Log string forensics (example)

| Log line | Implies |
|----------|---------|
| `bootstrap OK (sparse identity; bootstrap noop)` | Binary linked from **`d801516` host** — grep: `git show d801516:src/win32-ui-winui3-host.cpp` |
| `bootstrap OK (SDK 0x… tag …)` | Binary matches **`f9bad4e` host** — grep: `git show f9bad4e:src/win32-ui-winui3-host.cpp` |
| `0x80040154` Class not registered after noop bootstrap | Documented **`d801516`** failure — fix stale binary first, not manifest |
| `0x80073D2E` at `Add-AppxPackage` | Register layer — see status doc §A; check ignorable namespaces, signing, path |
| `sparse register failed (exit 1)` | Package not registered; exe may report stale identity |

If log text **does not exist in current source**, the problem is **stale `C:\msys64\tmp\vala-win32-build-win\` objects** or an old `.exe` in `build-win/`, not a new manifest guess. Agent build runs `ninja -t clean` on WinUI3 exes when `AGENT_REMOTE_BUILD=1`.

### Prove binary matches source

On Windows (or from validate output):

```bash
# Embedded manifest must match metadata/winui3-sparse/vala.win32.winui3.manifest
./scripts/agent-remote-build.sh validate
```

Build log must show **compile/link** of `winui3-hello-native`, not only `[1/1] Generating winui3-*-embed-manifest`.

---

## 4. Change one layer at a time

| Layer | Symptom | Touch only |
|-------|---------|------------|
| A — Register | `0x80073D2E`, `0x800B0100` at `Add-AppxPackage` | `AppxManifest.xml`, signing, cert trust |
| B — SxS | Side-by-side before `main` | Embedded `vala.win32.winui3.manifest`, sparse register, `ExternalLocation` path |
| C — Bootstrap | `0x80070032` after `package identity OK` | `win32-ui-winui3-host.cpp` bootstrap options |
| D — WinUI start | `0x80040154` after bootstrap | Bootstrap + runtime packages + **prove binary is not `d801516`** |
| E — Controls | `themed=1` / TextBox | XAML resources — **after** hello window works |

**Before each edit:** append to [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) with intent, files, and expected log change.

**After each edit:** `./scripts/agent-remote-build.sh build`, re-read logs, update changelog verification row.

---

## 5. Rejected without `f9bad4e` anchor (do not re-apply casually)

From commit `d801516` — failed even when register succeeded:

| Change | Observed failure |
|--------|------------------|
| `MddBootstrapInitializeOptions_OnPackageIdentity_NOOP` | `0x80040154` at `Application::Start` |
| Remove `<PackageDependency>` from sparse MSIX + noop bootstrap | Same |
| `ProcessorArchitecture="neutral"` | Not proven for hello at `f9bad4e`; only re-test with changelog entry |

Re-applying any of these requires: diff note, single-layer test, log HRESULT recorded in changelog.

---

## 6. Canonical paths (no Samba)

| Role | Path |
|------|------|
| Windows repo | `C:\msys64\tmp\vala.win32\` |
| Meson objects | `C:\msys64\tmp\vala-win32-build-win\` |
| Run exes | `C:\msys64\tmp\vala.win32\build-win\` |
| Agent sync | `./scripts/agent-remote-build.sh` from Linux |

`ExternalLocation` at register must equal the folder containing the `.exe`.

---

## Quick checklist (agents)

1. [ ] Read [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) Unreleased section
2. [ ] `git diff f9bad4e --` launch-critical files
3. [ ] Read `build-win/winui3-debug.log` — match strings to `git show f9bad4e` / `d801516` host
4. [ ] Confirm build log shows relink, not embed-only
5. [ ] One layer, one change, changelog updated
6. [ ] Do not ask user to paste logs if `agent-remote-build.sh pull` succeeded
