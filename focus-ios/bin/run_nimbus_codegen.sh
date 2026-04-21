#!/bin/bash

set -euo pipefail

cleanup_tmp_dir() {
    rm -rf "$1"
}

sync_generated_files() {
    local source_dir="$1"
    local destination_dir="$2"
    local generated_file

    while IFS= read -r -d '' generated_file; do
        local relative_path="${generated_file#"${source_dir}/"}"
        local destination_file="${destination_dir}/${relative_path}"

        mkdir -p "$(dirname "${destination_file}")"

        if [[ ! -f "${destination_file}" ]] || ! cmp -s "${generated_file}" "${destination_file}"; then
            mv "${generated_file}" "${destination_file}"
        fi
    done < <(find "${source_dir}" -type f -print0)
}

OUTPUT_DIR="${SOURCE_ROOT}/${PROJECT}/Generated"
TEMP_OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nimbus-generated.XXXXXX")
trap 'cleanup_tmp_dir "${TEMP_OUTPUT_DIR}"' EXIT

bash "${SOURCE_ROOT}/bin/nimbus-fml.sh" --output "${TEMP_OUTPUT_DIR}" "$@"
sync_generated_files "${TEMP_OUTPUT_DIR}" "${OUTPUT_DIR}"
