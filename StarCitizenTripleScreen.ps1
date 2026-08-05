param(
    [string]$Config = "",
    [switch]$ApplyUserCfg,
    [switch]$NoUserCfg,
    [switch]$RestoreUserCfg,
    [switch]$LaunchRSILauncher,
    [switch]$Watch,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$isWindowsVariable = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
if ($isWindowsVariable) {
    $runningOnWindows = [bool]$isWindowsVariable.Value
} else {
    $runningOnWindows = [Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

if (-not $runningOnWindows) {
    throw "StarCitizenTripleScreen.ps1 must be run on Windows, on the gaming PC."
}

if ([string]::IsNullOrWhiteSpace($Config)) {
    $Config = Join-Path $PSScriptRoot "StarCitizenTripleScreen.ini"
}

$LogRoot = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$LogPath = Join-Path $LogRoot ("StarCitizenTripleScreen-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line
}

function Read-IniFile {
    param([string]$Path)

    $data = @{}
    $section = "default"
    $data[$section] = @{}

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file was not found: $Path"
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line.StartsWith(";") -or $line.StartsWith("#")) { continue }

        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1].Trim()
            if (-not $data.ContainsKey($section)) {
                $data[$section] = @{}
            }
            continue
        }

        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { continue }

        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        $data[$section][$key] = $value
    }

    return $data
}

function Get-IniValue {
    param(
        [hashtable]$Ini,
        [string]$Section,
        [string]$Key,
        [string]$Default
    )
    if ($Ini.ContainsKey($Section) -and $Ini[$Section].ContainsKey($Key)) {
        return [string]$Ini[$Section][$Key]
    }
    return $Default
}

function Get-IniBool {
    param(
        [hashtable]$Ini,
        [string]$Section,
        [string]$Key,
        [bool]$Default
    )
    $value = (Get-IniValue $Ini $Section $Key ([string]$Default)).Trim().ToLowerInvariant()
    switch ($value) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "on" { return $true }
        "0" { return $false }
        "false" { return $false }
        "no" { return $false }
        "off" { return $false }
        default { return $Default }
    }
}

function Get-IniInt {
    param(
        [hashtable]$Ini,
        [string]$Section,
        [string]$Key,
        [int]$Default
    )
    $value = Get-IniValue $Ini $Section $Key ([string]$Default)
    $parsed = 0
    if ([int]::TryParse($value, [ref]$parsed)) {
        return $parsed
    }
    return $Default
}

