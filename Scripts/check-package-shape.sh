#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/awesome-button-package-shape.XXXXXX")"
archive_path="$temporary_root/swift-awesome-button.tar"
expanded_path="$temporary_root/archive"
file_list="$temporary_root/package-files.txt"
manifest_json="$temporary_root/package.json"

cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

if ! git -C "$repository_root" diff --quiet || ! git -C "$repository_root" diff --cached --quiet; then
  echo "Package-shape validation requires a clean tracked tree so git archive represents reviewed source." >&2
  exit 1
fi

mkdir -p "$expanded_path"
git -C "$repository_root" archive --format=tar --output="$archive_path" HEAD
tar -tf "$archive_path" | sed '/\/$/d' | LC_ALL=C sort >"$file_list"
tar -xf "$archive_path" -C "$expanded_path"

echo "Git source archive contents:"
cat "$file_list"

required_paths=(
  ".github/workflows/ci.yml"
  "API/SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json"
  "API/SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json.sha256"
  "API_COMPATIBILITY.md"
  "api-breakage-allowlist.txt"
  "CHANGELOG.md"
  "CONTRIBUTING.md"
  "LICENSE"
  "NOTICE.md"
  "PERFORMANCE.md"
  "Package.swift"
  "README.md"
  "RELEASE_NOTES_1.0.0.md"
  "Scripts/check-api-compatibility.sh"
  "Scripts/generate-api-baseline-candidate.sh"
  "Scripts/normalize-api-baseline.swift"
  "Scripts/check-package-shape.sh"
  "Scripts/check-public-documentation.swift"
  "Scripts/release-preflight.sh"
  "Scripts/test-api-compatibility-gate.sh"
  "Scripts/validate-api-baseline.swift"
  "Sources/SwiftAwesomeButton/SwiftAwesomeButton.docc/SwiftAwesomeButton.md"
)

for required_path in "${required_paths[@]}"; do
  if ! grep -Fxq "$required_path" "$file_list"; then
    echo "Source archive is missing required path: $required_path" >&2
    exit 1
  fi
done

unexpected_path="$(awk '
  /^(\.gitignore|API_COMPATIBILITY\.md|CHANGELOG\.md|CONTRIBUTING\.md|LICENSE|NOTICE\.md|PERFORMANCE\.md|Package\.swift|README\.md|RELEASE_NOTES_1\.0\.0\.md|api-breakage-allowlist\.txt)$/ { next }
  /^\.github\/workflows\/ci\.yml$/ { next }
  /^API\/SwiftAwesomeButton-v1\.0\.0-arm64-apple-ios-simulator\.json(\.sha256)?$/ { next }
  /^Scripts\/(check-api-compatibility\.sh|check-package-shape\.sh|check-public-documentation\.swift|generate-api-baseline-candidate\.sh|normalize-api-baseline\.swift|release-preflight\.sh|test-api-compatibility-gate\.sh|validate-api-baseline\.swift)$/ { next }
  /^(Examples\/|Sources\/|Tests\/|screenshots\/)/ { next }
  { print; exit }
' "$file_list")"
if [[ -n "$unexpected_path" ]]; then
  echo "Source archive contains an unreviewed path: $unexpected_path" >&2
  exit 1
fi

if grep -Eiq '(^|/)(build|\.build|deriveddata|coverage|reports?|caches?|credentials?)(/|$)|\.xcresult($|/)|\.ds_store$' "$file_list"; then
  echo "Source archive contains generated output, reports, caches, or credentials." >&2
  exit 1
fi

(
  cd "$expanded_path"
  swift package dump-package
) >"$manifest_json"

if ! jq -e '
  (.products | length == 1)
  and (.products[0].name == "SwiftAwesomeButton")
  and (.products[0].targets == ["SwiftAwesomeButton"])
  and ([.targets[] | select(.name == "SwiftAwesomeButton" and .type == "regular")] | length == 1)
  and ([.targets[] | select(.name == "SwiftAwesomeButtonTests" and .type == "test")] | length == 1)
  and ([.targets[] | select(.name == "SwiftAwesomeButton")][0].dependencies | length == 0)
  and ([.targets[] | select(.name == "SwiftAwesomeButton")][0].resources == [{"path":"Resources","rule":{"process":{}}}])
  and ([.targets[] | select(.name == "SwiftAwesomeButtonTests")][0].dependencies | length == 1)
' "$manifest_json" >/dev/null; then
  echo "SwiftPM product or target boundary does not match the reviewed package shape." >&2
  exit 1
fi

echo "Validated Git source archive and SwiftPM library/test target separation."
