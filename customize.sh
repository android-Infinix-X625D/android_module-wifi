#!/system/bin/sh
# x625d-driver-wifi — installer hook (KernelSU / Magisk).
MODPATH="${MODPATH:-$PWD}"

if type set_perm_recursive >/dev/null 2>&1; then
    set_perm_recursive "$MODPATH" 0 0 0755 0644
    set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
    set_perm "$MODPATH/service.sh" 0 0 0755
    set_perm "$MODPATH/action.sh" 0 0 0755
    set_perm "$MODPATH/uninstall.sh" 0 0 0755
    set_perm "$MODPATH/files/vendor/lib/modules/wlan_drv_gen4m.ko" 0 0 0644
else
    chmod 755 "$MODPATH" "$MODPATH"/*.sh
    chmod 644 "$MODPATH/module.prop" "$MODPATH/README.md" 2>/dev/null
    chmod 644 "$MODPATH/files/vendor/lib/modules/wlan_drv_gen4m.ko"
fi

exit 0
