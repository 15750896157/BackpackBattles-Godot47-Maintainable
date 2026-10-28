param(
    [ValidateSet('TouchPagesMain', 'MobileUIMain', 'CombatAnchorsMain', 'BoundAssetsMain', 'CoreFlowMain', 'NativeMain', 'NativeInventoryQA', 'SaveSafetyMain', 'LoadingContractsMain', 'LoadingProfileMain', 'NativeFeedbackMain', 'NativePreferencesWrite', 'NativePreferencesReopen', 'PersistenceRouteWrite', 'PersistenceRouteReopen', 'PersistenceShopWrite', 'PersistenceShopReopen', 'PersistenceCombatWrite', 'PersistenceCombatReopen', 'PersistenceResultWrite', 'PersistenceResultReopen', 'PersistenceRewardWrite', 'PersistenceRewardReopen')]
    [string[]]$Scenes = @('TouchPagesMain', 'CombatAnchorsMain', 'BoundAssetsMain', 'CoreFlowMain', 'NativeMain', 'NativeInventoryQA', 'SaveSafetyMain', 'LoadingContractsMain', 'LoadingProfileMain', 'NativeFeedbackMain', 'NativePreferencesWrite', 'NativePreferencesReopen', 'PersistenceRouteWrite', 'PersistenceRouteReopen', 'PersistenceShopWrite', 'PersistenceShopReopen', 'PersistenceCombatWrite', 'PersistenceCombatReopen', 'PersistenceResultWrite', 'PersistenceResultReopen', 'PersistenceRewardWrite', 'PersistenceRewardReopen')
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
if ($Scenes -contains 'NativeInteractionQA') {
    Write-Host '提示：真实鼠标检查会自动移动系统指针约36秒。检查期间请不要移动鼠标、点击其它窗口或切换应用。'
}
$bundlePath = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $bundlePath 'project'
$enginePath = Join-Path $bundlePath 'engine\Godot_v4.7-stable_win64.exe'
$qaPath = Join-Path $bundlePath ('verification\local_check_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $qaPath -Force | Out-Null
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ensure_art_imports.ps1')
if ($LASTEXITCODE -ne 0) { throw 'New artwork could not be prepared. See the import log in project/.godot.' }
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
    if ($scene -eq 'NativeInteractionQA') {
        Write-Host '现在开始真实指针测试（约36秒），请暂时不要操作鼠标或切换窗口。'
    }
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $processHandle = $process.Handle
    if (-not $process.WaitForExit(180000)) {
        $process.Kill()
        throw ('Timed out: ' + $scene + '. Only this test process was stopped.')
    }
    $process.WaitForExit()
    $errors = Get-Content -LiteralPath $stderrPath -Raw
    $passed = $process.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($errors)
    $results += [pscustomobject]@{scene=$scene;exit_code=$process.ExitCode;stderr_empty=[string]::IsNullOrWhiteSpace($errors);ok=$passed}
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $qaPath 'process-report.json') -Encoding UTF8
    if (-not $passed) { throw ('Failed: ' + $scene + '. See ' + $casePath) }
}
Write-Host ('All original-scene checks passed. Reports: ' + $qaPath)
