# Infinix X625D - Wi-Fi Driver (All Channels)

Root module (KernelSU/Magisk) for the Infinix Hot 7 Pro **X625D** (MT6765, Android 9) that unlocks **every supported Wi-Fi channel** on the CONNAC/MT7668 chip by patching the **vendor driver** `wlan_drv_gen4m.ko`.


## Result
**39 channels in every country** — 2.4 GHz `1–14` + 5 GHz `36–64`, `100–144`, `149–165`.
5 GHz and channel 14 are available as soon as Wi-Fi is turned on, regardless of which country code the framework sends.


## Why patch the driver

`arSupportedRegDomains[]` holds 22 domain entries (48 bytes each): 6 sub-bands (`band, step, first channel, count, flag`).
The framework picks an entry from the country code (SIM/operator) right before the first scan.

Stock problems:

- Entry **`ID`** (idx 15) has every 5 GHz sub-band disabled → 13 channels only.
- Other countries have their own limits: Japan (idx 0) has channel 14 but no 149–165; many entries are 2.4 GHz only.
- Default/`XX` (idx 21) has full 5 GHz but no channel 14.

A runtime watcher sending `COUNTRY XX` always loses the race, because the framework sends the country before the first scan.
Patching a single entry is also not enough when the SIM/roaming country changes, so this module fills **all 22 entries** with the same complete channel set.


## What the patch changes

**461 bytes** in `arSupportedRegDomains`: all 22 entries get the same six groups.

| group | contents |
|---|---|
| 2.4 GHz | 1–13 |
| 2.4 GHz | 14 |
| 5 GHz UNII-1 | 36, 40, 44, 48 |
| 5 GHz UNII-2A | 52, 56, 60, 64 (DFS) |
| 5 GHz UNII-2C | 100–144, 12 channels (DFS) |
| 5 GHz UNII-3 | 149, 153, 157, 161, 165 |

Entry headers (domain id) are untouched, and the power-limit table `g_rRlmPowerLimitDefault` is not modified — each country keeps its original non-zero power limits, including for channel 14.

No code is modified; file size and vermagic stay the same.

- sha256 stock  : `780fc3407552d8cb154c2b20dca0d3999f351b77d61295d1e0f2b843b077bebd`
- sha256 patched: `082c1773975726b890ab6df90264e7ae8c3da44c260951f3f55e8ba29e6c243c`


## How it works at boot

The stock `/vendor` partition is never modified. The patched `.ko` lives inside the module and is bind-mounted over `/vendor/lib/modules/wlan_drv_gen4m.ko` in `post-fs-data`.

- init loads the stock driver from `/vendor` very early (around 5 s uptime), before module scripts run.
- `post-fs-data` (around 7 s) bind-mounts the patched file, then `rmmod`s the stock module and `insmod`s the patched one. The WLAN chip has not been probed yet, so the swap is safe.
- The fresh module has no NVRAM buffer, so `wlan_assistant` is restarted to re-supply the MAC address and country data before the chip is probed.
- `service.sh` verifies the mount, sha, driver, and the first scan, and writes the result to `fix-wifi.log`.

Removing the module unmounts the patched file; a reboot restores the stock driver. The bind mount is done manually because the KernelSU Next build on this device does not magic-mount module files into `/vendor`.


## Hardware limits

Chip is **CONNAC / MT7668** (dmesg: `wlan CONNAC`, `Chip ID[0001] Version[E1]`), RF 2.4 GHz 2412–2484 MHz and 5 GHz 5180–5825 MHz.

- Channel 14 is supported by the hardware → once added, scans report 39 channels.
- **5.9 GHz (169/173/177) is not supported.** Tested with UNII-3 `first = 149, count = 8`: driver/firmware still filters them, result stays 39.
- **6 GHz (Wi-Fi 6E) is not supported.**

Channel 14 is a Japan-only allocation; regulatory compliance remains the user's responsibility.


## Verification

Log: `/data/adb/modules/x625d-driver-wifi/fix-wifi.log`

```
rlmDomainSendPwrLimitCmd: Domain: PwrLimitChNum=60, ValidCC=ID, PwrLimitCC=ID
SCANLOG: [SCN:100:K2D] n_channels=39: 1 2 ... 13 14 36 40 ... 144 149 153 157 161 165
scnEventScanDone: Country Code = ID, Detected_Channel_Num = 39
```

Tested with simulated country changes on the same driver:

| country | result |
|---|---|
| `ID` | `ValidCC=ID`, `Detected_Channel_Num = 39` |
| `US` | `ValidCC=US`, `Detected_Channel_Num = 39` |
| `JP` | `ValidCC=JP`, `Detected_Channel_Num = 39` (includes 149–165 + ch14) |
| `XX` (unknown) | default domain, 39 channels |

The Action button in KernelSU shows mount status, sha, driver, and the last regulatory event.


## Notes

- The stock kernel does not enable `CONFIG_MODULE_SIG`; do not use this module on a kernel with signature enforcement.
- All 22 entries are patched, so the 39-channel set applies in every country. Regulatory compliance remains the user's responsibility; the stock power limits per country are preserved.
- Reverse engineered with REA (Ghidra 12.1.4): `rlmDomainGetDomainInfo`, `rlmDomainGetChnlList`, `rlmDomainSendDomainInfoCmd`, `rlmDomainSendPwrLimitCmd`.

## Credits

Built with **OpenCode** — the AI coding agent used for the reverse engineering, driver patching, on-device testing, and module packaging.
