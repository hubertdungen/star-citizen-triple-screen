# Configuration reference

All runtime behavior is controlled by `StarCitizenTripleScreen.ini`. The script
contains tested defaults, but it does not assume that every user has the same
three-monitor geometry.

## Automatic layout

```ini
[Layout]
Mode=AutoUnion
```

`AutoUnion` spans the complete Windows virtual desktop. It adapts to the number,
positions, and effective resolutions of connected monitors. It is best for a
single horizontal row where every target display has the same effective height.

For example, three effective 2560x1440 displays arranged left/centre/right become:

```text
X=-2560, Y=0, Width=7680, Height=1440
```

Two 1920x1080 displays arranged side by side become a 3840x1080 target without
editing coordinates.

## Manual layout

Use Manual mode for asymmetric arrangements, custom render sizes, or when an
extra display should not be part of the game surface:

```ini
[Layout]
Mode=Manual
X=-1920
Y=0
Width=6400
Height=1440
```

The example spans a 1920-wide left region, a 2560-wide centre, and a 1920-wide
right region. The exact coordinates must match Windows Display Settings.

`PrimaryHeightUnionWidth` is also available: it uses the complete desktop width
but the primary monitor's top coordinate and height.

## Mixed physical resolutions

The wrapper creates one wide render surface. It cannot create independent camera
projections or independently scale portions of a frame.

Different physical monitor resolutions can work when the GPU exposes compatible
effective heights, for example two physical 1080p sides using NVIDIA DSR/DLDSR
at an effective 2560x1440 beside a native 2560x1440 centre.

Every display intersecting the target must use **100% Windows scale**. Mixed DPI
such as 125% sides plus a 100% centre caused Star Citizen to enlarge a requested
7680x1440 Windowed surface to 8960x1800. The wrapper detects this before launch.

## Resolution and USER.cfg

```ini
[UserCfg]
Width=auto
Height=auto
WindowMode=0
```

`auto` copies the calculated target dimensions into `r_Width` and `r_Height`.
Explicit numeric values remain available for experiments. Windowed mode is used
internally; the wrapper removes the normal frame through Windows APIs.

## Window stabilization and input

`WaitSeconds`, `StabilizeSeconds`, `IntervalMilliseconds`, `TolerancePixels`, and
`MaxCorrections` are configurable. Bounds and stop conditions prevent unbounded
resize loops.

`RepairCursorClip=true` expands a stale Windows `ClipCursor` rectangle to the
target, fixing menus trapped on the monitor where Star Citizen first opened.
