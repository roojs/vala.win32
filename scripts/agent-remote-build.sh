#!/usr/bin/env bash
# Agent workflow: rsync Linux → Windows C:, build, pull logs back to Linux build-win/.
#
# WinUI3 is off by default (BUILD_WINUI3=1 to re-enable). See README.md.
#
#   ./scripts/agent-remote-build.sh          # sync + build + SSH setup + demo + pull
#   ./scripts/agent-remote-build.sh setup    # SSH cert trust + sparse register only
#   ./scripts/agent-remote-build.sh run      # SSH setup + run demo + pull log
#   ./scripts/agent-remote-build.sh pull     # pull build-win/ artifacts
#   ./scripts/agent-remote-build.sh validate # pre-run checks only (on Windows)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${AGENT_WIN_HOST:-snappr-win}"
# hello = cf233c0 baseline; sparse = f9bad4e (see docs/windows-winui3-restore-layers.md)
AGENT_WINUI3_LAYER="${AGENT_WINUI3_LAYER:-hello}"
REMOTE_ROOT="/c/msys64/tmp/vala.win32"
REMOTE_BUILD_WIN="${REMOTE_ROOT}/build-win"
BUILD_WINUI3="${BUILD_WINUI3:-0}"
RSYNC_SSH=(ssh -o BatchMode=yes)
RSYNC_PATH=(--rsync-path='C:/msys64/usr/bin/rsync')

RSYNC_EXCLUDES=(
	--exclude 'build/'
	--exclude 'build-win/'
	--exclude '.git/'
	--exclude 'mingw-libs/'
	--exclude 'build-test/'
	--exclude '.specstory/'
	--exclude 'build/vendor/'
)

sync_to_windows() {
	echo "[agent-remote-build] rsync -> ${REMOTE_HOST}:${REMOTE_ROOT}/"
	# No --delete: avoids Windows rsync flakiness on large trees; stale files are rare.
	rsync -avz "${RSYNC_EXCLUDES[@]}" \
		-e "${RSYNC_SSH[*]}" \
		"${RSYNC_PATH[@]}" \
		"${ROOT}/" "${REMOTE_HOST}:${REMOTE_ROOT}/"
}

run_remote_build() {
	echo "[agent-remote-build] build on ${REMOTE_HOST} (C: mirror)"
	ssh -o BatchMode=yes "${REMOTE_HOST}" \
		"C:\\msys64\\msys2_shell.cmd -defterm -no-start -ucrt64 -c \"cd /c/msys64/tmp/vala.win32 && AGENT_REMOTE_BUILD=1 BUILD_WINUI3=${BUILD_WINUI3} WINUI3_LAYER=${AGENT_WINUI3_LAYER} WINUI3_SKIP_SPARSE_REGISTER=1 WINUI3_UNPACKAGED_WIDGETS=${WINUI3_UNPACKAGED_WIDGETS:-0} WINUI3_FORCE_RUNTIME_MSIX=${WINUI3_FORCE_RUNTIME_MSIX:-0} WINUI3_RUNTIME_REMOVE_NEWER=${WINUI3_RUNTIME_REMOVE_NEWER:-0} ./scripts/build-win.sh\""
}

run_remote_winui3_setup() {
	echo "[agent-remote-build] WinUI3 cert trust + sparse register on ${REMOTE_HOST}"
	local setup_rc=0
	ssh -o BatchMode=yes -o ConnectTimeout=15 "${REMOTE_HOST}" \
		'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\msys64\tmp\vala.win32\scripts\agent-remote-winui3-setup.ps1' \
		|| setup_rc=$?
	if [[ "${setup_rc}" -ne 0 ]]; then
		echo "[agent-remote-build] warning: sparse setup failed (rc=${setup_rc}); see build-win/agent-winui3-setup.log" >&2
	fi
	return "${setup_rc}"
}

run_remote_winui3_demo() {
	echo "[agent-remote-build] run WinUI3 demo (layer=${AGENT_WINUI3_LAYER}) on ${REMOTE_HOST}"
	local run_rc=0
	ssh -o BatchMode=yes -o ConnectTimeout=15 "${REMOTE_HOST}" \
		"powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"\$env:WINUI3_LAYER='${AGENT_WINUI3_LAYER}'; & 'C:\\msys64\\tmp\\vala.win32\\scripts\\agent-remote-winui3-run.ps1'\"" \
		|| run_rc=$?
	return "${run_rc}"
}

