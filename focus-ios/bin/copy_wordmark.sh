#!/bin/bash

set -euo pipefail

copy_if_needed() {
    local source_file="$1"
    local destination_file="$2"

    if [[ ! -f "${destination_file}" ]] || ! cmp -s "${source_file}" "${destination_file}"; then
        cp "${source_file}" "${destination_file}"
    fi
}

SOURCE_ASSET_DIR="${SRCROOT}/Blockzilla/Assets.xcassets"
DESTINATION_ASSET_DIR="${SOURCE_ASSET_DIR}/img_focus_launchscreen.imageset"

if [[ "${PRODUCT_NAME}" == "Firefox Klar" ]]; then
    SOURCE_WORDMARK_DIR="${SOURCE_ASSET_DIR}/img_klar_wordmark.imageset"
    declare -a SOURCE_FILES=(
        "img_klar_wordmark.png"
        "img_klar_wordmark@2x.png"
        "img_klar_wordmark@3x.png"
        "ic_logo_wordmark_light_horizontal_klar.png"
        "ic_logo_wordmark_light_horizontal_klar@2x.png"
        "ic_logo_wordmark_light_horizontal_klar@3x.png"
    )
else
    SOURCE_WORDMARK_DIR="${SOURCE_ASSET_DIR}/img_focus_wordmark.imageset"
    declare -a SOURCE_FILES=(
        "img_focus_wordmark.png"
        "img_focus_wordmark@2x.png"
        "img_focus_wordmark@3x.png"
        "ic_logo_wordmark_light_horizontal.png"
        "ic_logo_wordmark_light_horizontal@2x.png"
        "ic_logo_wordmark_light_horizontal@3x.png"
    )
fi

declare -a DESTINATION_FILES=(
    "img_focus_wordmark.png"
    "img_focus_wordmark@2x.png"
    "img_focus_wordmark@3x.png"
    "ic_logo_wordmark_light_horizontal.png"
    "ic_logo_wordmark_light_horizontal@2x.png"
    "ic_logo_wordmark_light_horizontal@3x.png"
)

for index in "${!SOURCE_FILES[@]}"; do
    copy_if_needed \
        "${SOURCE_WORDMARK_DIR}/${SOURCE_FILES[${index}]}" \
        "${DESTINATION_ASSET_DIR}/${DESTINATION_FILES[${index}]}"
done
