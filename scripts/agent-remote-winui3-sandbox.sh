#!/usr/bin/env bash
# Sync winui3/ sandbox; MSVC build + run on snappr-win (primary path).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${AGENT_WIN_HOST:-snappr-win}"
REMOTE_ROOT="/c/msys64/tmp/vala.win32"
RSYNC_SSH=(ssh -o BatchMode=yes)
RSYNC_PATH=(--rsync-path='C:/msys64/usr/bin/rsync')

rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
	"${ROOT}/winui3/" "${REMOTE_HOST}:${REMOTE_ROOT}/winui3/"
rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
	"${ROOT}/scripts/agent-remote-winui3-sandbox-run.ps1" \
	"${REMOTE_HOST}:${REMOTE_ROOT}/scripts/"

echo "[sandbox] MSVC build (primary)"
ssh -o BatchMode=yes "${REMOTE_HOST}" \
	'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\msys64\tmp\vala.win32\winui3\build-msvc.ps1'

echo "[sandbox] MSVC run (bounded)"
ssh -o BatchMode=yes "${REMOTE_HOST}" \
	'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\msys64\tmp\vala.win32\scripts\agent-remote-winui3-sandbox-run.ps1 -ExeName winui3-sandbox.exe' \
	|| true

echo "[sandbox] pull log"
mkdir -p "${ROOT}/build-win"
rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
	"${REMOTE_HOST}:${REMOTE_ROOT}/winui3/winui3-sandbox.log" \
	"${ROOT}/build-win/winui3-sandbox.log" 2>/dev/null || true

cat "${ROOT}/build-win/winui3-sandbox.log" 2>/dev/null || true
