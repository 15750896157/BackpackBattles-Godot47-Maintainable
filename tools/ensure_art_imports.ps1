param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$bundlePath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $bundlePath 'project'
$enginePath = Join-Path $bundlePath 'engine\Godot_v4.7-stable_win64.exe'
$catalog = @{}
function Get-ArtworkSourceDigest($path) {
    $digestAlgorithm = [System.Security.Cryptography.MD5]::Create()
    $sourceStream = [System.IO.File]::OpenRead($path)
    try { return ([System.BitConverter]::ToString($digestAlgorithm.ComputeHash($sourceStream))).Replace('-', '').ToLowerInvariant() }
    finally { $sourceStream.Dispose(); $digestAlgorithm.Dispose() }
}
foreach ($catalogFile in @('Art\20261022\catalog.json', 'Art\Supplied20261028\catalog.json')) {
    $catalogPath = Join-Path $projectPath $catalogFile
    $sourceCatalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($property in $sourceCatalog.PSObject.Properties) { $catalog[$catalogFile + ':' + $property.Name] = $property.Value }
}
function Get-MissingArtworkImports {
    $missing = @()
    foreach ($property in $catalog.GetEnumerator()) {
        $relative = $property.Value.Substring(6)
        $source = Join-Path $projectPath $relative
        if (-not (Test-Path -LiteralPath $source)) { throw ('Missing artwork source: ' + $relative) }
        $metadata = $source + '.import'
        if (-not (Test-Path -LiteralPath $metadata)) { $missing += $relative; continue }
        $match = [regex]::Match((Get-Content -LiteralPath $metadata -Raw), '(?m)^path="res://([^"]+)"')
        if (-not $match.Success) { $missing += $relative; continue }
        $imported = Join-Path $projectPath $match.Groups[1].Value
        if (-not (Test-Path -LiteralPath $imported)) { $missing += $relative; continue }
        if ((Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $imported).LastWriteTimeUtc) {
            # Godot keeps an identical cached texture when only the copy time changes.
            $digestPath = [System.IO.Path]::ChangeExtension($imported, '.md5')
            if (-not (Test-Path -LiteralPath $digestPath)) { $missing += $relative; continue }
            $digest = [regex]::Match((Get-Content -LiteralPath $digestPath -Raw), '(?m)^source_md5="([0-9a-f]+)"')
            if (-not $digest.Success -or $digest.Groups[1].Value -ine (Get-ArtworkSourceDigest $source)) { $missing += $relative }
        }
    }
    return $missing
}
$missing = @(Get-MissingArtworkImports)
if ($CheckOnly) {
    if ($missing.Count -gt 0) { Write-Output ($missing -join ', '); exit 3 }
    Write-Output 'All supplied artwork imports are ready.'
    exit 0
}
if ($missing.Count -eq 0) { exit 0 }
Write-Host 'Preparing new artwork for this project folder. The first launch may take a moment.'
$cachePath = Join-Path $projectPath '.godot'
New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
$stdoutPath = Join-Path $cachePath 'new-art-import.stdout.log'
$stderrPath = Join-Path $cachePath 'new-art-import.stderr.log'
$arguments = @('--headless', '--editor', '--path', ('"' + $projectPath + '"'), '--import', '--quit')
$process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$handle = $process.Handle
if (-not $process.WaitForExit(180000)) { $process.Kill(); throw 'Artwork import timed out; only this import process was stopped.' }
$process.WaitForExit()
$errors = Get-Content -LiteralPath $stderrPath -Raw
if ($process.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($errors)) { throw ('Artwork import failed. See ' + $stderrPath) }
if (@(Get-MissingArtworkImports).Count -gt 0) { throw 'Artwork imports remain incomplete. Keep the source images and inspect the import log.' }
Write-Host 'New artwork is ready.'
