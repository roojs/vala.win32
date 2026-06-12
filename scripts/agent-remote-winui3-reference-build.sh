#!/usr/bin/env bash
# Build ~/git/winui3-without-xaml on snappr-win (actual sample + MSVC + self-contained).
#
#   ./scripts/agent-remote-winui3-reference-build.sh
#
# Run on Windows after build:
#   C:\msys64\tmp\winui3-without-xaml\x64\Release\winui3-without-xaml.exe
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${AGENT_WIN_HOST:-snappr-win}"
GIT_ROOT="${WINUI3_GIT_ROOT:-/home/alan/git}"
SRC="${GIT_ROOT}/winui3-without-xaml/"
REMOTE_WIN='C:\msys64\tmp\winui3-without-xaml'
REMOTE_DIR="/c/msys64/tmp/winui3-without-xaml"
RSYNC_SSH=(ssh -o BatchMode=yes)
RSYNC_PATH=(--rsync-path='C:/msys64/usr/bin/rsync')
RSYNC_EXCLUDES=(--exclude '.git/' --exclude '**/x64/' --exclude '**/Debug/' --exclude '**/Release/' --exclude '**/packages/')

[[ -d "${SRC}" ]] || { echo "missing ${SRC} — clone sotanakamura/winui3-without-xaml to ~/git" >&2; exit 1; }

echo "[reference] rsync sample -> ${REMOTE_HOST}:${REMOTE_DIR}/"
rsync -avz "${RSYNC_EXCLUDES[@]}" -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
	"${SRC}" "${REMOTE_HOST}:${REMOTE_DIR}/"

echo "[reference] apply patches (WinApp SDK 1.5, v145, Release|x64, diag main.cpp)"
for f in packages.config winui3-without-xaml.vcxproj main.cpp; do
	rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
		"${ROOT}/winui3/patches/${f}" \
		"${REMOTE_HOST}:${REMOTE_DIR}/${f}"
done

rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
	"${ROOT}/scripts/agent-remote-winui3-reference-build.ps1" \
	"${REMOTE_HOST}:/c/msys64/tmp/vala.win32/scripts/"

ssh -o BatchMode=yes "${REMOTE_HOST}" \
	'powershell.exe -NoProfile -Command "Remove-Item -Recurse -Force C:\msys64\tmp\winui3-without-xaml\packages,C:\msys64\tmp\winui3-without-xaml\x64 -ErrorAction SilentlyContinue"'

for ps in agent-remote-winui3-reference-stage.ps1 agent-remote-winui3-reference-probe.ps1; do
	rsync -avz -e "${RSYNC_SSH[*]}" "${RSYNC_PATH[@]}" \
		"${ROOT}/scripts/${ps}" \
		"${REMOTE_HOST}:/c/msys64/tmp/vala.win32/scripts/"
done

echo "[reference] MSBuild (upstream main.cpp, WindowsAppSDKSelfContained)"
ssh -o BatchMode=yes "${REMOTE_HOST}" \
	"powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\\msys64\\tmp\\vala.win32\\scripts\\agent-remote-winui3-reference-build.ps1 -ProjectDir \"${REMOTE_WIN}\" -Solution winui3-without-xaml.sln -ExeRel x64\\Release\\winui3-without-xaml.exe"

echo "[reference] stage self-contained DLLs beside exe"
ssh -o BatchMode=yes "${REMOTE_HOST}" \
	"powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\\msys64\\tmp\\vala.win32\\scripts\\agent-remote-winui3-reference-stage.ps1 -ReleaseDir \"${REMOTE_WIN}\\x64\\Release\""

echo "[reference] probe layout + run (writes reference-probe.log)"
ssh -o BatchMode=yes "${REMOTE_HOST}" \
	"powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\\msys64\\tmp\\vala.win32\\scripts\\agent-remote-winui3-reference-probe.ps1 -ReleaseDir \"${REMOTE_WIN}\\x64\\Release\""

cat <<EOF

Sample built (diag main.cpp + self-contained deploy).
Run on Windows — click button should say "Thank You!":

  ${REMOTE_WIN}\\x64\\Release\\winui3-without-xaml.exe

If the window still does not appear, open:

  ${REMOTE_WIN}\\x64\\Release\\winui3-without-xaml-run.log

(Exe must run from Release/; needs resources.pri beside it.)
EOF
