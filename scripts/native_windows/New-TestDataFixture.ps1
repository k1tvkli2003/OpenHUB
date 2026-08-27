[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceBackup,

    [string]$FixtureRoot = (Join-Path $env:USERPROFILE '.openhub-test-fixtures'),

    [string]$PythonExecutable = 'python'
)

$ErrorActionPreference = 'Stop'

$liveData = [System.IO.Path]::GetFullPath((Join-Path $env:USERPROFILE '.openhub'))
$source = (Resolve-Path -LiteralPath $SourceBackup).Path
$root = [System.IO.Path]::GetFullPath($FixtureRoot)

if ($source.Equals($liveData, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to build a test fixture from the live openhub data directory. Use a verified backup.'
}

$required = @('store.db', 'encryption.key')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $name) -PathType Leaf)) {
        throw "Verified backup is missing required file: $name"
    }
}

New-Item -ItemType Directory -Path $root -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$destination = Join-Path $root ($stamp + '-native-test')
New-Item -ItemType Directory -Path $destination | Out-Null
$resolvedDestination = (Resolve-Path -LiteralPath $destination).Path

if (-not $resolvedDestination.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Fixture destination escaped the configured fixture root.'
}
if ($resolvedDestination.Equals($liveData, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Fixture destination resolved to the live openhub data directory.'
}

$names = @('store.db', 'encryption.key', 'store.db-wal', 'store.db-shm', 'store.db.migrate-lock')
foreach ($name in $names) {
    $sourceFile = Join-Path $source $name
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        continue
    }
    $targetFile = Join-Path $resolvedDestination $name
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Fixture hash verification failed for $name"
    }
}

$database = Join-Path $resolvedDestination 'store.db'
$probe = @'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
try:
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    accounts = connection.execute("SELECT COUNT(*) FROM accounts").fetchone()[0]
    usage = connection.execute("SELECT COUNT(*) FROM usage_history").fetchone()[0]
finally:
    connection.close()

if integrity != "ok":
    raise SystemExit(f"integrity={integrity}")
print(f"integrity=ok accounts={accounts} usage_history={usage}")
'@

& $PythonExecutable -c $probe $database
if ($LASTEXITCODE -ne 0) {
    throw 'Fixture SQLite integrity verification failed.'
}

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

$fileHashes = [ordered]@{}
foreach ($name in $names) {
    $fixtureFile = Join-Path $resolvedDestination $name
    if (Test-Path -LiteralPath $fixtureFile -PathType Leaf) {
        $fileHashes[$name] = (Get-FileHash -LiteralPath $fixtureFile -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$manifest = [ordered]@{
    schema_version = 1
    fixture_id = [guid]::NewGuid().ToString('D')
    fixture_path = $resolvedDestination
    fixture_path_sha256 = Get-CanonicalPathHash $resolvedDestination
    live_path_sha256 = Get-CanonicalPathHash $liveData
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    files = $fileHashes
}
$manifestPath = Join-Path $resolvedDestination '.openhub-native-test-fixture.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Output ('fixture_path=' + $resolvedDestination)
Write-Output ('fixture_id=' + $manifest.fixture_id)
