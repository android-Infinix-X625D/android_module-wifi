#!/system/bin/sh
# x625d-driver-wifi — remove the bind mount; /vendor itself was never modified.
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-driver-wifi

TGT=/vendor/lib/modules/wlan_drv_gen4m.ko
LOG=$MODDIR/fix-wifi.log

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [uninst] $*" >> "$LOG"; }

if mount | grep -q " $TGT "; then
  umount "$TGT" 2>/dev/null && log "bind mount removed" || log "WARN: umount failed"
else
  log "no bind mount at $TGT"
fi
log "uninstalled; reboot recommended"
exit 0
