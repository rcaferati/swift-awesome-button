#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
baseline_name="SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json"
baseline_path="$repository_root/API/$baseline_name"
sidecar_path="$baseline_path.sha256"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/awesome-button-api-compare.XXXXXX")"
comparison_log="$temporary_root/api-compare.log"
breaking_diagnostics="$temporary_root/api-breaking-changes.dia"

cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

swift "$repository_root/Scripts/validate-api-baseline.swift" "$baseline_path"

if [[ ! -s "$sidecar_path" ]]; then
  echo "API baseline checksum sidecar is missing or empty: $sidecar_path" >&2
  exit 1
fi

(
  cd "$repository_root/API"
  shasum -a 256 -c "$(basename "$sidecar_path")"
)

swift_flags='$(inherited) -compare-to-baseline-path '"$baseline_path"
allowlist_path="$repository_root/api-breakage-allowlist.txt"
if [[ -e "$allowlist_path" ]]; then
  if [[ ! -s "$allowlist_path" ]]; then
    echo "Remove the empty API breakage allowlist instead of committing a ceremonial file." >&2
    exit 1
  fi
  if grep -Ev '^API breakage: .+$' "$allowlist_path" | grep -q .; then
    echo "Every API allowlist row must be one exact API breakage diagnostic." >&2
    exit 1
  fi
  if [[ "$(LC_ALL=C sort "$allowlist_path" | uniq -d | wc -l | tr -d ' ')" != "0" ]]; then
    echo "API breakage allowlist contains a duplicate diagnostic." >&2
    exit 1
  fi
  swift_flags="$swift_flags -digester-breakage-allowlist-path $allowlist_path"
fi
swift_flags="$swift_flags -serialize-breaking-changes-path $breaking_diagnostics"

set +e
cd "$repository_root"
xcodebuild -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$temporary_root/derived-data" \
  clean build \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  "OTHER_SWIFT_FLAGS=$swift_flags" >"$comparison_log" 2>&1
build_status=$?
set -e

if [[ $build_status -ne 0 ]]; then
  cat "$comparison_log"
  echo "Swift compiler API comparison failed." >&2
  exit "$build_status"
fi

if grep -Eiq '(warning|error): API breakage:' "$comparison_log"; then
  grep -Ei '(warning|error): API breakage:' "$comparison_log" >&2
  echo "Swift compiler emitted a non-allowlisted API breakage diagnostic." >&2
  exit 1
fi

echo "Swift compiler API comparison passed against $baseline_name."
