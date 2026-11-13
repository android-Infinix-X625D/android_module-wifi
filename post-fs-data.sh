#!/system/bin/sh
# x625d-driver-wifi — bind-mount patched wlan_drv_gen4m.ko before init loads it.
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-driver-wifi

SRC=$MODDIR/files/vendor/lib/modules/wlan_drv_gen4m.ko
TGT=/vendor/lib/modules/wlan_drv_gen4m.ko
LOG=$MODDIR/fix-wifi.log
EXPECTED=082c1773975726b890ab6df90264e7ae8c3da44c260951f3f55e8ba29e6c243c

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [pfd] $*" >> "$LOG"; }

# keep the log small
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
  mv -f "$LOG" "$LOG.old"
fi

UP=$(cut -d. -f1 /proc/uptime 2>/dev/null)
log "start uptime=${UP}s"

if [ ! -f "$SRC" ]; then
  log "ABORT: patched module missing: $SRC"
  exit 1
fi
if [ ! -f "$TGT" ]; then
  log "ABORT: vendor module missing: $TGT"
  exit 1
fi

GOT=$(sha256sum "$SRC" 2>/dev/null | awk '{print $1}')
if [ "$GOT" != "$EXPECTED" ]; then
  log "ABORT: sha mismatch (got ${GOT:-none}), stock driver will be used"
  exit 1
fi
log "patched .ko sha ok"

ALREADY=0
if grep -q '^wlan_drv_gen4m ' /proc/modules 2>/dev/null; then
  ALREADY=1
  log "driver already loaded before mount (init loads it early)"
else
  log "driver not loaded yet; init will load the patched file"
fi

# file must carry the vendor label so init is allowed to load it
chcon u:object_r:vendor_file:s0 "$SRC" 2>/dev/null || log "WARN: chcon failed"

# drop any stale mount first
if mount | grep -q " $TGT "; then
  umount "$TGT" 2>/dev/null
fi

if mount --bind "$SRC" "$TGT"; then
  log "bind mount OK: $SRC -> $TGT"
else
  log "ABORT: bind mount failed"
  exit 1
fi

# verify what is now visible at the vendor path
NOW=$(sha256sum "$TGT" 2>/dev/null | awk '{print $1}')
if [ "$NOW" = "$EXPECTED" ]; then
  log "verify OK: $TGT now serves patched .ko"
else
  log "WARN: $TGT sha=${NOW:-none} (expected patched)"
fi

# init loads the driver very early (before this script), so swap the module in
# RAM now. At this stage the WLAN chip has not been probed yet, so it is safe.
if [ "$ALREADY" = "1" ]; then
  log "reloading patched driver now"
  if rmmod wlan_drv_gen4m 2>>"$LOG"; then
    sleep 1
    if insmod "$SRC" 2>>"$LOG"; then
      log "reload OK (patched module in RAM)"
      # wlan_assistant is the userspace NVRAM/MAC provider started by init right
      # after the stock insmod. The fresh module has no NVRAM buffer, so restart
      # it to re-supply MAC/country data before the chip is probed.
      stop wlan_assistant 2>/dev/null
      sleep 1
      start wlan_assistant 2>/dev/null
      sleep 2
      log "wlan_assistant restarted (NVRAM re-pushed)"
    else
      log "ERROR: insmod patched failed; falling back to stock on next boot"
    fi
  else
    log "ERROR: rmmod failed; patched file is mounted and will load on next reload/reboot"
  fi
  if grep -q '^wlan_drv_gen4m ' /proc/modules 2>/dev/null; then
    log "driver loaded after reload"
  else
    log "ERROR: driver not loaded after reload"
  fi
fi

log "done uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)s"
exit 0
