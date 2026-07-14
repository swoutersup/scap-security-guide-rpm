#!/usr/bin/env bash
# Mimics the AlmaLinux RPM %prep + cmake pipeline locally.
# Usage: ./local-build.sh [almalinux9|almalinux10] [git-repo-url-or-local-path]
#
# Defaults: product=almalinux10, repo=https://github.com/swoutersup/ComplianceAsCode-content
#
# Produces: <workdir>/build/ssg-<product>-ds.xml

set -euo pipefail

PRODUCT="${1:-almalinux10}"
CONTENT_SRC="${2:-https://github.com/swoutersup/ComplianceAsCode-content}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(pwd)/work-${PRODUCT}"

if [[ "${PRODUCT}" != "almalinux9" && "${PRODUCT}" != "almalinux10" ]]; then
  echo "ERROR: product must be almalinux9 or almalinux10" >&2
  exit 1
fi

SUPPORT_SCRIPT="${SCRIPT_DIR}/add-${PRODUCT}-support.sh"

if [[ ! -f "${SUPPORT_SCRIPT}" ]]; then
  echo "ERROR: support script not found: ${SUPPORT_SCRIPT}" >&2
  exit 1
fi

rm -rf "${WORK_DIR}"

if [[ "${CONTENT_SRC}" == http* || "${CONTENT_SRC}" == git@* ]]; then
  echo "==> Cloning ${CONTENT_SRC} to ${WORK_DIR}"
  git clone --depth=1 "${CONTENT_SRC}" "${WORK_DIR}"
else
  echo "==> Copying ${CONTENT_SRC} to ${WORK_DIR}"
  cp -r "${CONTENT_SRC}" "${WORK_DIR}"
fi

cd "${WORK_DIR}"

echo "==> Applying patches (%autosetup -p1)"
for PATCH in "${SCRIPT_DIR}"/*.patch; do
  [[ -f "${PATCH}" ]] || continue
  echo "    Applying $(basename "${PATCH}")"
  patch -p1 --forward --silent < "${PATCH}" || {
    echo "WARNING: patch $(basename "${PATCH}") already applied or failed — continuing"
  }
done

echo "==> Running ${SUPPORT_SCRIPT}"
bash "${SUPPORT_SCRIPT}"

echo "==> Building ssg-${PRODUCT}-ds.xml"
./build_product "${PRODUCT}" --datastream

echo ""
echo "==> Done. Datastream at:"
echo "    ${WORK_DIR}/build/ssg-${PRODUCT}-ds.xml"