if (-not ("StarCitizenTripleScreen.Native" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace StarCitizenTripleScreen {
    public static class Native {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        public struct MonitorScaleInfo {
            public int X;
            public int Y;
            public int Width;
            public int Height;
            public int Scale;
        }

        private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT rect, IntPtr data);

        [DllImport("user32.dll")]
        private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc callback, IntPtr data);

        [DllImport("shcore.dll")]
        private static extern int GetScaleFactorForMonitor(IntPtr hMonitor, out int scale);

        public static MonitorScaleInfo[] GetMonitorScaleInfo() {
            var results = new System.Collections.Generic.List<MonitorScaleInfo>();
            MonitorEnumProc callback = delegate(IntPtr monitor, IntPtr hdc, ref RECT rect, IntPtr data) {
                int scale = 100;
                GetScaleFactorForMonitor(monitor, out scale);
                results.Add(new MonitorScaleInfo {
                    X = rect.Left,
                    Y = rect.Top,
                    Width = rect.Right - rect.Left,
                    Height = rect.Bottom - rect.Top,
                    Scale = scale
                });
                return true;
            };
            EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
            return results.ToArray();
        }

        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

        [DllImport("user32.dll")]
        public static extern bool IsWindow(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetClipCursor(out RECT lpRect);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool ClipCursor(ref RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(
            IntPtr hWnd,
            IntPtr hWndInsertAfter,
            int X,
            int Y,
            int cx,
            int cy,
            UInt32 uFlags);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    }
}
"@
}

Add-Type -AssemblyName System.Windows.Forms
$DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = [IntPtr](-4)
if (-not [StarCitizenTripleScreen.Native]::SetProcessDpiAwarenessContext($DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {
    # Older Windows versions do not expose per-monitor-v2 awareness. The legacy
    # fallback is still better than DPI-virtualized monitor dimensions.
    [void][StarCitizenTripleScreen.Native]::SetProcessDPIAware()
}

function Get-TargetRectangle {
    param([hashtable]$Ini)

    $mode = Get-IniValue $Ini "Layout" "Mode" "AutoUnion"
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if ($screens.Count -lt 1) {
        throw "No Windows screens were detected."
    }

    Write-Log ("Detected {0} screen(s)." -f $screens.Count)
    foreach ($screen in $screens) {
        $b = $screen.Bounds
        Write-Log ("Screen: primary={0} x={1} y={2} width={3} height={4}" -f $screen.Primary, $b.X, $b.Y, $b.Width, $b.Height)
    }

    if ($mode -ieq "Manual") {
        return [pscustomobject]@{
            X = Get-IniInt $Ini "Layout" "X" -2560
            Y = Get-IniInt $Ini "Layout" "Y" 0
            Width = Get-IniInt $Ini "Layout" "Width" 7680
            Height = Get-IniInt $Ini "Layout" "Height" 1440
        }
    }

    $left = ($screens | ForEach-Object { $_.Bounds.Left } | Measure-Object -Minimum).Minimum
    $top = ($screens | ForEach-Object { $_.Bounds.Top } | Measure-Object -Minimum).Minimum
    $right = ($screens | ForEach-Object { $_.Bounds.Right } | Measure-Object -Maximum).Maximum
    $bottom = ($screens | ForEach-Object { $_.Bounds.Bottom } | Measure-Object -Maximum).Maximum

    if ($mode -ieq "AutoUnion") {
        return [pscustomobject]@{
            X = [int]$left
            Y = [int]$top
            Width = [int]($right - $left)
            Height = [int]($bottom - $top)
        }
    }

    if ($mode -ieq "PrimaryHeightUnionWidth") {
        $primary = $screens | Where-Object { $_.Primary } | Select-Object -First 1
        return [pscustomobject]@{
            X = [int]$left
            Y = [int]$primary.Bounds.Top
            Width = [int]($right - $left)
            Height = [int]$primary.Bounds.Height
        }
    }

    throw "Unknown Layout.Mode: $mode"
}

function Test-MonitorHeights {
    param(
        [hashtable]$Ini,
        [object]$Target
    )
    if (-not (Get-IniBool $Ini "Layout" "WarnOnHeightMismatch" $true)) { return }

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        if (-not (Test-RectanglesIntersect $screen.Bounds $Target)) { continue }
        if ($screen.Bounds.Height -ne $Target.Height) {
            Write-Log ("Monitor height mismatch: screen at x={0} has height={1}, target height={2}. Use an effective resolution with the target height, or define a different manual target." -f $screen.Bounds.X, $screen.Bounds.Height, $Target.Height) "WARN"
        }
    }
}

function Test-MonitorScales {
    param(
        [hashtable]$Ini,
        [object]$Target
    )

    $require100Percent = Get-IniBool $Ini "Display" "Require100PercentScale" $true
    $non100Percent = New-Object "System.Collections.Generic.List[Object]"

    foreach ($monitor in [StarCitizenTripleScreen.Native]::GetMonitorScaleInfo()) {
        Write-Log ("Monitor scale: x={0} y={1} width={2} height={3} scale={4}%" -f $monitor.X, $monitor.Y, $monitor.Width, $monitor.Height, $monitor.Scale)
        if (-not (Test-RectanglesIntersect $monitor $Target)) { continue }
        if ($monitor.Scale -ne 100) {
            $non100Percent.Add($monitor)
        }
    }

    if ($non100Percent.Count -gt 0) {
        $message = ("Windows display scaling is not 100% on every monitor intersecting the {0}x{1} target. Star Citizen can enlarge and crop a custom Windowed surface in mixed-DPI layouts. Set Scale to 100% on the displays used by the target, then sign out/in if Windows requests it." -f $Target.Width, $Target.Height)
        if ($require100Percent) {
            throw $message
        }
        Write-Log $message "WARN"
    }
}

function Test-RectanglesIntersect {
    param(
        [object]$First,
        [object]$Second
    )

    $firstRight = if ($null -ne $First.Right) { [int]$First.Right } else { [int]($First.X + $First.Width) }
    $firstBottom = if ($null -ne $First.Bottom) { [int]$First.Bottom } else { [int]($First.Y + $First.Height) }
    $secondRight = if ($null -ne $Second.Right) { [int]$Second.Right } else { [int]($Second.X + $Second.Width) }
    $secondBottom = if ($null -ne $Second.Bottom) { [int]$Second.Bottom } else { [int]($Second.Y + $Second.Height) }

    return ([int]$First.X -lt $secondRight) -and
        ($firstRight -gt [int]$Second.X) -and
        ([int]$First.Y -lt $secondBottom) -and
        ($firstBottom -gt [int]$Second.Y)
}

function Test-TargetRectangle {
    param([object]$Target)

    if ($Target.Width -le 0 -or $Target.Height -le 0) {
        throw "The target rectangle must have a positive Width and Height."
    }
    if ($Target.Width -gt 32768 -or $Target.Height -gt 32768) {
        throw "The target rectangle exceeds the wrapper safety limit of 32768 pixels per dimension."
    }
}

function Find-StarCitizenInstallRoot {
    param(
        [string]$ConfiguredRoot,
        [string]$Channel
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredRoot)) {
        return $ConfiguredRoot
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    $candidates = @(
        (Join-Path $env:ProgramFiles "Roberts Space Industries\StarCitizen"),
        $(if ($programFilesX86) { Join-Path $programFilesX86 "Roberts Space Industries\StarCitizen" }),
        "C:\Program Files\Roberts Space Industries\StarCitizen",
        "D:\Roberts Space Industries\StarCitizen",
        "E:\Roberts Space Industries\StarCitizen",
        "F:\Roberts Space Industries\StarCitizen"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate $Channel)) {
            return $candidate
        }
    }

    return ""
}

