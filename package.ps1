param(
    [string]$Version = "0.1.0-beta"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseRoot = Join-Path $projectRoot "release"
$folderName = "StarCitizenTripleScreen-v$Version"
$packageRoot = Join-Path $releaseRoot $folderName
$zipPath = Join-Path $releaseRoot "$folderName.zip"
$zipHashPath = "$zipPath.sha256"
$releaseNotes = Join-Path $projectRoot "docs\RELEASE-NOTES-$Version.md"

if (-not (Test-Path -LiteralPath $releaseNotes)) {
    throw "Release notes were not found: $releaseNotes"
}

New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
if (Test-Path -LiteralPath $packageRoot) {
    $resolvedPackage = (Resolve-Path -LiteralPath $packageRoot).Path
    $resolvedRelease = (Resolve-Path -LiteralPath $releaseRoot).Path
    if (-not $resolvedPackage.StartsWith($resolvedRelease, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace a package outside the release directory: $resolvedPackage"
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

New-Item -ItemType Directory -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageRoot "docs") | Out-Null

foreach ($name in @(
    "StarCitizenTripleScreen.ps1",
    "StarCitizenTripleScreen.ini",
    "Run-StarCitizenTripleScreen.cmd",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "CONTRIBUTING.md",
    "SECURITY.md"
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $packageRoot
}

foreach ($name in @("ANTI-CHEAT-SAFETY.md", "CONFIGURATION.md", "GUIA-PT.md")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "docs\$name") -Destination (Join-Path $packageRoot "docs")
}
Copy-Item -LiteralPath $releaseNotes -Destination (Join-Path $packageRoot "RELEASE-NOTES.md")

$hashLines = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    "$hash  $relative"
}
$hashLines | Set-Content -LiteralPath (Join-Path $packageRoot "SHA256SUMS.txt") -Encoding ASCII

Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal -Force
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
"$zipHash  $folderName.zip" | Set-Content -LiteralPath $zipHashPath -Encoding ASCII

Write-Output "Packaged $zipPath"
