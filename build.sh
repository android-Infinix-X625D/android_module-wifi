#!/bin/bash
# Build the module zip.
#   ./build.sh  ->  ../x625d-driver-wifi_v<version>.zip
set -euo pipefail
cd "$(dirname "$0")"

VER=$(sed -n 's/^version=//p' module.prop)
VER=${VER#v}
ZIP="../x625d-driver-wifi_v$VER.zip"

chmod 755 post-fs-data.sh service.sh action.sh uninstall.sh customize.sh
chmod 644 module.prop README.md files/vendor/lib/modules/wlan_drv_gen4m.ko

rm -f "$ZIP"
zip -X -D -r -q "$ZIP" \
  module.prop customize.sh post-fs-data.sh service.sh action.sh uninstall.sh README.md \
  files

echo "== built: $ZIP =="
sha256sum "$ZIP"
unzip -l "$ZIP"
