#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configuration="FocusDebug"
derived_data_path="$repo_root/DerivedData"
full_product_name="Web Viewer.app"
expected_bundle_identifier="me.whydontyoulove.ios.webviewer.Focus"

build_arguments=(build)
devicectl_arguments=()

if [[ "${RUN_VERBOSE:-0}" != "1" ]]; then
  build_arguments=(-quiet build)
  devicectl_arguments=(--quiet)
fi

temporary_directory="$(mktemp -d)"
devices_json="$temporary_directory/devices.json"

cleanup() {
  rm -f "$devices_json"
  rmdir "$temporary_directory" 2>/dev/null || true
}
trap cleanup EXIT

plist_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null || true
}

print_devices() {
  local index

  for ((index = 0; index < ${#device_identifiers[@]}; index++)); do
    printf '  %s (DEVICE_ID=%s)\n' \
      "${device_names[$index]}" \
      "${device_udids[$index]}" >&2
  done
}

echo "Finding paired iPhones available over Wi-Fi..."
xcrun devicectl ${devicectl_arguments[@]+"${devicectl_arguments[@]}"} \
  list devices --json-output "$devices_json" >/dev/null

device_identifiers=()
device_udids=()
device_names=()
device_count="$(plist_value result.devices "$devices_json")"

if [[ ! "$device_count" =~ ^[0-9]+$ ]]; then
  echo "error: Could not read the paired-device list from devicectl." >&2
  exit 1
fi

for ((index = 0; index < device_count; index++)); do
  prefix="result.devices.$index"
  platform="$(plist_value "$prefix.hardwareProperties.platform" "$devices_json")"
  reality="$(plist_value "$prefix.hardwareProperties.reality" "$devices_json")"
  device_type="$(plist_value "$prefix.hardwareProperties.deviceType" "$devices_json")"
  boot_state="$(plist_value "$prefix.deviceProperties.bootState" "$devices_json")"
  pairing_state="$(plist_value "$prefix.connectionProperties.pairingState" "$devices_json")"
  transport_type="$(plist_value "$prefix.connectionProperties.transportType" "$devices_json")"

  if [[ "$platform" != "iOS" ||
        "$reality" != "physical" ||
        "$device_type" != "iPhone" ||
        "$boot_state" != "booted" ||
        "$pairing_state" != "paired" ||
        "$transport_type" != "localNetwork" ]]; then
    continue
  fi

  device_identifiers+=("$(plist_value "$prefix.identifier" "$devices_json")")
  device_udids+=("$(plist_value "$prefix.hardwareProperties.udid" "$devices_json")")
  device_names+=("$(plist_value "$prefix.deviceProperties.name" "$devices_json")")
done

if [[ ${#device_identifiers[@]} -eq 0 ]]; then
  echo "error: No paired iPhone is currently available over Wi-Fi." >&2
  echo "Unlock the iPhone, enable Developer Mode, and pair it with Xcode over USB once with Connect via Network enabled." >&2
  exit 1
fi

selected_index=""
requested_device="${DEVICE_ID:-}"

if [[ -n "$requested_device" ]]; then
  for ((index = 0; index < ${#device_identifiers[@]}; index++)); do
    if [[ "$requested_device" == "${device_identifiers[$index]}" ||
          "$requested_device" == "${device_udids[$index]}" ||
          "$requested_device" == "${device_names[$index]}" ]]; then
      if [[ -n "$selected_index" ]]; then
        echo "error: DEVICE_ID matches more than one available iPhone; use a UDID instead." >&2
        print_devices
        exit 1
      fi
      selected_index="$index"
    fi
  done

  if [[ -z "$selected_index" ]]; then
    echo "error: DEVICE_ID does not match an available wireless iPhone: $requested_device" >&2
    print_devices
    exit 1
  fi
elif [[ ${#device_identifiers[@]} -eq 1 ]]; then
  selected_index=0
else
  echo "error: More than one wireless iPhone is available; set DEVICE_ID to choose one." >&2
  print_devices
  exit 1
fi

device_identifier="${device_identifiers[$selected_index]}"
device_udid="${device_udids[$selected_index]}"
device_name="${device_names[$selected_index]}"
destination="platform=iOS,id=$device_udid"

echo "Building a signed $configuration Focus build for $device_name..."
DEVICE_DESTINATION="$destination" \
  "$repo_root/scripts/build-device.sh" "${build_arguments[@]}"

app_path="$derived_data_path/Build/Products/$configuration-iphoneos/$full_product_name"
if [[ ! -d "$app_path" ]]; then
  echo "error: Could not locate the built Focus app at $app_path." >&2
  exit 1
fi

bundle_identifier="$(plist_value CFBundleIdentifier "$app_path/Info.plist")"
if [[ "$bundle_identifier" != "$expected_bundle_identifier" ]]; then
  echo "error: Expected Focus bundle $expected_bundle_identifier, found ${bundle_identifier:-none}." >&2
  exit 1
fi

echo "Verifying the app signature..."
/usr/bin/codesign --verify --deep --strict "$app_path"

echo "Installing $full_product_name on $device_name over Wi-Fi..."
xcrun devicectl ${devicectl_arguments[@]+"${devicectl_arguments[@]}"} \
  device install app --device "$device_identifier" "$app_path"

echo "Launching $bundle_identifier on $device_name..."
xcrun devicectl ${devicectl_arguments[@]+"${devicectl_arguments[@]}"} \
  device process launch \
  --device "$device_identifier" \
  --terminate-existing \
  "$bundle_identifier"
