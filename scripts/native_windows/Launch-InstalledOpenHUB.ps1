[CmdletBinding()]
param(
    [switch]$Wait,
    [switch]$LaunchCodex
)

$ErrorActionPreference = 'Stop'
$installRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$packageRoot = [IO.Path]::GetFullPath((Join-Path $installRoot 'App'))
$installPrefix = $installRoot.TrimEnd('\') + '\'
if (-not $packageRoot.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OpenHUB stable App directory escaped the install root.'
}

$launcher = Join-Path $packageRoot 'Launch-OpenHUB.ps1'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "OpenHUB package launcher is missing: $launcher"
}
& $launcher -Wait:$Wait -LaunchCodex:$LaunchCodex
