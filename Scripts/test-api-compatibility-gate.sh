#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/awesome-button-api-canary.XXXXXX")"
temporary_repository="$temporary_root/repository"
plain_build_log="$temporary_root/plain-build.log"
comparison_log="$temporary_root/comparison.log"

cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

if [[ -n "$(git -C "$repository_root" status --porcelain --untracked-files=all)" ]]; then
  echo "API canary requires a clean tree so its isolated git archive matches the reviewed source." >&2
  exit 1
fi

mkdir -p "$temporary_repository"
git -C "$repository_root" archive HEAD | tar -x -C "$temporary_repository"

canary_source="$temporary_repository/Sources/SwiftAwesomeButton/Models.swift"
perl -0pi -e \
  's/public func merge\(_ other: AwesomeButtonStyle\?\) -> AwesomeButtonStyle/internal func merge(_ other: AwesomeButtonStyle?) -> AwesomeButtonStyle/' \
  "$canary_source"

if ! grep -Fq 'internal func merge(_ other: AwesomeButtonStyle?)' "$canary_source"; then
  echo "API canary could not install the intended AwesomeButtonStyle.merge restriction." >&2
  exit 1
fi

set +e
(
  cd "$temporary_repository"
  xcodebuild -quiet -scheme swift-awesome-button \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$temporary_root/plain-derived-data" \
    clean build \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
) >"$plain_build_log" 2>&1
plain_status=$?
set -e

cat "$plain_build_log"
if [[ $plain_status -ne 0 ]]; then
  echo "API canary mutation did not compile without comparison; this is not valid breakage evidence." >&2
  exit 1
fi

set +e
(
  cd "$temporary_repository"
  Scripts/check-api-compatibility.sh
) >"$comparison_log" 2>&1
comparison_status=$?
set -e

cat "$comparison_log"
if [[ $comparison_status -eq 0 ]]; then
  echo "API canary failed: restricting AwesomeButtonStyle.merge was accepted." >&2
  exit 1
fi

if ! grep -Eiq '(merge|AwesomeButtonStyle)' "$comparison_log"; then
  echo "API canary failed for a reason that did not name the mutated declaration." >&2
  exit 1
fi

if ! grep -Eiq '(api break|breaking change|removed decl|decl.*removed)' "$comparison_log"; then
  echo "API canary did not emit an API-digester breakage diagnostic." >&2
  exit 1
fi

echo "Swift API canary rejected the isolated declaration restriction as expected."