function Find-RsiLauncher {
    param([string]$ConfiguredPath)

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) {
        return $ConfiguredPath
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    $candidates = @(
        (Join-Path $env:ProgramFiles "Roberts Space Industries\RSI Launcher\RSI Launcher.exe"),
        $(if ($programFilesX86) { Join-Path $programFilesX86 "Roberts Space Industries\RSI Launcher\RSI Launcher.exe" }),
        "C:\Program Files\Roberts Space Industries\RSI Launcher\RSI Launcher.exe",
        "D:\Roberts Space Industries\RSI Launcher\RSI Launcher.exe",
        "E:\Roberts Space Industries\RSI Launcher\RSI Launcher.exe",
        "F:\Roberts Space Industries\RSI Launcher\RSI Launcher.exe"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return ""
}

function Get-ChannelPath {
    param(
        [hashtable]$Ini,
        [string]$Channel
    )

    $configuredRoot = Get-IniValue $Ini "Game" "InstallRoot" ""
    $root = Find-StarCitizenInstallRoot $configuredRoot $Channel
    if ([string]::IsNullOrWhiteSpace($root)) {
        return ""
    }

    return Join-Path $root $Channel
}

function Set-UserCfg {
    param(
        [hashtable]$Ini,
        [object]$Target
    )

    $channel = Get-IniValue $Ini "Game" "Channel" "LIVE"
    $channelPath = Get-ChannelPath $Ini $channel
    if ([string]::IsNullOrWhiteSpace($channelPath) -or -not (Test-Path -LiteralPath $channelPath)) {
        Write-Log "Could not find StarCitizen\$channel. Set Game.InstallRoot in StarCitizenTripleScreen.ini if the game is installed elsewhere." "WARN"
        return
    }

    $cfgPath = Join-Path $channelPath "USER.cfg"
    $backupEnabled = Get-IniBool $Ini "UserCfg" "Backup" $true

    if ((Test-Path -LiteralPath $cfgPath) -and $backupEnabled) {
        $backupPath = Join-Path $channelPath ("USER.cfg.StarCitizenTripleScreen.backup-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
        Copy-Item -LiteralPath $cfgPath -Destination $backupPath -Force
        Write-Log "Backed up USER.cfg to $backupPath"
    }

    $widthValue = Get-IniValue $Ini "UserCfg" "Width" "auto"
    $heightValue = Get-IniValue $Ini "UserCfg" "Height" "auto"
    if ($widthValue -ieq "auto") { $widthValue = [string]$Target.Width }
    if ($heightValue -ieq "auto") { $heightValue = [string]$Target.Height }

    $desired = New-Object "System.Collections.Generic.Dictionary[System.String,System.String]" ([System.StringComparer]::OrdinalIgnoreCase)
    $desired["Con_Restricted"] = Get-IniValue $Ini "UserCfg" "ConRestricted" "0"
    $desired["r_WindowMode"] = Get-IniValue $Ini "UserCfg" "WindowMode" "0"
    $desired["r_Width"] = $widthValue
    $desired["r_Height"] = $heightValue

    if (Get-IniBool $Ini "UserCfg" "SetFullscreenFlags" $false) {
        $desired["r_Fullscreen"] = Get-IniValue $Ini "UserCfg" "Fullscreen" "0"
        $desired["r_FullscreenWindow"] = Get-IniValue $Ini "UserCfg" "FullscreenWindow" "0"
        $desired["r_BorderlessWindow"] = Get-IniValue $Ini "UserCfg" "BorderlessWindow" "0"
    }

    $lines = New-Object "System.Collections.Generic.List[System.String]"
    if (Test-Path -LiteralPath $cfgPath) {
        foreach ($line in Get-Content -LiteralPath $cfgPath) {
            $match = [regex]::Match($line, '^\s*([^;#][^=]+?)\s*=')
            if ($match.Success) {
                $key = $match.Groups[1].Value.Trim()
                if ($desired.ContainsKey($key)) {
                    $lines.Add(("{0} = {1}" -f $key, $desired[$key]))
                    $desired.Remove($key) | Out-Null
                    continue
                }
            }
            $lines.Add($line)
        }
    } else {
        $lines.Add("; Created by StarCitizenTripleScreen.ps1")
    }

    if ($desired.Count -gt 0) {
        $lines.Add("")
        $lines.Add("; StarCitizenTripleScreen display settings")
        foreach ($key in $desired.Keys) {
            $lines.Add(("{0} = {1}" -f $key, $desired[$key]))
        }
    }

    Set-Content -LiteralPath $cfgPath -Value $lines -Encoding ASCII
    Write-Log "Updated $cfgPath"

    if (Get-IniBool $Ini "UserCfg" "SetReadOnly" $false) {
        (Get-Item -LiteralPath $cfgPath).IsReadOnly = $true
        Write-Log "Set USER.cfg read-only because UserCfg.SetReadOnly=true." "WARN"
    }
}

function Restore-UserCfgBackup {
    param([hashtable]$Ini)

    $channel = Get-IniValue $Ini "Game" "Channel" "LIVE"
    $channelPath = Get-ChannelPath $Ini $channel
    if ([string]::IsNullOrWhiteSpace($channelPath) -or -not (Test-Path -LiteralPath $channelPath)) {
        throw "Could not find StarCitizen\$channel. Set Game.InstallRoot in StarCitizenTripleScreen.ini."
    }

    $backup = Get-ChildItem -LiteralPath $channelPath -Filter "USER.cfg.StarCitizenTripleScreen.backup-*" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $backup) {
        throw "No StarCitizenTripleScreen USER.cfg backup was found in $channelPath"
    }

    $cfgPath = Join-Path $channelPath "USER.cfg"
    if (Test-Path -LiteralPath $cfgPath) {
        (Get-Item -LiteralPath $cfgPath).IsReadOnly = $false
    }
    Copy-Item -LiteralPath $backup.FullName -Destination $cfgPath -Force
    Write-Log "Restored USER.cfg from $($backup.FullName)"
}

function Get-StarCitizenWindow {
    param(
        [string]$ProcessName,
        [int]$WaitSeconds
    )

    $name = $ProcessName
    if ($name.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
        $name = $name.Substring(0, $name.Length - 4)
    }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline) {
        $processes = [System.Diagnostics.Process]::GetProcessesByName($name)
        foreach ($process in $processes) {
            try {
                $process.Refresh()
                if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                    return [pscustomobject]@{
                        Process = $process
                        Handle = $process.MainWindowHandle
                    }
                }
            } catch {
                Write-Log "Skipping a process that disappeared while probing: $($_.Exception.Message)" "WARN"
            }
        }

        Start-Sleep -Milliseconds 500
    }

    throw "Could not find a visible $ProcessName window within $WaitSeconds seconds."
}

