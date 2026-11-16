# Star Citizen Triple Screen

Configurable external Windows wrapper for spanning Star Citizen across multiple
monitors without NVIDIA Surround.

**Download:** https://github.com/hubertdungen/star-citizen-triple-screen/releases

**Source and documentation:** https://github.com/hubertdungen/star-citizen-triple-screen

This independent community project is not affiliated with or endorsed by Cloud
Imperium Games or Roberts Space Industries. Star Citizen and related marks belong
to their respective owners.

This is the Star Citizen-safe adaptation of the X4 idea. The X4 tool used an in-process DLL window hook because X4 is a single-player/sandbox use case. Star Citizen uses Easy Anti-Cheat and online services, so this project deliberately does not inject anything into the game.

## What It Does

- optionally updates `USER.cfg` with a custom wide resolution;
- waits for `StarCitizen.exe` after you launch through the normal RSI Launcher flow;
- follows the game if it recreates its top-level window during renderer startup;
- removes the normal window border from the existing game window;
- positions and sizes the window across your Windows virtual desktop;
- repairs a stale Windows cursor-clip rectangle that can trap menus on one screen;
- stops if the game keeps fighting the rectangle, instead of creating an endless resize loop.

## What It Does Not Do

- no DLL injection;
- no Vulkan/DX hook;
- no process memory access;
- no patching `StarCitizen.exe`;
- no service, driver, stealth, obfuscation, or EAC bypass;
- no direct launch of `StarCitizen.exe`.

## Target Layout

The default `Layout.Mode=AutoUnion` discovers the complete Windows virtual
desktop, so equal-height two-, three-, and wider monitor rows do not require
hard-coded coordinates. `Manual` mode accepts any explicit `X`, `Y`, `Width`, and
`Height`, which also lets you exclude an auxiliary display. See
[docs/CONFIGURATION.md](docs/CONFIGURATION.md) for examples.

Default layout:

```text
[ left 2560x1440 effective ][ centre 2560x1440 native ][ right 2560x1440 effective ]
```

Window rectangle:

```text
X      -2560
Y          0
Width   7680
Height  1440
```

For the two 1080p side monitors, set a 2560x1440 effective resolution first using NVIDIA DSR/DLDSR or a driver-level custom resolution. Keep NVIDIA Surround disabled.

### NVIDIA DSR/DLDSR for 1080p side monitors

1. Open **NVIDIA Control Panel**.
2. Go to **Manage 3D settings > Global Settings**.
3. Open **DSR - Factors** and enable the `1.78x` option that exposes
   `2560x1440` on a native `1920x1080` display. Depending on the driver, the
   option may be labelled `1.78x DL` (DLDSR) or simply `1.78x` (legacy DSR).
4. Select **Apply**.
5. Open **Windows Settings > System > Display**. Select each side monitor in
   turn and set **Display resolution** to `2560x1440`.
6. On every monitor used by the game, set **Scale** to `100%`.
7. Keep the centre monitor at its native `2560x1440`, align all three displays
   by their top edge, and leave the centre display as primary.

If `2560x1440` does not appear for a side monitor after applying the factor,
reopen the NVIDIA setting and confirm that the `1.78x` factor is enabled for the
active GPU/display path before starting the wrapper.

Set **Windows Display Scale to 100% on all three monitors**. A mixed 100% centre
and 125% sides layout makes the current Star Citizen Windowed renderer expand
`7680x1440` into an `8960x1800` outer window. The wrapper detects this and stops
before launch instead of entering a resize loop.

## First Run

Portuguese quick guide: [docs/GUIA-PT.md](docs/GUIA-PT.md).

Keep this wrapper outside the Star Citizen install folder, for example in `Documents\StarCitizenTripleScreen` or `C:\Tools\StarCitizenTripleScreen`. Do not place it in `LIVE\Bin64`, the Easy Anti-Cheat folder, or the RSI Launcher folder.

