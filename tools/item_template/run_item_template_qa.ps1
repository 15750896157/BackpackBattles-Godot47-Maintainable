﻿param(
    # 开发者模式 · 物品模板试点单独验收入口（不跑全量 verify_native.ps1 时用）。
    # 正常游戏不进入本场景；报告输出到 校验\04_本地检查\item_template_qa_<时间戳>\。
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$bundlePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # tools\item_template\ -> bundle 根
$projectPath = Join-Path $bundlePath 'project'
$enginePath = Join-Path $bundlePath 'engine\Godot_v4.7-stable_win64.exe'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outPath = Join-Path $bundlePath ('校验\04_本地检查\item_template_qa_' + $stamp)
New-Item -ItemType Directory -Path $outPath -Force | Out-Null

# 门槛一：覆盖数据必须与源场景同步（不同步=提取脚本过期或场景被改，先拦下）
& py -3 (Join-Path $PSScriptRoot 'extract_item_overrides.py') --check
if ($LASTEXITCODE -ne 0) { throw 'item_template_overrides.json 与源场景不同步：跑 py -3 tools/item_template/extract_item_overrides.py 重生成' }

# 门槛二：无头跑开发者模式场景，失败非零退出
$arguments = @('--path', ('"' + $projectPath + '"'), '--rendering-method', 'gl_compatibility')
if ($Headless) { $arguments += '--headless' } else { $arguments += @('--windowed', '--resolution', '1280x720') }
$arguments += @('res://PvE/tests/ItemTemplateMain.tscn', '--', ('"--qa-output=' + $outPath + '"'))
Write-Host ('Running ItemTemplateQA ... report: ' + $outPath)
$process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw ('ItemTemplateQA FAILED, exit code ' + $process.ExitCode + '。报告: ' + $outPath)
}
Write-Host ('ItemTemplateQA PASSED。报告: ' + $outPath)
