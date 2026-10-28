param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$bundlePath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $bundlePath 'project'
$enginePath = Join-Path $bundlePath 'engine\Godot_v4.7-stable_win64.exe'
$catalogPath = Join-Path $projectPath 'Art\20261022\catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Get-MissingArtworkImports {
    $missing = @()
    foreach ($property in $catalog.PSObject.Properties) {
        $relative = $property.Value.Substring(6)
        $source = Join-Path $projectPath $relative
        if (-not (Test-Path -LiteralPath $source)) { throw ('Missing artwork source: ' + $relative) }
        $metadata = $source + '.import'
        if (-not (Test-Path -LiteralPath $metadata)) { $missing += $relative; continue }
        $match = [regex]::Match((Get-Content -LiteralPath $metadata -Raw), '(?m)^path="res://([^"]+)"')
        if (-not $match.Success) { $missing += $relative; continue }
        $imported = Join-Path $projectPath $match.Groups[1].Value
        if (-not (Test-Path -LiteralPath $imported)) { $missing += $relative; continue }
        if ((Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $imported).LastWriteTimeUtc) { $missing += $relative }
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
