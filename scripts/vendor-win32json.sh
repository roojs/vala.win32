#!/usr/bin/env bash
# Clone marlersoft/win32json into build/vendor; copy api/*.json listed in
# metadata/win32json-api.files → metadata/win32json/api/
#
# Upstream: https://github.com/marlersoft/win32json
# File api/UI.Foo.json  ==  namespace Windows.Win32.UI.Foo
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE_LIST="${ROOT}/metadata/win32json-api.files"
REPO_URL="${WIN32JSON_REPO:-https://github.com/marlersoft/win32json.git}"
REF_FILE="${ROOT}/metadata/win32json-ref.txt"
if [[ -z "${WIN32JSON_REF:-}" && -f "${REF_FILE}" ]]; then
	WIN32JSON_REF="$(grep -v '^#' "${REF_FILE}" | grep -v '^[[:space:]]*$' | head -1)"
fi
REPO_REF="${WIN32JSON_REF:-main}"
CLONE_DIR="${ROOT}/build/vendor/win32json"
OUT_DIR="${ROOT}/metadata/win32json"
OUT_API="${OUT_DIR}/api"

if [[ ! -f "${FILE_LIST}" ]]; then
	echo "missing file list: ${FILE_LIST}" >&2
	exit 1
fi

if [[ -d "${CLONE_DIR}/.git" ]]; then
	echo "Updating ${CLONE_DIR} (${REPO_REF}) ..."
	git -C "${CLONE_DIR}" fetch --depth 1 origin "${REPO_REF}" 2>/dev/null || git -C "${CLONE_DIR}" fetch origin
	git -C "${CLONE_DIR}" checkout -q "${REPO_REF}" 2>/dev/null || git -C "${CLONE_DIR}" checkout -q "origin/${REPO_REF}"
else
	mkdir -p "$(dirname "${CLONE_DIR}")"
	echo "Cloning ${REPO_URL} -> ${CLONE_DIR} (ref ${REPO_REF}) ..."
	git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${CLONE_DIR}" 2>/dev/null \
		|| git clone --depth 1 "${REPO_URL}" "${CLONE_DIR}"
	if [[ "${REPO_REF}" != "main" ]]; then
		git -C "${CLONE_DIR}" checkout -q "${REPO_REF}"
	fi
fi

mkdir -p "${OUT_API}"
rm -f "${OUT_API}"/*.json

copied=0
missing=0
while IFS= read -r line || [[ -n "${line}" ]]; do
	line="${line%%#*}"
	line="${line#"${line%%[![:space:]]*}"}"
	line="${line%"${line##*[![:space:]]}"}"
	[[ -z "${line}" ]] && continue
	src="${CLONE_DIR}/api/${line}"
	if [[ ! -f "${src}" ]]; then
		echo "missing upstream: api/${line}" >&2
		missing=$((missing + 1))
		continue
	fi
	cp -- "${src}" "${OUT_API}/${line}"
	copied=$((copied + 1))
done < "${FILE_LIST}"

if [[ -f "${CLONE_DIR}/version.txt" ]]; then
	cp -- "${CLONE_DIR}/version.txt" "${OUT_DIR}/version.txt"
fi

if [[ "${missing}" -gt 0 ]]; then
	echo "win32json: ${missing} listed file(s) not found in ${CLONE_DIR}/api" >&2
	exit 1
fi

echo "win32json: copied ${copied} api file(s) to ${OUT_API}"
echo "  upstream: ${CLONE_DIR} @ $(git -C "${CLONE_DIR}" rev-parse --short HEAD 2>/dev/null || echo '?')"
