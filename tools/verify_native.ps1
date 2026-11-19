param(
    [ValidateSet('RestartResidencyMain', 'ReleaseContentMain', 'ReleasePagesMain', 'ReferenceLayoutMain', 'SuppliedArtMain', 'TouchPagesMain', 'MobileUIMain', 'CombatAnchorsMain', 'BoundAssetsMain', 'ItemTemplateMain', 'CoreFlowMain', 'PostBattleMain', 'NativeMain', 'NativeInventoryQA', 'SaveSafetyMain', 'LoadingContractsMain', 'TransitionLayerMain', 'RouterContractsMain', 'ScaffoldContractsMain', 'LoadingProfileMain', 'NativeFeedbackMain', 'CombatVFXMain', 'NativePreferencesWrite', 'NativePreferencesReopen', 'PersistenceRouteWrite', 'PersistenceRouteReopen', 'PersistenceShopWrite', 'PersistenceShopReopen', 'PersistenceCombatWrite', 'PersistenceCombatReopen', 'PersistenceResultWrite', 'PersistenceResultReopen', 'PersistenceRewardWrite', 'PersistenceRewardReopen')]
    [string[]]$Scenes = @('RestartResidencyMain', 'ReleaseContentMain', 'ReleasePagesMain', 'ReferenceLayoutMain', 'SuppliedArtMain', 'TouchPagesMain', 'CombatAnchorsMain', 'BoundAssetsMain', 'ItemTemplateMain', 'CoreFlowMain', 'PostBattleMain', 'NativeMain', 'NativeInventoryQA', 'SaveSafetyMain', 'LoadingContractsMain', 'TransitionLayerMain', 'RouterContractsMain', 'ScaffoldContractsMain', 'LoadingProfileMain', 'NativeFeedbackMain', 'CombatVFXMain', 'NativePreferencesWrite', 'NativePreferencesReopen', 'PersistenceRouteWrite', 'PersistenceRouteReopen', 'PersistenceShopWrite', 'PersistenceShopReopen', 'PersistenceCombatWrite', 'PersistenceCombatReopen', 'PersistenceResultWrite', 'PersistenceResultReopen', 'PersistenceRewardWrite', 'PersistenceRewardReopen'),
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
if ($Scenes -contains 'NativePreferencesReopen' -and ($Scenes -notcontains 'NativePreferencesWrite' -or [array]::IndexOf($Scenes, 'NativePreferencesWrite') -gt [array]::IndexOf($Scenes, 'NativePreferencesReopen'))) {
    throw 'NativePreferencesReopen requires NativePreferencesWrite earlier in Scenes.'
}
foreach ($phase in @('Route','Shop','Combat','Result','Reward')) {
    $writeName = 'Persistence' + $phase + 'Write'
    $reopenName = 'Persistence' + $phase + 'Reopen'
    if ($Scenes -contains $reopenName -and ($Scenes -notcontains $writeName -or [array]::IndexOf($Scenes, $writeName) -gt [array]::IndexOf($Scenes, $reopenName))) {
        throw ($reopenName + ' requires ' + $writeName + ' earlier in Scenes.')
    }
}
$bundlePath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $bundlePath 'project'
$enginePath = Join-Path $bundlePath 'engine\Godot_v4.7-stable_win64.exe'
$qaPath = if ($OutputDirectory) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
} else {
    Join-Path $bundlePath ('verification\local_check_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
}
if (Test-Path -LiteralPath $qaPath) { throw ('Output directory already exists: ' + $qaPath) }
$oldAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
$qaAppData = Join-Path $qaPath 'app-data'
New-Item -ItemType Directory -Path (Join-Path $qaAppData 'BackpackBattles_Local47_PvE') -Force | Out-Null
@{
    app_data = $qaAppData
    save_directory = 'per-case isolated directory; write/reopen pairs share one directory'
    scenes = $Scenes
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $qaPath 'isolation.json') -Encoding UTF8

try {
    $env:APPDATA = $qaAppData
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ensure_art_imports.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'New artwork could not be prepared. See the import log in project/.godot.' }
    # Data layer gate: the item stats view must match its source tables before any scene runs.
    & py -3 (Join-Path $PSScriptRoot 'build_item_stats_view.py')
    if ($LASTEXITCODE -ne 0) { throw 'Item stats view is out of sync with items.csv/item_effects.csv. Run: py -3 tools/build_item_stats_view.py --write' }
    $results = @()
    foreach ($scene in $Scenes) {
        $casePath = Join-Path $qaPath $scene
        New-Item -ItemType Directory -Path $casePath -Force | Out-Null
        $stdoutPath = Join-Path $casePath 'stdout.log'
        $stderrPath = Join-Path $casePath 'stderr.log'
        $outputPath = if ($scene -eq 'NativeInventoryQA') { Join-Path $casePath 'report.json' } else { $casePath }
        if ($scene.StartsWith('NativePreferences')) {
            $outputPath = Join-Path $qaPath 'preferences_output'
            New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
        }
        $actualScene = if ($scene.StartsWith('NativePreferences')) { 'NativePreferencesMain' } else { $scene }
        $saveDirectory = if ($scene.StartsWith('NativePreferences')) { Join-Path $qaPath 'preferences_saves' } else { Join-Path $casePath 'saves' }
        $persistenceCase = ''
        if ($scene -match '^Persistence(Route|Shop|Combat|Result|Reward)(Write|Reopen)$') {
            $persistenceCase = $Matches[1].ToLowerInvariant()
            $persistenceStage = $Matches[2].ToLowerInvariant()
            $actualScene = 'PersistenceMain'
            $outputPath = Join-Path $qaPath ('persistence_' + $persistenceCase)
            New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
            $saveDirectory = Join-Path $qaPath ('persistence_' + $persistenceCase + '_saves')
        }
        $arguments = @('--path', ('"' + $projectPath + '"'), '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720', ('res://PvE/tests/' + $actualScene + '.tscn'), '--', ('"--qa-save-directory=' + $saveDirectory + '"'), ('"--qa-output=' + $outputPath + '"'))
        if ($scene.StartsWith('NativePreferences')) { $arguments += ('--preferences-stage=' + $(if ($scene.EndsWith('Write')) { 'write' } else { 'reopen' })) }
        if ($persistenceCase) { $arguments += @(('--persistence-case=' + $persistenceCase), ('--persistence-stage=' + $persistenceStage)) }
        Write-Host ('Checking ' + $scene + ' ...')
        $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $processHandle = $process.Handle
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $timedOut = $false
        $scriptFailed = $false
        while (-not $process.WaitForExit(2000)) {
            $timedOut = $clock.ElapsedMilliseconds -ge 180000
            $scriptFailed = [string](Get-Content -LiteralPath $stderrPath -Raw) -match 'SCRIPT ERROR: (Parse Error|Compile Error)'
            if ($timedOut -or $scriptFailed) {
                if (-not $process.HasExited) { $process.Kill() }
                break
            }
        }
        $process.WaitForExit()
        $errors = Get-Content -LiteralPath $stderrPath -Raw
        $passed = $process.ExitCode -eq 0 -and -not $timedOut -and -not $scriptFailed -and [string]::IsNullOrWhiteSpace($errors)
        $results += [pscustomobject]@{
            scene = $scene
            exit_code = $process.ExitCode
            stderr_empty = [string]::IsNullOrWhiteSpace($errors)
            timed_out = $timedOut
            script_error_at_startup = $scriptFailed
            elapsed_ms = $clock.ElapsedMilliseconds
            ok = $passed
        }
        ConvertTo-Json -InputObject $results -Depth 5 | Set-Content -LiteralPath (Join-Path $qaPath 'process-report.json') -Encoding UTF8
        if (-not $passed) { throw ('Failed: ' + $scene + '. See ' + $casePath) }
    }
    Write-Host ('All original-scene checks passed. Reports: ' + $qaPath)
} finally {
    [Environment]::SetEnvironmentVariable('APPDATA', $oldAppData, 'Process')
}