function Get-WindowRectangle {
    param([IntPtr]$Handle)

    if ($Handle -eq [IntPtr]::Zero -or -not [StarCitizenTripleScreen.Native]::IsWindow($Handle)) {
        return $null
    }

    $rect = New-Object "StarCitizenTripleScreen.Native+RECT"
    $ok = [StarCitizenTripleScreen.Native]::GetWindowRect($Handle, [ref]$rect)
    if (-not $ok) {
        return $null
    }

    return [pscustomobject]@{
        X = $rect.Left
        Y = $rect.Top
        Width = $rect.Right - $rect.Left
        Height = $rect.Bottom - $rect.Top
    }
}

function Test-RectangleClose {
    param(
        [object]$Actual,
        [object]$Target,
        [int]$Tolerance
    )

    return ([Math]::Abs($Actual.X - $Target.X) -le $Tolerance) -and
        ([Math]::Abs($Actual.Y - $Target.Y) -le $Tolerance) -and
        ([Math]::Abs($Actual.Width - $Target.Width) -le $Tolerance) -and
        ([Math]::Abs($Actual.Height - $Target.Height) -le $Tolerance)
}

function Get-CursorClipRectangle {
    $rect = New-Object "StarCitizenTripleScreen.Native+RECT"
    $ok = [StarCitizenTripleScreen.Native]::GetClipCursor([ref]$rect)
    if (-not $ok) { return $null }

    return [pscustomobject]@{
        X = $rect.Left
        Y = $rect.Top
        Width = $rect.Right - $rect.Left
        Height = $rect.Bottom - $rect.Top
    }
}

