[CmdletBinding()]
param(
    [switch]$Wait,
    [switch]$LaunchCodex
)

$ErrorActionPreference = 'Stop'
$packageRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$executable = Join-Path $packageRoot 'OpenHUB.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "OpenHUB executable is missing: $executable"
}

$startParameters = @{
    FilePath = $executable
    WorkingDirectory = $packageRoot
    PassThru = $true
}
if ($LaunchCodex) {
    $startParameters.ArgumentList = @('--launch-codex')
}
$process = Start-Process @startParameters
if ($Wait) {
    $process.WaitForExit()
    exit $process.ExitCode
}
