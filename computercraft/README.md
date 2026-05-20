# MC Control Room ComputerCraft Suite

Target: Minecraft All the Mods 10 with CC:Tweaked/ComputerCraft-style computers.

Recommended install: push this folder to
`https://github.com/dadou000/codebrown` on the `main` branch. The bootloader uses
GitHub raw URLs from `bootloader_startup.lua` to download the selected dynamic
program. Install the bootloader on each in-game computer as `/startup.lua`. On
first boot it shows a selectable touch/click console menu for the program type,
then a second menu for the physical instance when needed. It downloads the
matching program to `/mccr_program.lua`, verifies the selected program and
instance, writes `/mccr_device.dat`, and keeps the program running after
reboot/reload.

The files in `programs/*/startup.lua` are fully standalone dynamic bundles. They
do not need any shared source folder on the in-game computer. The old `mccr` and
`computers` folders have been removed; `programs` is the deployable layout.

Every program:

- opens every attached modem and uses rednet protocol `mccr.v1`
- saves state under `/mccr_state` so chunk unload/reload and reboot recover cleanly
- publishes heartbeat/telemetry packets
- accepts `restore` commands from the admin panel
- can be refreshed from the bootloader by typing `update` locally, or from the
  admin panel Settings tab with `UPDATE ALL`
- continues in simulated mode when real mod/peripheral APIs are not available

Main computers and screens included:

- `maincomputer`
- `peripheral1_draconic`
- `peripheral2_mekanism`
- `peripheral3_ae2`
- `peripheral4_spare`
- `peripheral5_fake_load`
- `peripheral6_sound`
- `PMC1`, `PMC2`, `PMC3`
- `admin_control_panel`
- `emergency_controls_screen`
- `action_screen`
- `alert_level_screen`
- `clock`
- `mon1`, `mon2`, `mon3`, `mon4`
- `statsm1`, `statsm2`, `statsm3`, `statsm4`, `statsm5`, `statsm6`
- `presentation_screen_left`, `main_presentation_screen`, `presentation_screen_right`

In-game layout:

```text
/startup.lua              from bootloader_startup.lua
/mccr_boot.dat            created by bootloader_startup.lua after device selection
/mccr_program.lua         selected device program downloaded by bootloader_startup.lua
/mccr_device.dat          created by bootloader_startup.lua after device selection
/mccr_state/*.dat         created automatically for persistent state
```

The main computer is the supervisor. Start it first if possible. Other computers
will still run while offline and reconnect when the chunk loads again.

The admin panel now uses compact `Power`, `Screens`, and `Settings` tabs. The
`Screens` tab selects a target display first, then sends that display its own
context. The `Settings` tab handles resets, display colors/themes, sound channel
selection, and program updates.

Updating installed computers:

```text
update
```

Type `update` in a computer terminal and press Enter to make the bootloader
download the current GitHub raw version for that computer's selected program
type.

From the admin panel, open `Settings` and press `UPDATE ALL` to broadcast an
update command. Press `UPDATE SELF` to refresh only the admin panel computer.

The bootloader downloads updates into `/mccr_program.lua.tmp`, verifies the
temporary file, then replaces `/mccr_program.lua`. Remote `UPDATE ALL` requests
are staggered per computer to avoid Pastebin rate limits.

Bootloaders broadcast update progress over rednet as `update_status` packets.
Remote `UPDATE ALL` starts devices in half-second slots, excludes the admin
panel so it can stay online, and the admin Settings tab shows one aggregate
fleet progress bar. Use `UPDATE SELF` afterward to refresh the admin panel.

Bootloader updates are separate. The admin panel embeds the current
`bootloader_startup.lua` and `BOOT ALL` streams it over rednet in chunks, so the
fleet bootloader update does not contact GitHub or Pastebin from every computer.
Use `BOOT SELF` last to update the admin panel bootloader.

GitHub source layout expected by the bootloader:

```text
https://raw.githubusercontent.com/dadou000/codebrown/main/computercraft/bootloader_startup.lua
https://raw.githubusercontent.com/dadou000/codebrown/main/computercraft/programs/<type>/startup.lua
```

If the GitHub repository is private, ComputerCraft will not be able to download
from raw GitHub without credentials. For a private codebase, host the same files
on a small HTTP server reachable by the Minecraft server and change
`SOURCE_BASE_URL` in `bootloader_startup.lua`.