function Set-CursorClipRectangle {
    param([object]$Target)

    $rect = New-Object "StarCitizenTripleScreen.Native+RECT"
    $rect.Left = [int]$Target.X
    $rect.Top = [int]$Target.Y
    $rect.Right = [int]($Target.X + $Target.Width)
    $rect.Bottom = [int]($Target.Y + $Target.Height)

    if (-not [StarCitizenTripleScreen.Native]::ClipCursor([ref]$rect)) {
        throw "ClipCursor failed while applying the target desktop rectangle."
    }
}

function Set-BorderlessWindow {
    param(
        [IntPtr]$Handle,
        [bool]$RemoveBorders
    )

    if (-not $RemoveBorders) { return }

    $GWL_STYLE = -16
    $GWL_EXSTYLE = -20

    $WS_CAPTION = 0x00C00000
    $WS_THICKFRAME = 0x00040000
    $WS_MINIMIZEBOX = 0x00020000
    $WS_MAXIMIZEBOX = 0x00010000
    $WS_SYSMENU = 0x00080000
    $WS_EX_DLGMODALFRAME = 0x00000001
    $WS_EX_CLIENTEDGE = 0x00000200
    $WS_EX_STATICEDGE = 0x00020000

    $style = [StarCitizenTripleScreen.Native]::GetWindowLong($Handle, $GWL_STYLE)
    $removeStyle = $WS_CAPTION -bor $WS_THICKFRAME -bor $WS_MINIMIZEBOX -bor $WS_MAXIMIZEBOX -bor $WS_SYSMENU
    $newStyle = $style -band (-bnot $removeStyle)
    if ($newStyle -ne $style) {
        [void][StarCitizenTripleScreen.Native]::SetWindowLong($Handle, $GWL_STYLE, $newStyle)
    }

    $exStyle = [StarCitizenTripleScreen.Native]::GetWindowLong($Handle, $GWL_EXSTYLE)
    $removeExStyle = $WS_EX_DLGMODALFRAME -bor $WS_EX_CLIENTEDGE -bor $WS_EX_STATICEDGE
    $newExStyle = $exStyle -band (-bnot $removeExStyle)
    if ($newExStyle -ne $exStyle) {
        [void][StarCitizenTripleScreen.Native]::SetWindowLong($Handle, $GWL_EXSTYLE, $newExStyle)
    }
}

