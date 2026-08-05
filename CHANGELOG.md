# Changelog

## 0.1.0-beta - 2026-08-05

- Move development out of the Star Citizen installation into a local Git project.
- Default the renderer to real Windowed mode (`r_WindowMode = 0`) while keeping
  the outer window visually borderless through normal Windows APIs.
- Recover when Star Citizen recreates its top-level window during renderer startup.
- Request per-monitor-v2 DPI awareness before reading monitor geometry.
- Repair a stale Windows cursor clip that can confine menus to the left monitor.
- Detect non-100% Windows display scaling and stop before Star Citizen expands
  a 7680x1440 Windowed surface into 8960x1800.
- Default to automatic virtual-desktop discovery while retaining explicit Manual
  coordinates for asymmetric layouts or excluding auxiliary displays.
- Validate target dimensions and make the game-window wait timeout configurable.
- Add a disposable dry-run test for `USER.cfg` generation.
