[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$InstallRoot = (Join-Path $env:ProgramFiles 'OpenHUB'),
    [switch]$SkipShortcutCreation,
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $localArchives = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'OpenHUB-Windows-*.zip')
    if ($localArchives.Count -ne 1) {
        throw 'PackagePath was omitted and the installer directory does not contain exactly one OpenHUB-Windows-*.zip artifact.'
    }
    $PackagePath = $localArchives[0].FullName
}
$resolvedInput = (Resolve-Path -LiteralPath $PackagePath -ErrorAction Stop).Path
$resolvedRequestedInstallRoot = [IO.Path]::GetFullPath($InstallRoot)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator -and -not $SkipElevation) {
    $powershellExecutable = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $PSCommandPath + '"'),
        '-PackagePath', ('"' + $resolvedInput + '"'),
        '-InstallRoot', ('"' + $resolvedRequestedInstallRoot + '"'),
        '-SkipElevation'
    )
    if ($SkipShortcutCreation) {
        $arguments += '-SkipShortcutCreation'
    }
    $elevated = Start-Process -FilePath $powershellExecutable -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    exit $elevated.ExitCode
}

$temporaryExtractRoot = $null
$packageRoot = $resolvedInput
if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) {
    if ([IO.Path]::GetExtension($resolvedInput) -ne '.zip') {
        throw "OpenHUB package must be a directory or zip archive: $resolvedInput"
    }
    $temporaryExtractRoot = Join-Path ([IO.Path]::GetTempPath()) ('OpenHUB-install-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporaryExtractRoot | Out-Null
    Expand-Archive -LiteralPath $resolvedInput -DestinationPath $temporaryExtractRoot
    $packageRoot = $temporaryExtractRoot
}
elseif (-not (Test-Path -LiteralPath $resolvedInput -PathType Container)) {
    throw "OpenHUB package does not exist: $resolvedInput"
}

try {
    $packageName = if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) {
        [IO.Path]::GetFileNameWithoutExtension($resolvedInput)
    }
    else {
        [IO.Path]::GetFileName($resolvedInput.TrimEnd('\'))
    }
    if ($packageName -notlike 'OpenHUB-Windows-*') {
        throw "Unexpected OpenHUB package name: $packageName"
    }

    $required = @(
        'OpenHUB.exe',
        'backend\openhub-backend.exe',
        'Launch-OpenHUB.ps1',
        'PACKAGE-INFO.txt',
        'SHA256SUMS.txt'
    )
    foreach ($relativePath in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $relativePath) -PathType Leaf)) {
            throw "OpenHUB package is incomplete: $relativePath"
        }
    }

    $packagePrefix = [IO.Path]::GetFullPath($packageRoot).TrimEnd('\') + '\'
    foreach ($line in Get-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt')) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') {
            throw "Invalid SHA256SUMS entry: $line"
        }
        $expectedHash = $Matches[1]
        $relativePath = $Matches[2].Replace('/', '\')
        $resolvedFile = [IO.Path]::GetFullPath((Join-Path $packageRoot $relativePath))
        if (-not $resolvedFile.StartsWith($packagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Package hash entry escaped the package root: $relativePath"
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedFile).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Package hash mismatch: $relativePath"
        }
    }

    $installDirectory = New-Item -ItemType Directory -Path $resolvedRequestedInstallRoot -Force
    $resolvedInstallRoot = $installDirectory.FullName
    $installPrefix = $resolvedInstallRoot.TrimEnd('\') + '\'
    $appTarget = [IO.Path]::GetFullPath((Join-Path $resolvedInstallRoot 'App'))
    $releaseTarget = [IO.Path]::GetFullPath((Join-Path $resolvedInstallRoot 'Release'))
    foreach ($targetPath in @($appTarget, $releaseTarget)) {
        if (-not $targetPath.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'OpenHUB stable install target escaped the install root.'
        }
    }

    $runningOpenHub = @(Get-Process -Name 'OpenHUB' -ErrorAction SilentlyContinue)
    if ($runningOpenHub.Count -gt 0) {
        throw 'OpenHUB is running. Close the current HUB window before installing the replacement build.'
    }

    $transactionId = [guid]::NewGuid().ToString('N')
    $appStaging = Join-Path $resolvedInstallRoot ('.App.staging-' + $transactionId)
    $releaseStaging = Join-Path $resolvedInstallRoot ('.Release.staging-' + $transactionId)
    $appPrevious = Join-Path $resolvedInstallRoot ('.App.previous-' + $transactionId)
    $releasePrevious = Join-Path $resolvedInstallRoot ('.Release.previous-' + $transactionId)
    $appActivated = $false
    $releaseActivated = $false
    $appBackedUp = $false
    $releaseBackedUp = $false

    try {
        New-Item -ItemType Directory -Path $appStaging | Out-Null
        Copy-Item -Path (Join-Path $packageRoot '*') -Destination $appStaging -Recurse -Force
        foreach ($relativePath in $required) {
            if (-not (Test-Path -LiteralPath (Join-Path $appStaging $relativePath) -PathType Leaf)) {
                throw "Staged OpenHUB install is incomplete: $relativePath"
            }
        }

        New-Item -ItemType Directory -Path $releaseStaging | Out-Null
        $releaseArchive = Join-Path $releaseStaging ($packageName + '.zip')
        if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) {
            Copy-Item -LiteralPath $resolvedInput -Destination $releaseArchive -Force
        }
        else {
            Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $releaseArchive -CompressionLevel Optimal
        }
        Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $releaseStaging 'Install-OpenHUB.ps1') -Force
        $releaseNotes = @(
            'OpenHUB fixed local release artifact'
            "Package: $packageName"
            "Installed: $([DateTimeOffset]::Now.ToString('o'))"
            'Reinstall: run Install-OpenHUB.ps1 from this directory; it automatically selects the single adjacent zip artifact.'
        )
        Set-Content -LiteralPath (Join-Path $releaseStaging 'README.txt') -Value $releaseNotes -Encoding utf8

        if (Test-Path -LiteralPath $appTarget) {
            Move-Item -LiteralPath $appTarget -Destination $appPrevious
            $appBackedUp = $true
        }
        Move-Item -LiteralPath $appStaging -Destination $appTarget
        $appActivated = $true

        if (Test-Path -LiteralPath $releaseTarget) {
            Move-Item -LiteralPath $releaseTarget -Destination $releasePrevious
            $releaseBackedUp = $true
        }
        Move-Item -LiteralPath $releaseStaging -Destination $releaseTarget
        $releaseActivated = $true

        if (-not $SkipShortcutCreation) {
            $iconPath = Join-Path $appTarget 'OpenHUB.exe'
            $shell = New-Object -ComObject WScript.Shell
            function Set-OpenHubShortcut {
                param(
                    [Parameter(Mandatory = $true)]
                    [string]$ShortcutPath,
                    [Parameter(Mandatory = $true)]
                    [string]$Description,
                    [string]$Arguments = ''
                )
                New-Item -ItemType Directory -Path (Split-Path -Parent $ShortcutPath) -Force | Out-Null
                $shortcut = $shell.CreateShortcut($ShortcutPath)
                $shortcut.TargetPath = $iconPath
                $shortcut.Arguments = $Arguments
                $shortcut.WorkingDirectory = $appTarget
                $shortcut.IconLocation = "$iconPath,0"
                $shortcut.Description = $Description
                $shortcut.Save()
                if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
                    throw "OpenHUB shortcut was not created: $ShortcutPath"
                }
            }

            $desktopDirectory = [Environment]::GetFolderPath('Desktop')
            $desktopHubShortcut = Join-Path $desktopDirectory 'OpenHUB.lnk'
            $desktopManagedShortcut = Join-Path $desktopDirectory 'OpenHUB - Open Codex.lnk'
            $startMenuDirectory = Join-Path ([Environment]::GetFolderPath('Programs')) 'OpenHUB'
            $startMenuHubShortcut = Join-Path $startMenuDirectory 'OpenHUB.lnk'
            $startMenuManagedShortcut = Join-Path $startMenuDirectory 'OpenHUB - Open Codex.lnk'
            $hubShortcutArguments = ''
            $managedShortcutArguments = '--launch-codex'
            $startupDirectory = [Environment]::GetFolderPath('Startup')
            $startupShortcuts = @(
                (Join-Path $startupDirectory 'OpenHUB Auto Start.lnk'),
                (Join-Path $startupDirectory 'Localhost Dashboard Auto Start.lnk')
            )
            foreach ($startupShortcut in $startupShortcuts) {
                if (Test-Path -LiteralPath $startupShortcut -PathType Leaf) {
                    Remove-Item -LiteralPath $startupShortcut -Force
                }
            }
            Set-OpenHubShortcut -ShortcutPath $desktopHubShortcut -Description 'Open the OpenHUB local account router.' -Arguments $hubShortcutArguments
            Set-OpenHubShortcut -ShortcutPath $desktopManagedShortcut -Description 'Open Codex through OpenHUB using the current Auto route preference.' -Arguments $managedShortcutArguments
            Set-OpenHubShortcut -ShortcutPath $startMenuHubShortcut -Description 'Open the OpenHUB local account router.' -Arguments $hubShortcutArguments
            Set-OpenHubShortcut -ShortcutPath $startMenuManagedShortcut -Description 'Open Codex through OpenHUB using the current Auto route preference.' -Arguments $managedShortcutArguments
            Write-Output "HUB_SHORTCUT=$desktopHubShortcut"
            Write-Output "MANAGED_SHORTCUT=$desktopManagedShortcut"
            Write-Output "START_MENU_HUB_SHORTCUT=$startMenuHubShortcut"
            Write-Output "START_MENU_SHORTCUT=$startMenuManagedShortcut"
            Write-Output 'STARTUP_SHORTCUT=disabled'
        }

        if ($appBackedUp -and (Test-Path -LiteralPath $appPrevious)) {
            Remove-Item -LiteralPath $appPrevious -Recurse -Force
        }
        if ($releaseBackedUp -and (Test-Path -LiteralPath $releasePrevious)) {
            Remove-Item -LiteralPath $releasePrevious -Recurse -Force
        }
    }
    catch {
        if ($releaseActivated -and (Test-Path -LiteralPath $releaseTarget)) {
            Remove-Item -LiteralPath $releaseTarget -Recurse -Force
        }
        if ($releaseBackedUp -and (Test-Path -LiteralPath $releasePrevious)) {
            Move-Item -LiteralPath $releasePrevious -Destination $releaseTarget
        }
        if ($appActivated -and (Test-Path -LiteralPath $appTarget)) {
            Remove-Item -LiteralPath $appTarget -Recurse -Force
        }
        if ($appBackedUp -and (Test-Path -LiteralPath $appPrevious)) {
            Move-Item -LiteralPath $appPrevious -Destination $appTarget
        }
        foreach ($partial in @($appStaging, $releaseStaging)) {
            $resolvedPartial = [IO.Path]::GetFullPath($partial)
            if ($resolvedPartial.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path -LiteralPath $resolvedPartial)) {
                Remove-Item -LiteralPath $resolvedPartial -Recurse -Force
            }
        }
        throw
    }

    $legacyInstallRoot = Join-Path $env:LOCALAPPDATA 'OpenHUB'
    if (Test-Path -LiteralPath $legacyInstallRoot -PathType Container) {
        $resolvedLegacyRoot = (Resolve-Path -LiteralPath $legacyInstallRoot).Path
        $legacyPrefix = $resolvedLegacyRoot.TrimEnd('\') + '\'
        foreach ($legacyPackage in Get-ChildItem -LiteralPath $resolvedLegacyRoot -Directory -Filter 'OpenHUB-Windows-*') {
            $resolvedLegacyPackage = [IO.Path]::GetFullPath($legacyPackage.FullName)
            if ($resolvedLegacyPackage.StartsWith($legacyPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedLegacyPackage -Recurse -Force
            }
        }
        foreach ($legacyFileName in @('current.txt', 'Launch-OpenHUB.ps1')) {
            $legacyFile = Join-Path $resolvedLegacyRoot $legacyFileName
            if (Test-Path -LiteralPath $legacyFile -PathType Leaf) {
                Remove-Item -LiteralPath $legacyFile -Force
            }
        }
    }

    Write-Output "INSTALL_PATH=$appTarget"
    Write-Output "RELEASE_PATH=$releaseTarget"
    Write-Output "INSTALLER_PATH=$(Join-Path $releaseTarget 'Install-OpenHUB.ps1')"
}
finally {
    if ($temporaryExtractRoot -and (Test-Path -LiteralPath $temporaryExtractRoot)) {
        $resolvedTemporaryExtractRoot = [IO.Path]::GetFullPath($temporaryExtractRoot)
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if ($resolvedTemporaryExtractRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
            [IO.Path]::GetFileName($resolvedTemporaryExtractRoot).StartsWith('OpenHUB-install-')) {
            Remove-Item -LiteralPath $resolvedTemporaryExtractRoot -Recurse -Force
        }
    }
}
