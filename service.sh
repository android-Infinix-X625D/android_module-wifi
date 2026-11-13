#!/system/bin/sh
# x625d-driver-wifi — late boot verification (no risky reload here;
# post-fs-data.sh already swapped the module in RAM before the chip probe).
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-driver-wifi

TGT=/vendor/lib/modules/wlan_drv_gen4m.ko
EXPECTED=082c1773975726b890ab6df90264e7ae8c3da44c260951f3f55e8ba29e6c243c
LOG=$MODDIR/fix-wifi.log

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [svc] $*" >> "$LOG"; }

log "service start uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)s"

# wait for boot to settle (max 90s)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do
  sleep 1
  i=$((i+1))
done

if mount | grep -q " $TGT "; then
  log "bind mount present"
else
  log "WARN: bind mount missing at $TGT"
fi
NOW=$(sha256sum "$TGT" 2>/dev/null | awk '{print $1}')
[ "$NOW" = "$EXPECTED" ] && log "target sha: patched" || log "WARN: target sha=${NOW:-none}"

if grep -q '^wlan_drv_gen4m ' /proc/modules 2>/dev/null; then
  log "driver loaded"
else
  log "WARN: wlan_drv_gen4m not loaded"
fi

if grep -q '^\[.*\] \[pfd\] reload OK' "$LOG" 2>/dev/null; then
  log "post-fs-data reload confirmed"
fi

# wait up to 60s for the first scan and record the proof
i=0
while [ $i -lt 60 ]; do
  LINE=$(dmesg 2>/dev/null | grep -a 'n_channels=' | tail -1)
  if [ -n "$LINE" ]; then
    log "scan: $LINE"
    break
  fi
  sleep 2
  i=$((i+2))
done

log "service done"
exit 0
