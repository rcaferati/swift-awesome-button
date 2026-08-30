#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_tag_commit="c296ea3d3167fec16eae45c749124f832359b702"
baseline_name="SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json"

if [[ $# -ne 1 || "$1" != /* ]]; then
  echo "usage: Scripts/generate-api-baseline-candidate.sh <absolute-output-directory>" >&2
  exit 64
fi

output_root="$1"
baseline_path="$output_root/$baseline_name"
sidecar_path="$baseline_path.sha256"
provenance_path="$output_root/provenance.txt"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/awesome-button-swift-baseline.XXXXXX")"
tag_source="$temporary_root/v1.0.0"

cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

resolved_tag="$(git -C "$repository_root" rev-list -n 1 v1.0.0)"
if [[ "$resolved_tag" != "$expected_tag_commit" ]]; then
  echo "v1.0.0 resolved to $resolved_tag, expected $expected_tag_commit." >&2
  exit 1
fi

if [[ -e "$baseline_path" || -e "$sidecar_path" || -e "$provenance_path" ]]; then
  echo "Baseline output paths must not already exist: $output_root" >&2
  exit 1
fi

mkdir -p "$output_root" "$tag_source"
git -C "$repository_root" archive v1.0.0 | tar -x -C "$tag_source"
swift_flags='$(inherited) -emit-digester-baseline-path '"$baseline_path"

(
  cd "$tag_source"
  xcodebuild -quiet -scheme swift-awesome-button \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$temporary_root/baseline-derived-data" \
    clean build \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    "OTHER_SWIFT_FLAGS=$swift_flags"
)

swift "$repository_root/Scripts/normalize-api-baseline.swift" "$baseline_path"
swift "$repository_root/Scripts/validate-api-baseline.swift" "$baseline_path"
(
  cd "$output_root"
  shasum -a 256 "$baseline_name" >"$(basename "$sidecar_path")"
)

{
  printf 'source_tag=v1.0.0\n'
  printf 'source_commit=%s\n' "$resolved_tag"
  printf 'target=arm64-apple-ios16.0-simulator\n'
  xcodebuild -version
  xcrun swift --version
  printf 'iphonesimulator_sdk=%s\n' "$(xcrun --sdk iphonesimulator --show-sdk-version)"
  printf 'sha256=%s\n' "$(shasum -a 256 "$baseline_path" | awk '{print $1}')"
} >"$provenance_path"

echo "Generated validated baseline candidate and provenance at $output_root."
