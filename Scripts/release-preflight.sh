#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
simulator_name="${AWESOME_BUTTON_SIMULATOR_NAME:-iPhone 17 Pro}"
simulator_os="${AWESOME_BUTTON_SIMULATOR_OS:-}"
provided_artifacts="${AWESOME_BUTTON_ARTIFACTS_DIR:-}"

if [[ -n "$provided_artifacts" ]]; then
  if [[ "$provided_artifacts" != /* ]]; then
    echo "AWESOME_BUTTON_ARTIFACTS_DIR must be an absolute path." >&2
    exit 1
  fi
  artifacts_root="$provided_artifacts"
  mkdir -p "$artifacts_root"
  chmod 700 "$artifacts_root"
  clean_artifacts=false
else
  artifacts_root="$(mktemp -d "${TMPDIR:-/tmp}/awesome-button-swift-preflight.XXXXXX")"
  clean_artifacts=true
fi

for reserved_artifact in \
  SwiftAwesomeButton.xcresult \
  SwiftAwesomeButton-coverage.json \
  SwiftAwesomeButton-coverage.txt \
  SwiftAwesomeButton-package.json \
  test-derived-data \
  strict-swift5-derived-data \
  strict-swift6-derived-data \
  docc-derived-data; do
  if [[ -e "$artifacts_root/$reserved_artifact" ]]; then
    echo "Artifact destination must be empty before preflight: $artifacts_root/$reserved_artifact" >&2
    exit 1
  fi
done

cleanup() {
  if [[ "$clean_artifacts" == true ]]; then
    rm -rf "$artifacts_root"
  fi
}
trap cleanup EXIT

destination="platform=iOS Simulator,name=$simulator_name"
if [[ -n "$simulator_os" ]]; then
  destination="$destination,OS=$simulator_os"
fi

cd "$repository_root"

swift format lint --strict --recursive Sources Tests Package.swift

xcodebuild -quiet -scheme swift-awesome-button \
  -destination "$destination" \
  -enableCodeCoverage YES \
  -resultBundlePath "$artifacts_root/SwiftAwesomeButton.xcresult" \
  -derivedDataPath "$artifacts_root/test-derived-data" \
  test SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xccov view --report --json \
  "$artifacts_root/SwiftAwesomeButton.xcresult" \
  >"$artifacts_root/SwiftAwesomeButton-coverage.json"
xcrun xccov view --report \
  "$artifacts_root/SwiftAwesomeButton.xcresult" \
  >"$artifacts_root/SwiftAwesomeButton-coverage.txt"

xcodebuild -quiet -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$artifacts_root/strict-swift5-derived-data" \
  clean build \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild -quiet -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$artifacts_root/strict-swift6-derived-data" \
  clean build \
  SWIFT_VERSION=6 \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

Scripts/check-api-compatibility.sh
Scripts/test-api-compatibility-gate.sh

xcodebuild -quiet docbuild \
  -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$artifacts_root/docc-derived-data" \
  'OTHER_DOCC_FLAGS=$(inherited) --warnings-as-errors'

swift Scripts/check-public-documentation.swift \
  --derived-data "$artifacts_root/docc-derived-data"

Scripts/check-package-shape.sh
swift package dump-package >"$artifacts_root/SwiftAwesomeButton-package.json"

echo "SwiftAwesomeButton release preflight passed."
if [[ "$clean_artifacts" == false ]]; then
  echo "Artifacts: $artifacts_root"
fi
