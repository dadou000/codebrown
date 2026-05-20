# MCCR Pastebin Upload Checklist

Upload each dynamic program file below to its own Pastebin. Paste each ID into
the matching `PASTEBIN_IDS` slot inside `bootloader_startup.lua`, then upload the
bootloader itself to Pastebin.

For bootloader self-updates, also paste the bootloader's own Pastebin ID into
`BOOTLOADER_PASTEBIN_ID` before uploading `bootloader_startup.lua`.

In Minecraft, install the bootloader as `/startup.lua`. It will show a touch/click
menu for the program type, then a second menu for the instance when needed.

| Bootloader program choice | Upload this file to Pastebin | Instances selected in-game | Pastebin ID |
| --- | --- | --- | --- |
| `maincomputer` | `programs/maincomputer/startup.lua` | `maincomputer` | `ueY3Fmye` |
| `admin_control_panel` | `programs/admin_control_panel/startup.lua` | `admin_control_panel` | `cqpYrNs5` |
| `emergency_controls_screen` | `programs/emergency_controls_screen/startup.lua` | `emergency_controls_screen` | `VvxgATEN` |
| `action_screen` | `programs/action_screen/startup.lua` | `action_screen` | `hM9jLzcb` |
| `alert_level_screen` | `programs/alert_level_screen/startup.lua` | `alert_level_screen` | `yyDJtM4p` |
| `clock` | `programs/clock/startup.lua` | `clock` | `Rcx37DxC` |
| `mon` | `programs/mon/startup.lua` | `mon1`, `mon2`, `mon3`, `mon4` | `rktaUG0a` |
| `statsm` | `programs/statsm/startup.lua` | `statsm1` through `statsm6` | `5yTMXSLG` |
| `presentation_screen` | `programs/presentation_screen/startup.lua` | left, main, right presentation screens | `zQjrdrBp` |
| `PMC` | `programs/PMC/startup.lua` | `PMC1`, `PMC2`, `PMC3` | `NKrrcY8p` |
| `peripheral` | `programs/peripheral/startup.lua` | draconic, mekanism, AE2, spare, fake load, sound device | `ENtPE4DW` |

The bootloader verifies that the downloaded code contains the selected
`MCCR_PROGRAM` and that the selected instance exists inside the program.

## Automated updates

After logging in to Pastebin in Firefox, you can update all configured Pastebins
from the local files with:

```powershell
.\update_pastebins.ps1
```

Useful variants:

```powershell
.\update_pastebins.ps1 --skip-bootloader
.\update_pastebins.ps1 admin_control_panel mon clock
.\update_pastebins.ps1 --verify-only
```

If Pastebin shows a Cloudflare/human check, open Pastebin in Firefox, clear the
check, open one `/edit/<id>` page, then run the script again.

When update-system code changes, upload the bootloader too. The admin panel can
schedule fleet updates from live telemetry, but computers only use the improved
bootloader countdown/status protocol after their `/startup.lua` has been updated
from the bootloader Pastebin.