run_remote_validate() {
	echo "[agent-remote-build] validate on ${REMOTE_HOST}"
	ssh -o BatchMode=yes "${REMOTE_HOST}" \
		'C:\msys64\msys2_shell.cmd -defterm -no-start -ucrt64 -c "cd /c/msys64/tmp/vala.win32 && ./scripts/validate-winui3-build-win.sh"'
}

pull_artifacts() {
	mkdir -p "${ROOT}/build-win"
	echo "[agent-remote-build] pull build-win/ + logs <- ${REMOTE_HOST}"
	rsync -avz \
		-e "${RSYNC_SSH[*]}" \
		"${RSYNC_PATH[@]}" \
		"${REMOTE_HOST}:${REMOTE_BUILD_WIN}/" \
		"${ROOT}/build-win/"
}

print_user_tasks() {
	if [[ -f "${ROOT}/build-win/YOUR-TASKS.txt" ]]; then
		echo ""
		cat "${ROOT}/build-win/YOUR-TASKS.txt"
		echo ""
	fi
}

print_run_hint() {
	print_user_tasks
	if [[ "${BUILD_WINUI3}" == 1 ]]; then
		echo "(Agent details: build-win/WINUI3-VALIDATION.txt, build-win/last-build.log, build-win/agent-winui3-setup.log)"
	else
		echo "(WinUI3 disabled — see README.md. Log: build-win/last-build.log)"
	fi
}

cmd="${1:-build}"

case "${cmd}" in
	build)
		sync_to_windows
		build_rc=0
		run_remote_build || build_rc=$?
		setup_rc=0
		if [[ "${BUILD_WINUI3}" == 1 && "${build_rc}" -eq 0 && ( "${AGENT_WINUI3_LAYER}" == sparse || "${AGENT_WINUI3_LAYER}" == widgets ) ]]; then
			run_remote_winui3_setup || setup_rc=$?
		fi
		pull_artifacts || true
		if [[ "${BUILD_WINUI3}" == 1 && "${build_rc}" -eq 0 && "${setup_rc}" -eq 0 ]]; then
			run_remote_winui3_demo || true
			pull_artifacts || true
		fi
		print_run_hint
		if [[ -f "${ROOT}/build-win/winui3-debug.log" ]]; then
			echo "--- tail winui3-debug.log ---"
			tail -25 "${ROOT}/build-win/winui3-debug.log"
		fi
		exit "${build_rc}"
		;;
	setup)
		if [[ "${BUILD_WINUI3}" != 1 ]]; then
			echo "[agent-remote-build] WinUI3 disabled (BUILD_WINUI3=1 required)" >&2
			exit 1
		fi
		sync_to_windows
		setup_rc=0
		run_remote_winui3_setup || setup_rc=$?
		pull_artifacts || true
		exit "${setup_rc}"
		;;
	run)
		if [[ "${BUILD_WINUI3}" != 1 ]]; then
			echo "[agent-remote-build] WinUI3 disabled (BUILD_WINUI3=1 required)" >&2
			exit 1
		fi
		if [[ "${AGENT_WINUI3_LAYER}" == sparse || "${AGENT_WINUI3_LAYER}" == widgets ]]; then
			run_remote_winui3_setup || true
		fi
		run_rc=0
		run_remote_winui3_demo || run_rc=$?
		pull_artifacts || true
		if [[ -f "${ROOT}/build-win/winui3-debug.log" ]]; then
			echo "--- winui3-debug.log ---"
			tail -40 "${ROOT}/build-win/winui3-debug.log"
		fi
		exit "${run_rc}"
		;;
	pull)
		pull_artifacts
		print_run_hint
		if [[ -f "${ROOT}/build-win/last-build.log" ]]; then
			echo "--- tail last-build.log ---"
			tail -30 "${ROOT}/build-win/last-build.log"
		fi
		if [[ -f "${ROOT}/build-win/winui3-debug.log" ]]; then
			echo "--- tail winui3-debug.log ---"
			tail -20 "${ROOT}/build-win/winui3-debug.log"
		fi
		;;
	sync)
		sync_to_windows
		;;
	validate)
		sync_to_windows
		validate_rc=0
		run_remote_validate || validate_rc=$?
		pull_artifacts || true
		print_user_tasks
		exit "${validate_rc}"
		;;
	*)
		echo "usage: $0 [build|setup|run|pull|sync|validate]" >&2
		exit 1
		;;
esac
