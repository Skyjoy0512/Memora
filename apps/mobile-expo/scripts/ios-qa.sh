#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_ROOT="${SCRIPT_DIR:h}"
ACTION="${1:-build-for-testing}"
DERIVED_DATA_PATH="${MEMORA_RN_DERIVED_DATA_PATH:-${APP_ROOT}/.expo/ios-qa-derived-data}"
DESTINATION="${MEMORA_RN_DESTINATION:-generic/platform=iOS Simulator}"
ARCHS_VALUE="${MEMORA_RN_ARCHS:-arm64}"

if [[ ("${ACTION}" == "test" || "${ACTION}" == "test-without-building") && "${DESTINATION}" == generic/* ]]; then
  echo "MEMORA_RN_DESTINATION must name a concrete simulator for test actions." >&2
  echo "Example: platform=iOS Simulator,name=Memora RN Test,OS=26.5" >&2
  exit 64
fi

echo "Memora RN QA"
echo "  action: ${ACTION}"
echo "  destination: ${DESTINATION}"
echo "  derived data: ${DERIVED_DATA_PATH}"
echo "  architectures: ${ARCHS_VALUE}"

cd "${APP_ROOT}"

xcodebuild \
  -workspace ios/MemoraRN.xcworkspace \
  -scheme MemoraRN \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -quiet \
  ARCHS="${ARCHS_VALUE}" \
  ONLY_ACTIVE_ARCH=YES \
  "${ACTION}"
