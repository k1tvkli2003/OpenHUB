[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestDataDirectory
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPathHash([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value.ToLowerInvariant())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$liveData = [System.IO.Path]::GetFullPath((Join-Path $env:USERPROFILE '.openhub'))
$resolved = (Resolve-Path -LiteralPath $TestDataDirectory).Path
if ($resolved.Equals($liveData, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to run a test against the live openhub data directory.'
}

$manifestPath = Join-Path $resolved '.openhub-native-test-fixture.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Test data is missing the native disposable-fixture identity marker.'
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace($manifest.fixture_id)) {
    throw 'Test fixture identity marker is invalid.'
}
$resolvedHash = Get-CanonicalPathHash $resolved
$liveHash = Get-CanonicalPathHash $liveData
if ($resolvedHash -eq $liveHash -or $manifest.fixture_path_sha256 -eq $liveHash) {
    throw 'Test fixture resolves to the app-recorded live-store identity.'
}
if ($manifest.live_path_sha256 -ne $liveHash) {
    throw 'Test fixture was not recorded against the current live-store identity.'
}
if (-not $resolved.Equals([string]$manifest.fixture_path, [System.StringComparison]::OrdinalIgnoreCase) -or
    $manifest.fixture_path_sha256 -ne $resolvedHash) {
    throw 'Test fixture path does not match its recorded disposable identity.'
}

foreach ($name in @('store.db', 'encryption.key')) {
    $fixtureFile = Join-Path $resolved $name
    if (-not (Test-Path -LiteralPath $fixtureFile -PathType Leaf)) {
        throw "Test fixture is missing required file: $name"
    }
    $expectedHash = [string]$manifest.files.$name
    $actualHash = (Get-FileHash -LiteralPath $fixtureFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $actualHash -ne $expectedHash) {
        throw "Test fixture pre-start hash verification failed for $name"
    }
}

Write-Output ('fixture_verified=' + $resolved)
Write-Output ('fixture_id=' + $manifest.fixture_id)
