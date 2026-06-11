# WinUI3 on Windows (vala.win32)

WinUI3 demos (`winui3-widgets-native.exe`, `winui3-hello-native.exe`) are built by the agent or `build-win.sh`.

**Debugging (mandatory):** [windows-winui3-method.md](windows-winui3-method.md) — diff vs `f9bad4e`, read logs, no guessing.

**Changelog:** [WINUI3-CHANGELOG.md](WINUI3-CHANGELOG.md) — append after every change.

**HRESULT / symptoms:** [windows-winui3-status.md](windows-winui3-status.md)

General Windows build (rsync `C:` mirror, MSYS2, WebView2): [windows-build.md](windows-build.md).

---

## After each agent build

**`build-win/YOUR-TASKS.txt`** — what to do next (usually: run the exe locally).

```bash
./scripts/agent-remote-build.sh build   # sync, build, SSH cert+register, pull logs
./scripts/agent-remote-build.sh pull    # refresh logs after a local run
```

Pre-run checks (no GUI): `./scripts/agent-remote-build.sh validate` → `WINUI3-VALIDATION.txt`.

**Note:** Validation can say READY while the exe still fails SxS at launch. See [status doc](windows-winui3-status.md).

---

## Paths

**Repo + `build-win` on Windows (rsync mirror):** `C:\msys64\tmp\vala.win32\` — synced from Linux via `./scripts/agent-remote-build.sh`.

Run exes from **`C:\msys64\tmp\vala.win32\build-win\`**. `ExternalLocation` at register time must be that same folder (agent setup does this automatically).

---

## Setup (agent vs manual)

### Agent (default)

`./scripts/agent-remote-build.sh build` runs `scripts/agent-remote-winui3-setup.ps1` on Windows over SSH:

- Trust dev cert (`TrustedPeople` / `Root`)
- `Add-AppxPackage` with `-ExternalLocation` = `build-win`

Check `build-win/agent-winui3-setup.log`. **Do not re-run manual cert/register if that log shows OK.**

### Manual (non-agent or setup failed)

**cmd** — trust cert:

```cmd
certutil -delstore -user TrustedPeople "vala.win32"
certutil -delstore -user Root "vala.win32"
certutil -addstore -user TrustedPeople C:\msys64\tmp\vala.win32\build-win\vala.win32.sparse.cer
certutil -addstore -user Root C:\msys64\tmp\vala.win32\build-win\vala.win32.sparse.cer
```

**PowerShell** — register:

```powershell
Get-AppxPackage vala.win32.WinUI3 -ErrorAction SilentlyContinue | Remove-AppxPackage
Add-AppxPackage -Path 'C:\msys64\tmp\vala.win32\build-win\vala.win32.winui3.sparse.msix' -ExternalLocation 'C:\msys64\tmp\vala.win32\build-win' -ForceUpdateFromAnyVersion
```

### Run

```text
C:\msys64\tmp\vala.win32\build-win\winui3-widgets-native.exe
```

Log: `build-win\winui3-debug.log` (only written if the process starts).

---

## Symptoms (registration vs launch)

| Symptom | Layer | See |
|---------|-------|-----|
| `Add-AppxPackage` **0x800B0109** | Registration | Trust new `.cer` after rebuild |
| `Add-AppxPackage` **0x80073D2E** | Registration | [status doc](windows-winui3-status.md) § A |
| **SxS** at exe launch | Launch | [status doc](windows-winui3-status.md) § B — **not** “register again” if register already OK |
| **`0x80070032`** after `package identity OK` | Bootstrap | [status doc](windows-winui3-status.md) § C — `OnPackageIdentity_NOOP` in host, **not** `PackageDependency` in sparse MSIX |
| Labels only, `themed=0` | Runtime | Needs package identity; blocked until launch works |

---

## Agent subcommands

| Command | Action |
|---------|--------|
| `build` | Full cycle (default) |
| `setup` | SSH cert + register only |
| `run` | Setup + headless demo attempt + pull |
| `pull` | Pull `build-win/` |
| `validate` | Checks only |

---

## Build scripts (reference)

- `install-winui3-runtime.sh` — Windows App SDK runtime
- `vendor-winui3-sparse.sh` — pack/sign sparse MSIX
- `embed-winui3-manifest.sh` — `mt.exe` embed after link
- `sign-winui3-sparse.sh` — dev cert (`CERT_FORMAT` bump regens cert)

---

## Related

- [windows-winui3-status.md](windows-winui3-status.md) — **timeline, proof criteria, anti-loop guide**
- [windows-build.md](windows-build.md) — MSYS2, rsync, `build-win.sh`
- [11. phase 9 winui3](plans/11.%20phase%209%20winui3%20winmd%20hand%20binding.md)
