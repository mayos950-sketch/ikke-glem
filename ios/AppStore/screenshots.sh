#!/bin/bash
set -euo pipefail
app_path="$1"
mkdir -p release-assets
xcrun simctl list devices available -j > "$RUNNER_TEMP/devices.json"
device_id=$(python3 - "$RUNNER_TEMP/devices.json" <<'PY'
import json, sys
devices = [d for group in json.load(open(sys.argv[1]))["devices"].values() for d in group if d.get("isAvailable")]
for name in ("iPhone 17 Pro", "iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro"):
    for d in devices:
        if d["name"] == name:
            print(d["udid"])
            sys.exit(0)
raise SystemExit("No supported iPhone simulator available")
PY
)
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl status_bar "$device_id" override --time "9:41" --batteryState charged --batteryLevel 100
xcrun simctl install "$device_id" "$app_path"
xcrun simctl launch "$device_id" com.marioproter.IkkeGlem --screenshots -AppleLanguages '(nb)' -AppleLocale nb_NO
sleep 5
xcrun simctl io "$device_id" screenshot release-assets/01-home.png
xcrun simctl terminate "$device_id" com.marioproter.IkkeGlem
xcrun simctl launch "$device_id" com.marioproter.IkkeGlem --screenshots --screenshots-help -AppleLanguages '(nb)' -AppleLocale nb_NO
sleep 5
xcrun simctl io "$device_id" screenshot release-assets/02-help.png
xcrun simctl shutdown "$device_id"
printf 'Screenshots captured from native iPhone simulator. Sample reminders are fictional.\n' > release-assets/screenshot-notes.txt
