$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectRoot "StarCitizenTripleScreen.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("StarCitizenTripleScreen-test-{0}" -f [Guid]::NewGuid().ToString("N"))
$installRoot = Join-Path $testRoot "StarCitizen"
$channelPath = Join-Path $installRoot "TEST"
$configPath = Join-Path $testRoot "test.ini"

try {
    New-Item -ItemType Directory -Path $channelPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $channelPath "USER.cfg") -Encoding ASCII -Value "example_setting = 1"

    $config = @"
[Game]
Channel=TEST
InstallRoot=$installRoot
ProcessName=StarCitizenTripleScreenTestProcess

[Layout]
Mode=Manual
X=-300
Y=10
Width=900
Height=200
WarnOnHeightMismatch=false

[Display]
Require100PercentScale=false

[Window]
RemoveBorders=true
StabilizeSeconds=1
IntervalMilliseconds=10
TolerancePixels=2
MaxCorrections=1
ContinuousWatch=false

[Input]
RepairCursorClip=true

[UserCfg]
Enabled=true
Backup=true
SetReadOnly=false
ConRestricted=0
WindowMode=0
Width=auto
Height=auto
SetFullscreenFlags=false
"@
    Set-Content -LiteralPath $configPath -Encoding ASCII -Value $config

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Config $configPath -DryRun
    if ($LASTEXITCODE -ne 0) {
        throw "Dry-run process failed with exit code $LASTEXITCODE"
    }

    $userCfg = Get-Content -Raw -LiteralPath (Join-Path $channelPath "USER.cfg")
    foreach ($expected in @(
        "example_setting = 1",
        "Con_Restricted = 0",
        "r_WindowMode = 0",
        "r_Width = 900",
        "r_Height = 200"
    )) {
        if (-not $userCfg.Contains($expected)) {
            throw "Generated USER.cfg is missing: $expected"
        }
    }

    $backups = @(Get-ChildItem -LiteralPath $channelPath -Filter "USER.cfg.StarCitizenTripleScreen.backup-*")
    if ($backups.Count -ne 1) {
        throw "Expected one USER.cfg backup, found $($backups.Count)."
    }

    $source = Get-Content -Raw -LiteralPath $scriptPath
    if (-not $source.Contains("Star Citizen recreated its window")) {
        throw "Window-recreation recovery path is missing."
    }
    if (-not $source.Contains("Expanding cursor clip")) {
        throw "Cursor-clip recovery path is missing."
    }
    if (-not $source.Contains("Star Citizen can enlarge and crop a custom Windowed surface")) {
        throw "Mixed-DPI guard is missing."
    }

    Write-Output "PASS: disposable USER.cfg dry run, window guards, and mixed-DPI guard"
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $resolvedTempRoot = (Resolve-Path -LiteralPath ([System.IO.Path]::GetTempPath())).Path
        if (-not $resolvedTestRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove test path outside the temporary directory: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
