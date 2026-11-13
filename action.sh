#!/system/bin/sh
# x625d-driver-wifi — status for the KernelSU/Magisk action button.
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-driver-wifi

TGT=/vendor/lib/modules/wlan_drv_gen4m.ko
EXPECTED=082c1773975726b890ab6df90264e7ae8c3da44c260951f3f55e8ba29e6c243c

echo "== x625d-driver-wifi =="
if mount | grep -q " $TGT "; then
  echo "mount : ACTIVE (patched .ko)"
else
  echo "mount : not mounted"
fi
NOW=$(sha256sum "$TGT" 2>/dev/null | awk '{print $1}')
[ "$NOW" = "$EXPECTED" ] && echo "sha   : patched OK" || echo "sha   : ${NOW:-unknown}"
grep -q '^wlan_drv_gen4m ' /proc/modules && echo "driver: loaded" || echo "driver: not loaded"
echo "wifi  : $(settings get global wifi_on 2>/dev/null)"
echo
echo "== last regulatory events =="
dmesg 2>/dev/null | grep -aE 'ValidCC=|n_channels=|Country Code = ' | tail -6
echo
echo "Catatan: 5GHz langsung aktif saat WiFi dinyalakan; tidak perlu menunggu scan."
