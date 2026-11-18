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
$artRoot = Join-Path $projectPath 'Art'
foreach ($file in Get-ChildItem -LiteralPath $artRoot -File -Recurse) {
    if ($file.Extension -in @('.png','.jpg','.jpeg','.svg','.webp')) {
        $relative = $file.FullName.Substring($projectPath.Length + 1).Replace('\', '/')
        $catalog[$relative] = 'res://' + $relative
    }
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
function Invoke-ArtImport([string]$name) {
    $stdoutPath = Join-Path $cachePath ($name + '.stdout.log')
    $stderrPath = Join-Path $cachePath ($name + '.stderr.log')
    $arguments = @('--headless', '--editor', '--path', ('"' + $projectPath + '"'), '--import', '--quit')
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $handle = $process.Handle
    if (-not $process.WaitForExit(180000)) { $process.Kill(); throw 'Artwork import timed out.' }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw ('Artwork import failed. See ' + $stderrPath) }
    return [string](Get-Content -LiteralPath $stderrPath -Raw)
}

$errors = Invoke-ArtImport 'new-art-import'
if (-not [string]::IsNullOrWhiteSpace($errors) -or @(Get-MissingArtworkImports).Count -gt 0) {
    # On a cold checkout some atlas consumers can be opened before the first
    # pass has written their imports. Require a clean second import.
    $errors = Invoke-ArtImport 'new-art-import-verify'
}
if (-not [string]::IsNullOrWhiteSpace($errors)) { throw 'Artwork import verification failed. See project/.godot/new-art-import-verify.stderr.log.' }
if (@(Get-MissingArtworkImports).Count -gt 0) { throw 'Artwork imports remain incomplete.' }
Write-Host 'New artwork is ready.'
