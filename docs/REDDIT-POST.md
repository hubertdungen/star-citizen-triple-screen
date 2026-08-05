# [Guide + open-source tool] Mixed-resolution triple monitors in Star Citizen without NVIDIA Surround

Hi everyone,

I wanted Star Citizen across three independent monitors: a native 2560x1440
centre and two physical 1080p sides, without NVIDIA Surround. CRU and NVIDIA
DSR/DLDSR could expose the effective side resolutions, but Star Citizen still
started from the primary display and its Windowed/Borderless behavior produced
the wrong surface.

After testing the startup sequence, window recreation, Windows DPI scaling, and
cursor confinement, I built **Star Citizen Triple Screen**, a small open-source
external Windows wrapper.

Download: https://github.com/hubertdungen/star-citizen-triple-screen/releases

Source and documentation: https://github.com/hubertdungen/star-citizen-triple-screen

The verified result is a real 7680x1440 Star Citizen render surface across three
monitors, with Surround disabled and the mouse able to cross the complete span.

## What it does

- detects the Windows virtual desktop or accepts manual coordinates;
- backs up and updates the normal Star Citizen USER.cfg;
- waits for launch through the normal RSI Launcher/EAC flow;
- follows Star Citizen if it recreates its top-level window;
- removes the frame and applies the requested external window rectangle;
- repairs a stale Windows cursor clip that can trap menus on one monitor;
- detects mixed Windows DPI scaling before it creates a cropped window;
- stops after bounded corrections instead of running an endless resize loop.

## What it deliberately does not do

No DLL injection, Vulkan/DX hook, game-memory access, executable patching, direct
StarCitizen.exe launch, EAC bypass, service, driver, stealth, or obfuscation.
It is plain-text PowerShell and normal top-level Windows window management. No
third-party tool can promise an anti-cheat outcome, so please read the source and
safety notes before deciding whether to use it. RSI's current EAC guidance is
linked from the repository; this project is independent and is not official CIG,
RSI, or Epic software.

## My mixed 1440p + 1080p setup

1. Keep NVIDIA Surround disabled.
2. Open **NVIDIA Control Panel > Manage 3D settings > Global Settings > DSR - Factors**.
3. Enable the `1.78x` factor that exposes `2560x1440` on a native `1920x1080`
   display. Depending on the driver, it may be labelled `1.78x DL` (DLDSR) or
   simply `1.78x` (legacy DSR), then select **Apply**.
4. Open **Windows Settings > System > Display**, select each side monitor, and
   set its display resolution to `2560x1440`. Keep the centre at native `2560x1440`.
5. Set **Windows Scale to 100% on every display used by the game**. This matters:
   125% sides plus a 100% centre made Star Citizen turn 7680x1440 into 8960x1800.
6. Align the displays in one horizontal row with the centre as primary.
7. Extract the complete release ZIP outside the game folder.
8. Run `Run-StarCitizenTripleScreen.cmd`, then launch the game normally from RSI Launcher.

If `2560x1440` does not appear for a side monitor, reopen **DSR - Factors** and
confirm that `1.78x` remained enabled before starting the wrapper.

The default automatic mode adapts to the Windows virtual desktop. Manual X/Y/
Width/Height values support other geometries or excluding an auxiliary display.
This remains one very wide camera/render surface, not three separately projected
cameras, so edge stretching and wide HUD/menu placement are game limitations.

This is a public beta. The initial 7680x1440 layout is verified; reports from
other monitor counts, resolutions, and arrangements are very welcome. Please
include effective resolutions, Windows scale percentages, layout coordinates,
and a sanitized wrapper log.

The original mixed-resolution X4 guide and tool are here:
https://www.reddit.com/r/X4Foundations/comments/1vfqbe5/guide_opensource_tool_mixedresolution_triple/
