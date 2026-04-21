#!/bin/bash

set -euo pipefail

if [[ "$(uname -m)" == "arm64" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
    exit 0
fi

REPO_ROOT="${SRCROOT}/.."
CONFIG_FILE="${SRCROOT}/.swiftlint.yml"
BASELINE_FILE="${REPO_ROOT}/.swiftlint-baseline.json"

collect_modified_files() {
    git -C "${REPO_ROOT}" diff --name-only --diff-filter=ACM -- focus-ios | grep -E '\.swift$' || true
    git -C "${REPO_ROOT}" diff --cached --name-only --diff-filter=ACM -- focus-ios | grep -E '\.swift$' || true
    git -C "${REPO_ROOT}" ls-files --others --exclude-standard -- focus-ios | grep -E '\.swift$' || true
}

MODIFIED_FILES=()
while IFS= read -r modified_file; do
    MODIFIED_FILES+=("${modified_file}")
done < <(collect_modified_files | awk 'NF' | sort -u)

if [[ "${#MODIFIED_FILES[@]}" -eq 0 ]]; then
    echo "No modified Swift files under focus-ios; skipping SwiftLint."
    exit 0
fi

cd "${REPO_ROOT}"

SWIFTLINT_ARGS=(
    lint
    --force-exclude
    --config "${CONFIG_FILE}"
)

if [[ -f "${BASELINE_FILE}" ]]; then
    SWIFTLINT_ARGS+=(--baseline "${BASELINE_FILE}")
fi

swiftlint "${SWIFTLINT_ARGS[@]}" "${MODIFIED_FILES[@]}"
