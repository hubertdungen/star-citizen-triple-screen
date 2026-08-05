# Star Citizen Triple Screen v0.1.0-beta

Initial public beta of the external-only Star Citizen multi-monitor wrapper.

## Verified setup

- Star Citizen LIVE 4.9.0 on Windows;
- native 2560x1440 centre display;
- two physical 1080p side displays at effective 2560x1440 through NVIDIA DSR/DLDSR;
- all three displays at 100% Windows scale;
- real 7680x1440 Windowed render surface with NVIDIA Surround disabled;
- cursor movement across the complete three-monitor span.

## Highlights

- automatic full-desktop layout plus explicit manual coordinates;
- configurable channel, install paths, target geometry, timing, and USER.cfg values;
- recovery when Star Citizen recreates its window during renderer startup;
- mixed-DPI guard and stale cursor-clip repair;
- bounded resize corrections and automatic USER.cfg backups;
- no DLL injection, graphics hook, game-memory access, binary patch, direct game
  launch, or EAC bypass.

This is a beta because only the verified layout above has received in-game proof.
Reports from different two-, three-, and four-monitor layouts are welcome.
