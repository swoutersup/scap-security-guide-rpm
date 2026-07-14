#!/usr/bin/env bash
# Mimics the AlmaLinux RPM %prep + cmake pipeline locally.
# Usage: ./local-build.sh <path-to-ComplianceAsCode-source> [almalinux9|almalinux10]
#
# Produces: <workdir>/build/ssg-<product>-ds.xml
# The ComplianceAsCode source tree is NOT modified.

set -euo pipefail

CONTENT_SRC="${1:?Usage: $0 <path-to-ComplianceAsCode-source> [almalinux9|almalinux10]}"
PRODUCT="${2:-almalinux10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(pwd)/work-${PRODUCT}"

if [[ "${PRODUCT}" != "almalinux9" && "${PRODUCT}" != "almalinux10" ]]; then
  echo "ERROR: product must be almalinux9 or almalinux10" >&2
  exit 1
fi

MAJOR="${PRODUCT//almalinux/}"  # "9" or "10"
SUPPORT_SCRIPT="${SCRIPT_DIR}/add-${PRODUCT}-support.sh"

if [[ ! -f "${SUPPORT_SCRIPT}" ]]; then
  echo "ERROR: support script not found: ${SUPPORT_SCRIPT}" >&2
  exit 1
fi

echo "==> Copying ComplianceAsCode source to ${WORK_DIR}"
rm -rf "${WORK_DIR}"
cp -r "${CONTENT_SRC}" "${WORK_DIR}"
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