The only game-folder file this wrapper intentionally touches is `StarCitizen\LIVE\USER.cfg`, which Star Citizen/RSI already treats as a normal custom config file.

1. Edit `StarCitizenTripleScreen.ini`.
2. Keep `Layout.Mode=AutoUnion` for a simple horizontal row, or configure Manual mode.
3. Confirm `Game.Channel`, usually `LIVE`.
4. Put the side monitors into their effective 2560x1440 mode in Windows/NVIDIA settings.
5. Run `Run-StarCitizenTripleScreen.cmd`.
6. Open the RSI Launcher normally and launch Star Citizen.
7. The wrapper waits for the game window and applies the rectangle.

This is one wide render surface, not separate cameras per monitor. Different
physical resolutions are supported when the displays expose compatible effective
heights and all target displays use 100% Windows scale. Layouts not covered by
automatic union remain fully configurable through Manual mode.

If you want the wrapper to open the RSI Launcher, set:

```ini
[Game]
AutoLaunchLauncher=true
```

It still will not start `StarCitizen.exe` directly.

## USER.cfg

By default the script updates:

```text
Con_Restricted = 0
r_WindowMode = 0
r_Width = 7680
r_Height = 1440
```

The default is now `r_WindowMode = 0` (Windowed). The wrapper itself removes the
frame, so the result still looks borderless. In the August 2026 LIVE build,
`r_WindowMode = 2` was logged by Star Citizen as `Borderless`; that path recreated
the window and produced a correctly sized outer window with a letterboxed/squashed
internal render on the tested mixed-monitor setup.

It backs up an existing `USER.cfg` before editing it. To restore the latest backup:

```powershell
.\StarCitizenTripleScreen.ps1 -RestoreUserCfg
```

Star Citizen has changed window handling across builds, so `WindowMode` remains
configurable. Do not change it from `0` unless a test log gives a clear reason.

## Anti-Cheat Reality Check

No one outside CIG/Epic can guarantee an anti-cheat outcome for third-party software. The point of this implementation is to stay on the boring, normal side of Windows: config file plus top-level window management. See [docs/ANTI-CHEAT-SAFETY.md](docs/ANTI-CHEAT-SAFETY.md) and RSI's current [Easy Anti-Cheat guidance](https://support.robertsspaceindustries.com/hc/en-us/articles/4412282759191-Easy-Anti-Cheat).

## Troubleshooting

- If nothing happens, check the newest file in `logs`.
- If the game opens only on the centre monitor, confirm Star Citizen accepted `r_Width` and `r_Height` in `USER.cfg`.
- If the side monitors show cropped or vertically offset content, confirm Windows sees them at 2560x1440 effective height.
- If the log says the window was recreated, that is expected during renderer startup; the wrapper should acquire the new handle and continue.
- If the outer window is correct but the picture is vertically squashed with black space, confirm the log reports `Windowed`, not `Borderless`, and keep `WindowMode=0`.
- If the image is too tall/cropped and the log reports `8960x1800`, set Windows Display Scale to 100% on both side monitors. Do not compensate by lowering `Height`; that changes the render geometry.
- If the mouse is trapped on one monitor, confirm `[Input] RepairCursorClip=true`; the log should show the old clip and its expansion to the complete target.
- If the script stops with a resize-loop warning, Star Citizen is repeatedly changing its own window. Keep `ContinuousWatch=false` and attach the wrapper log plus `StarCitizen\LIVE\Game.log` to the bug report.
- If the game or launcher has issues, restore `USER.cfg`, close the wrapper, and run Star Citizen normally.


<p align="center"><a href="https://dlforge.dungenlabs.com"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/branding/dlforge-logo-negative.svg"><source media="(prefers-color-scheme: light)" srcset="docs/branding/dlforge-logo.svg"><img src="docs/branding/dlforge-logo.svg" alt="DL Forge" width="120"></picture></a></p>