function Apply-WindowRectangle {
    param(
        [IntPtr]$Handle,
        [object]$Target,
        [bool]$RemoveBorders
    )

    Set-BorderlessWindow $Handle $RemoveBorders

    $SW_SHOWNORMAL = 1
    $SWP_NOZORDER = 0x0004
    $SWP_NOACTIVATE = 0x0010
    $SWP_FRAMECHANGED = 0x0020
    $SWP_SHOWWINDOW = 0x0040
    $SWP_NOOWNERZORDER = 0x0200
    $flags = $SWP_NOZORDER -bor $SWP_NOACTIVATE -bor $SWP_FRAMECHANGED -bor $SWP_SHOWWINDOW -bor $SWP_NOOWNERZORDER

    [void][StarCitizenTripleScreen.Native]::ShowWindow($Handle, $SW_SHOWNORMAL)
    $ok = [StarCitizenTripleScreen.Native]::SetWindowPos(
        $Handle,
        [IntPtr]::Zero,
        [int]$Target.X,
        [int]$Target.Y,
        [int]$Target.Width,
        [int]$Target.Height,
        [uint32]$flags)

    if (-not $ok) {
        throw "SetWindowPos failed for handle $Handle"
    }
}

function Stabilize-Window {
    param(
        [System.Diagnostics.Process]$Process,
        [object]$Target,
        [hashtable]$Ini,
        [bool]$Continuous
    )

    $removeBorders = Get-IniBool $Ini "Window" "RemoveBorders" $true
    $seconds = Get-IniInt $Ini "Window" "StabilizeSeconds" 90
    $intervalMs = Get-IniInt $Ini "Window" "IntervalMilliseconds" 1000
    $tolerance = Get-IniInt $Ini "Window" "TolerancePixels" 2
    $maxCorrections = Get-IniInt $Ini "Window" "MaxCorrections" 30
    $repairCursorClip = Get-IniBool $Ini "Input" "RepairCursorClip" $true

    $corrections = 0
    $deadline = (Get-Date).AddSeconds($seconds)
    $handle = [IntPtr]::Zero
    $missingHandleLogged = $false

    do {
        try {
            $Process.Refresh()
            if ($Process.HasExited) {
                Write-Log "Star Citizen exited while the wrapper was watching the window." "WARN"
                return
            }
        } catch {
            Write-Log "Star Citizen disappeared while the wrapper was watching the window." "WARN"
            return
        }

        $currentHandle = $Process.MainWindowHandle
        if ($currentHandle -eq [IntPtr]::Zero -or -not [StarCitizenTripleScreen.Native]::IsWindow($currentHandle)) {
            if (-not $missingHandleLogged) {
                Write-Log "Star Citizen temporarily has no visible main window; waiting for window recreation." "WARN"
                $missingHandleLogged = $true
            }
            Start-Sleep -Milliseconds $intervalMs
            if ($Continuous) { $alive = $true } else { $alive = (Get-Date) -lt $deadline }
            continue
        }

        if ($currentHandle -ne $handle) {
            if ($handle -ne [IntPtr]::Zero) {
                Write-Log ("Star Citizen recreated its window: old handle={0}, new handle={1}. Continuing with the new window." -f $handle, $currentHandle) "WARN"
            }
            $handle = $currentHandle
            $missingHandleLogged = $false
        }

        $actual = Get-WindowRectangle $handle
        if ($null -eq $actual) {
            Write-Log ("Window handle {0} became invalid during inspection; reacquiring it." -f $handle) "WARN"
            $handle = [IntPtr]::Zero
            Start-Sleep -Milliseconds $intervalMs
            if ($Continuous) { $alive = $true } else { $alive = (Get-Date) -lt $deadline }
            continue
        }

        if (-not (Test-RectangleClose $actual $Target $tolerance)) {
            if ($corrections -ge $maxCorrections) {
                Write-Log "Star Citizen keeps changing the window rectangle after $corrections corrections. Stopping to avoid a resize loop." "WARN"
                return
            }

            $corrections++
            Write-Log ("Applying target rectangle x={0} y={1} width={2} height={3}; previous x={4} y={5} width={6} height={7}" -f $Target.X, $Target.Y, $Target.Width, $Target.Height, $actual.X, $actual.Y, $actual.Width, $actual.Height)
            try {
                Apply-WindowRectangle $handle $Target $removeBorders
            } catch {
                Write-Log ("The window changed while applying the rectangle; reacquiring it. {0}" -f $_.Exception.Message) "WARN"
                $handle = [IntPtr]::Zero
            }
        }

        if ($repairCursorClip) {
            $cursorClip = Get-CursorClipRectangle
            if ($null -ne $cursorClip -and -not (Test-RectangleClose $cursorClip $Target $tolerance)) {
                Write-Log ("Expanding cursor clip to x={0} y={1} width={2} height={3}; previous x={4} y={5} width={6} height={7}" -f $Target.X, $Target.Y, $Target.Width, $Target.Height, $cursorClip.X, $cursorClip.Y, $cursorClip.Width, $cursorClip.Height)
                Set-CursorClipRectangle $Target
            }
        }

        Start-Sleep -Milliseconds $intervalMs

        if ($Continuous) {
            $alive = $true
        } else {
            $alive = (Get-Date) -lt $deadline
        }
    } while ($alive)

    $Process.Refresh()
    $handle = $Process.MainWindowHandle
    $finalRect = Get-WindowRectangle $handle
    if ($null -ne $finalRect -and (Test-RectangleClose $finalRect $Target $tolerance)) {
        Write-Log ("Window is stable at x={0} y={1} width={2} height={3} after {4} correction(s)." -f $finalRect.X, $finalRect.Y, $finalRect.Width, $finalRect.Height, $corrections)
    } elseif ($null -eq $finalRect) {
        Write-Log "Star Citizen had no valid main window when stabilization ended." "WARN"
    } else {
        Write-Log ("Window did not settle exactly. Final x={0} y={1} width={2} height={3}." -f $finalRect.X, $finalRect.Y, $finalRect.Width, $finalRect.Height) "WARN"
    }
}

