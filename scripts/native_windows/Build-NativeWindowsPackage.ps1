[CmdletBinding()]
param(
    [switch]$SkipFlutterBuild,
    [switch]$SkipSidecarBuild,
    [string]$PyInstallerPath,
    [string]$Version = '2.0.0'
)

$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$nativeRoot = Join-Path $sourceRoot 'native_windows'
$flutterRelease = Join-Path $nativeRoot 'build\windows\x64\runner\Release'
$flutterExe = Join-Path $flutterRelease 'OpenHUB.exe'
$specPath = Join-Path $PSScriptRoot 'openhub_backend.spec'
$sidecarBuildRoot = Join-Path $nativeRoot 'build\native_sidecar'
$sidecarWork = Join-Path $sidecarBuildRoot 'work'
$sidecarDist = Join-Path $sidecarBuildRoot 'dist'
$sidecarSource = Join-Path $sidecarDist 'openhub-backend'
$sidecarExe = Join-Path $sidecarSource 'openhub-backend.exe'

if (-not $SkipFlutterBuild) {
    Push-Location $nativeRoot
    try {
        $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
        $bundledDart = Join-Path (Split-Path -Parent $flutterCommand) 'cache\dart-sdk\bin\dart.exe'
        if (Test-Path -LiteralPath $bundledDart -PathType Leaf) {
            $dartCommand = $bundledDart
        }
        else {
            $dartCommand = (Get-Command dart -ErrorAction Stop).Source
        }
        & $dartCommand 'tool\generate_openhub_icon.dart'
        if ($LASTEXITCODE -ne 0) {
            throw "OpenHUB icon generation failed with exit code $LASTEXITCODE."
        }
        & flutter build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter release build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $flutterExe -PathType Leaf)) {
    throw "Flutter release executable is missing: $flutterExe"
}

if (-not $SkipSidecarBuild) {
    if ([string]::IsNullOrWhiteSpace($PyInstallerPath)) {
        $resolvedPyInstaller = Get-Command pyinstaller -ErrorAction Stop
        $PyInstallerPath = $resolvedPyInstaller.Source
    }
    $PyInstallerPath = (Resolve-Path -LiteralPath $PyInstallerPath).Path

    New-Item -ItemType Directory -Path $sidecarWork -Force | Out-Null
    New-Item -ItemType Directory -Path $sidecarDist -Force | Out-Null

    Push-Location $sourceRoot
    try {
        & $PyInstallerPath `
            --noconfirm `
            --clean `
            --distpath $sidecarDist `
            --workpath $sidecarWork `
            $specPath
        if ($LASTEXITCODE -ne 0) {
            throw "PyInstaller sidecar build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $sidecarExe -PathType Leaf)) {
    throw "Pinned sidecar executable is missing after build: $sidecarExe"
}

$packageName = "OpenHUB-Windows-$Version"
$packageDistRoot = Join-Path $nativeRoot 'dist'
$packageRoot = Join-Path $packageDistRoot $packageName
$archivePath = "$packageRoot.zip"
$resolvedPackageDistRoot = [IO.Path]::GetFullPath($packageDistRoot)
$distPrefix = $resolvedPackageDistRoot.TrimEnd('\') + '\'
$resolvedPackageRoot = [IO.Path]::GetFullPath($packageRoot)
if (-not $resolvedPackageRoot.StartsWith($distPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($resolvedPackageRoot) -ne $packageName) {
    throw 'Stable native package target escaped the native dist directory.'
}
New-Item -ItemType Directory -Path $resolvedPackageDistRoot -Force | Out-Null
if (Test-Path -LiteralPath $resolvedPackageRoot) {
    Remove-Item -LiteralPath $resolvedPackageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
$backendTarget = Join-Path $packageRoot 'backend'
New-Item -ItemType Directory -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Path $backendTarget | Out-Null

Copy-Item -Path (Join-Path $flutterRelease '*') -Destination $packageRoot -Recurse -Force
Copy-Item -Path (Join-Path $sidecarSource '*') -Destination $backendTarget -Recurse -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-OpenHUB.ps1') -Destination (Join-Path $packageRoot 'Launch-OpenHUB.ps1')

$indexAssets = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter 'index.html'
if ($indexAssets) {
    throw 'Native package unexpectedly contains a React index.html asset.'
}

$metadata = @(
    'OpenHUB native Windows package'
    "Client version: $Version"
    "Backend version: $Version"
    "Built at (local): $([DateTimeOffset]::Now.ToString('o'))"
    'Startup policy: pinned local sidecar; no uvx, Git, or network resolution'
)
Set-Content -LiteralPath (Join-Path $packageRoot 'PACKAGE-INFO.txt') -Value $metadata -Encoding utf8

$hashLines = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
    Where-Object { $_.Name -ne 'SHA256SUMS.txt' } |
    Sort-Object FullName |
    ForEach-Object {
        # Windows PowerShell 5.1 runs on .NET Framework, which does not expose
        # Path.GetRelativePath. Every item here was enumerated below
        # $packageRoot, so a prefix trim is deterministic and keeps the package
        # builder compatible with both Windows PowerShell and PowerShell 7.
        $relative = $_.FullName.Substring($packageRoot.Length).TrimStart('\').Replace('\', '/')
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        "$hash  $relative"
    }
Set-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt') -Value $hashLines -Encoding ascii

Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal

$packageBytes = (Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum
$archiveBytes = (Get-Item -LiteralPath $archivePath).Length
Write-Output "PACKAGE_PATH=$packageRoot"
Write-Output "PACKAGE_BYTES=$packageBytes"
Write-Output "PACKAGE_ARCHIVE=$archivePath"
Write-Output "PACKAGE_ARCHIVE_BYTES=$archiveBytes"
Write-Output "BACKEND_EXE=$backendTarget\openhub-backend.exe"