function Start-RsiLauncherIfRequested {
    param(
        [hashtable]$Ini,
        [bool]$LaunchRequested
    )

    $autoLaunch = Get-IniBool $Ini "Game" "AutoLaunchLauncher" $false
    if (-not ($LaunchRequested -or $autoLaunch)) {
        Write-Log "Open the RSI Launcher normally and launch Star Citizen. This wrapper is waiting for the game window."
        return
    }

    $launcherPath = Find-RsiLauncher (Get-IniValue $Ini "Game" "LauncherPath" "")
    if ([string]::IsNullOrWhiteSpace($launcherPath) -or -not (Test-Path -LiteralPath $launcherPath)) {
        Write-Log "RSI Launcher was not found. Open it manually, or set Game.LauncherPath in the INI." "WARN"
        return
    }

    Write-Log "Starting RSI Launcher: $launcherPath"
    Start-Process -FilePath $launcherPath | Out-Null
}

$ini = Read-IniFile $Config
Write-Log "Star Citizen Triple Screen external wrapper started."
Write-Log "Safety mode: no DLL injection, no game memory access, no EAC bypass, no direct StarCitizen.exe launch."
Write-Log "Config: $Config"

if ($RestoreUserCfg) {
    Restore-UserCfgBackup $ini
    Write-Log "Done."
    exit 0
}

$target = Get-TargetRectangle $ini
Write-Log ("Target rectangle: x={0} y={1} width={2} height={3}" -f $target.X, $target.Y, $target.Width, $target.Height)
Test-TargetRectangle $target
Test-MonitorHeights $ini $target
Test-MonitorScales $ini $target

$userCfgEnabled = (Get-IniBool $ini "UserCfg" "Enabled" $true) -or $ApplyUserCfg
if ($NoUserCfg) { $userCfgEnabled = $false }

if ($userCfgEnabled) {
    Set-UserCfg $ini $target
} else {
    Write-Log "USER.cfg update skipped."
}

if ($DryRun) {
    Write-Log "Dry run complete. No launcher or window changes were performed."
    exit 0
}

Start-RsiLauncherIfRequested $ini $LaunchRSILauncher

$processName = Get-IniValue $ini "Game" "ProcessName" "StarCitizen"
$waitSeconds = Get-IniInt $ini "Window" "WaitSeconds" 240
if ($waitSeconds -le 0) { throw "Window.WaitSeconds must be greater than zero." }
Write-Log "Waiting up to $waitSeconds seconds for a visible $processName window."
$window = Get-StarCitizenWindow $processName $waitSeconds
Write-Log ("Found {0}.exe pid={1}, window handle={2}" -f $window.Process.ProcessName, $window.Process.Id, $window.Handle)

$continuous = (Get-IniBool $ini "Window" "ContinuousWatch" $false) -or $Watch
if ($continuous) {
    Write-Log "Continuous watch is enabled. Close this window after quitting Star Citizen."
}

Stabilize-Window $window.Process $target $ini $continuous
Write-Log "Done. Log written to $LogPath"
