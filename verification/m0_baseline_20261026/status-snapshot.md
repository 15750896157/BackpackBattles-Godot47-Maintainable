# M0 Step 1：项目现状快照

采样时间：2026-10-27T17:19:09+08:00。目录名中的20261026来自原计划标签；实际采样为2026-10-27。

工作工程：`C:\Users\Asus\Documents\Codex\2026-10-12\zhe\outputs\BackpackBattles_Godot47_Maintainable\project`。Git仓库真实存在于project/.git（隐藏目录）。本次先完成用户要求的点击翻页、窗口/按钮与继续入口改版，通过完整独立回归后才进入M0。本快照冻结的是改版后的真实源码；不能把改版行为纳入M0“零行为变更”声明。

范围：只实施M0 Step 1；未执行Step 2–8及M1–M7，没有创建SceneRouter/ViewModel生产骨架，没有Git提交。目录枚举与计数排除.git、.godot、__pycache__，计入工程内真实存在的QA/插件脚本；未把工作目录或461参考副本混入工程计数。

## 项目与脚本存在性

- `launch-game.cmd`：存在。命令 C0。
- `verify-project.cmd`：存在。命令 C0。
- `tools/verify_native.ps1`：存在。命令 C0。
- `tools/ensure_art_imports.ps1`：存在。命令 C0。
- `engine/Godot_v4.7-stable_win64.exe`：存在。命令 C0。

project/project.godot、下表五个关键源码均实际存在，读取成功。命令 C0、C4。真实参考461项目存在，当前Python为3.9.13，命令 C9；这与设计文件的旧缺失说明不同。

## Git 工作区

HEAD：`9ce0943 Initial upload Backpack Battles Godot project`。完整提交号：`9ce09433c4dc75fb3e22622fc5c8dd56f987b685`。命令 C1。

| 两字符状态（·代表空格） | 文件条目数 | 复现命令 |
| --- | ---: | --- |
| `·D` | 4854 | C1 |
| `·M` | 373 | C1 |
| `??` | 670 | C1 |
| 合计 | 5897 | C1 |

这是所有迭代累积的真实脏工作区，不是本轮新增数量。删除状态不代表M0本步删除了文件。本轮UI没有删除旧文件，M0亦未操作删除、暂存、还原或提交。完整状态见同目录git-status.txt。

## 工程规模

| 项目 | 实测 | 复现命令 |
| --- | ---: | --- |
| .gd文件 | 795 | C2 |
| .gd总行数（含空行/注释） | 67558 | C2 |
| .tscn文件 | 335 | C2 |
| class_name声明 | 110 | C3 |
| 自动加载项 | 24 | C5 |
| 默认验收阶段 | 22 | C8 |

| 关键文件 | 行数 | 复现命令 |
| --- | ---: | --- |
| Core/Main.tscn | 15072 | C4 |
| Core/Game.gd | 2118 | C4 |
| Items/Item.gd | 3043 | C4 |
| Core/Character.gd | 899 | C4 |
| PvE/NativeExpedition.gd | 844 | C4 |

class_name逐行记录在class-names.json。不能把源码行数减少当作可维护性证据；此处只记录现状。

## 自动加载原序摘录

实测24项，命令C5；没有补写计划中的第25项。

```ini
ShaderClock="*res://Compatibility/ShaderClock.gd"
FontSizeBinder="*res://Compatibility/FontSizeBinder.gd"
LocalServices="*res://LocalServices/LocalStore.gd"
Steam="*res://LocalServices/LocalSteam.gd"
ControllerIcons="*res://addons/controller_icons/ControllerIcons.gd"
Util="*res://Utility/Util.gd"
AssetStream="*res://Runtime/Loading/AssetStream.gd"
SteamHelper="*res://Utility/SteamHelper.gd"
Settings="*res://Utility/Settings.gd"
InputMapping="*res://Interface/Options/InputMapping.gd"
SilentWolf="*res://addons/silent_wolf/SilentWolf.gd"
ItemBook="*res://Sheets/ItemBook.gd"
SkinBook="*res://Utility/SkinBook.gd"
Game="*res://Core/Game.gd"
ObjectPool="*res://Utility/ObjectPool.gd"
RunDatabase="*res://Core/RunDatabase.gd"
Sound="*res://Utility/Sound.tscn"
CrazySDK="*res://Utility/CrazySDK.gd"
CraftingManager="*res://Core/CraftingManager.gd"
MaterialCompiler="*res://Utility/MaterialCompiler.gd"
EventBus="*res://Utility/EventBus.gd"
CustomRules="*res://Utility/CustomRules.gd"
InputBlocker="*res://Interface/InputBlocker.tscn"
Expedition="*res://PvE/NativeExpedition.gd"
```

## Runtime 到二级的目录树

命令C6。只列到Runtime的子目录及下一层子目录/直属文件，更深处不展开；文件计数另见规模表。

```text
Runtime/
├── Audio/
│   ├── SceneMusic.gd
│   ├── SceneMusic.gd.uid
├── Behavior/
│   └── Assets/
│   └── CharacterClasses/
│   └── Compatibility/
│   └── Core/
│   └── Features/
│   └── Game/
│   └── Interface/
│   └── Items/
│   └── LocalServices/
│   └── Shader/
│   └── Sheets/
│   └── Utility/
├── Callbacks/
│   └── CharacterClasses/
│   └── Compatibility/
│   └── Core/
│   └── Interface/
│   └── Items/
│   └── Utility/
├── Collections/
│   ├── CountLedger.gd
│   ├── CountLedger.gd.uid
│   ├── SequenceOps.gd
│   ├── SequenceOps.gd.uid
├── Events/
│   ├── CombatDispatch.gd
│   ├── CombatDispatch.gd.uid
├── Loading/
│   ├── AssetStream.gd
│   ├── AssetStream.gd.uid
│   ├── item_effects.json
│   ├── LazyCatalog.gd
│   ├── LazyCatalog.gd.uid
│   ├── LazyPanel.gd
│   ├── LazyPanel.gd.uid
│   ├── SceneResidency.gd
│   ├── SceneResidency.gd.uid
│   └── Scenes/
├── Random/
│   ├── ChanceDebt.gd
│   ├── ChanceDebt.gd.uid
│   ├── PrefixSampler.gd
│   ├── PrefixSampler.gd.uid
│   ├── RangeDebt.gd
│   ├── RangeDebt.gd.uid
├── Scene/
│   ├── LeasePool.gd
│   ├── LeasePool.gd.uid
├── Serialization/
│   ├── BitPacket.gd
│   ├── BitPacket.gd.uid
├── UI/
│   ├── InputLocks.gd
│   ├── InputLocks.gd.uid
```

## 根目录与 docs 的报告/说明文件

以下按实际修改时间倒序记录直接位于根目录和docs的.md/.txt/.json文件，命令C7。历史报告保留原时间与内容，不能作为当前源码数量替代。

| 文件 | 修改时间（本地时区） | 复现命令 |
| --- | --- | --- |
| manifest.json | 2026-10-27T17:16:49+08:00 | C7 |
| docs/M0_文档核对与最小修正建议_20261027.md | 2026-10-27T17:14:28+08:00 | C7 |
| 代码重构与兼容性报告.txt | 2026-10-27T17:10:46+08:00 | C7 |
| 增量更新说明.txt | 2026-10-27T17:10:46+08:00 | C7 |
| 开始使用.txt | 2026-10-27T17:10:46+08:00 | C7 |
| 点击翻页与继续入口重制_20261027.md | 2026-10-27T17:10:46+08:00 | C7 |
| 点击翻页与继续入口重制_20261027.txt | 2026-10-27T17:10:46+08:00 | C7 |
| docs/后续更新指南.txt | 2026-10-27T17:10:46+08:00 | C7 |
| 移动端UI重构与瘦身说明_20261027.md | 2026-10-27T15:30:15+08:00 | C7 |
| 移动端UI重构与瘦身说明_20261027.txt | 2026-10-27T15:30:15+08:00 | C7 |
| docs/代码维护索引.json | 2026-10-27T15:23:47+08:00 | C7 |
| 核心流程修复与光影优化_20261023.md | 2026-10-23T11:19:42+08:00 | C7 |
| 核心流程修复与光影优化_20261023.txt | 2026-10-23T11:19:42+08:00 | C7 |
| 美术与过渡优化说明_20261022.md | 2026-10-22T17:07:16+08:00 | C7 |
| 美术与过渡优化说明_20261022.txt | 2026-10-22T17:07:16+08:00 | C7 |
| docs/生成素材提示词_20261022.md | 2026-10-22T17:07:16+08:00 | C7 |
| 新美术替换与布局核验_20261022.md | 2026-10-22T17:04:00+08:00 | C7 |
| 新美术替换与布局核验_20261022.txt | 2026-10-22T17:04:00+08:00 | C7 |
| docs/新美术接入与维护说明.txt | 2026-10-22T12:45:42+08:00 | C7 |
| 异步加载与轻量化优化记录_20261022.txt | 2026-10-22T10:27:19+08:00 | C7 |
| docs/异步加载维护指南.txt | 2026-10-22T10:27:19+08:00 | C7 |
| 进一步重构报告_20261021.txt | 2026-10-21T11:03:26+08:00 | C7 |
| docs/20261021_进一步重构报告.txt | 2026-10-21T11:03:26+08:00 | C7 |
| UI与结构改良报告_20261020.txt | 2026-10-20T12:07:53+08:00 | C7 |
| docs/20261020_第二轮UI与结构改良报告.txt | 2026-10-20T12:07:53+08:00 | C7 |
| docs/20261020_首轮代码重构与兼容性报告.txt | 2026-10-20T10:46:54+08:00 | C7 |
| docs/20261015_架构重置与错误修复报告.txt | 2026-10-15T19:21:22+08:00 | C7 |
| docs/20261015_开始使用.txt | 2026-10-15T19:13:50+08:00 | C7 |

最新UI说明：点击翻页与继续入口重制_20261027.md。架构核对：docs/M0_文档核对与最小修正建议_20261027.md。本快照与其他M0证据位于verification，不混入上述根目录/docs列表。

## 验收脚本实况与文档偏差

默认真实列表（22项，命令C8）：

`TouchPagesMain / CombatAnchorsMain / BoundAssetsMain / CoreFlowMain / NativeMain / NativeInventoryQA / SaveSafetyMain / LoadingContractsMain / LoadingProfileMain / NativeFeedbackMain / NativePreferencesWrite / NativePreferencesReopen / PersistenceRouteWrite / PersistenceRouteReopen / PersistenceShopWrite / PersistenceShopReopen / PersistenceCombatWrite / PersistenceCombatReopen / PersistenceResultWrite / PersistenceResultReopen / PersistenceRewardWrite / PersistenceRewardReopen`

M0文件写31阶段，其所列旧名展开为32项；设计方案另有28阶段说法。当前公共脚本为22阶段，且一些旧场景/示范RuntimeContracts已不在工程中。公共默认测试不操作系统鼠标；真实鼠标本轮另用隔离窗口完成。UI回归为入口启动加22阶段，即23个进程，报告1932项断言通过，证据在../touch_ui_20261027/summary.json；它是此前UI改版验收，不冒充M0 Step 2基线。

Autoload实际24项，提示词自身列举亦为24项却写25项；场景总数、NativeExpedition行数、Runtime目录及现有UI结构以本快照为准。Main.tscn的15072行与旧文件一致。461参考目录与可用Python存在，不据此擅改结构匹配率门槛。

## 五个设计风险与最小建议

详见docs/M0_文档核对与最小修正建议_20261027.md，按严重程度：

1. P0：`class_name SceneRouter`与同名Autoload冲突。工程外Godot4.7实际复现编译失败；建议保留Autoload名，去掉同名全局类声明。
2. P1：全公开方法零副作用与允许内存注册矛盾。建议明确禁用change_scene无外部副作用，注册表仅允许纯内存操作；直接子节点计数不能单独证明无副作用。
3. P1：预期push_error使成功QA的空stderr门槛失败。实际复现退出0且返回空字典，但stderr非空；建议把负向验证分离到捕获预期错误的子进程。
4. P1：目录清单漏掉新UI、Behavior/Callbacks、其他Core与动画/信号路径；过滤后仍要求条数≥原始命中也不自洽。建议全工程候选逐条纳入、解释排除或标注待确认。
5. P2：两次性能采样需要保留完整六阶段×十二项基础指标，并固定VSync、前后台、冷热缓存与环境，按相同阶段比较。较差基线并非天然更保守；不擅改+5%/+10%阈值。

两项负向实验在本目录design-probes保留最小源码、参数、输出。它们是隔离的故意失败样例，不能混入正式游戏空stderr通过记录。生产工程没有添加这两个问题骨架。

## 本步验证

- 对真实文件完成两次独立收集，关键数值、HEAD、状态、工程所有文件SHA256完全一致；M0文档写完后再次比较。
- 使用Windows PowerShell复现C1–C5对应数字，结果写入command-check.json；Python计数与rg/PowerShell计数相互核对。
- facts.json是机器可读数字；project-hashes.json用于本步前后源码不变校验；git-status.txt为原始工作区状态；input-documents.json记录两份输入文件SHA256（命令C10），原文件未改。
- 本步不修改运行代码。阶段A完整code-review须等Step 1–4全部完成后进行；阶段B未开始，未冒称阶段收尾。

## 是否进入 Step 2

Step 1已完成，可复现验证通过。Step 2尚未开始，需要用户先确认按现有22阶段冻结，还是先重新恢复旧列表的验收覆盖；不会把22写成31或拿空场景凑数量。建议按真实22阶段留档，同时明确旧覆盖差异。其余契约与性能建议均未自行实施，待相关Step前确认。

## 复现命令

以下使用PowerShell，从实际project目录开始。所有数量是命令输出，不是设计文件的预期值。

### C0：项目、Git和脚本存在性

```powershell
Set-Location -LiteralPath 'C:\Users\Asus\Documents\Codex\2026-10-12\zhe\outputs\BackpackBattles_Godot47_Maintainable\project'
Test-Path -LiteralPath '.git'
Get-Item -Force -LiteralPath '.git'
Get-Item -LiteralPath 'project.godot','Core/Main.tscn','Core/Game.gd','Items/Item.gd','Core/Character.gd','PvE/NativeExpedition.gd'
'../launch-game.cmd','../verify-project.cmd','../tools/verify_native.ps1','../tools/ensure_art_imports.ps1','../engine/Godot_v4.7-stable_win64.exe' | ForEach-Object { Get-Item -LiteralPath $_ }
```

### C1：HEAD 与两字符状态计数

```powershell
git log --oneline -1
git rev-parse HEAD
git status --short --untracked-files=all | Group-Object { $_.Substring(0,2) } | Select-Object Name,Count
@(git status --short --untracked-files=all).Count
```

### C2：文件和总行数

```powershell
$snapshotGd=@(rg --files --hidden --no-ignore -g '*.gd' -g '!.git/**' -g '!.godot/**')
$snapshotGd.Count
$snapshotLines=0
foreach ($snapshotFile in $snapshotGd) { $snapshotLines+=@(Get-Content -LiteralPath $snapshotFile -Encoding UTF8).Count }
$snapshotLines
@(rg --files --hidden --no-ignore -g '*.tscn' -g '!.git/**' -g '!.godot/**').Count
```

### C3：class_name

```powershell
@(rg -n --hidden --no-ignore -g '*.gd' -g '!.git/**' -g '!.godot/**' '^\s*class_name\s+' .).Count
```

### C4：关键文件行数

```powershell
'Core/Main.tscn','Core/Game.gd','Items/Item.gd','Core/Character.gd','PvE/NativeExpedition.gd' | ForEach-Object { [pscustomobject]@{File=$_;Lines=@(Get-Content -LiteralPath $_ -Encoding UTF8).Count} }
```

### C5：Autoload清单及数量

```powershell
$snapshotConfig=Get-Content -LiteralPath 'project.godot' -Raw -Encoding UTF8
$snapshotAutoload=@((($snapshotConfig -split '\[autoload\]')[1] -split '?
\[')[0] -split '?
' | Where-Object { $_ -match '=' })
$snapshotAutoload
$snapshotAutoload.Count
```

### C6：Runtime二级树

```powershell
Get-ChildItem -LiteralPath 'Runtime' | Sort-Object Name | ForEach-Object { $_.Name; if ($_.PSIsContainer) { Get-ChildItem -LiteralPath $_.FullName | Sort-Object Name | ForEach-Object { '  '+$_.Name } } }
```

### C7：报告清单与修改日期

```powershell
Get-ChildItem -LiteralPath '..','../docs' -File | Where-Object { $_.Extension -in '.md','.txt','.json' } | Sort-Object LastWriteTime -Descending | Select-Object Name,DirectoryName,@{Name='Modified';Expression={$_.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:sszzz')}}
```

### C8：默认阶段（直接解析脚本，不执行验收）

```powershell
$snapshotWrapper=Get-Content -LiteralPath '../tools/verify_native.ps1' -Raw -Encoding UTF8
$snapshotArray=[regex]::Match($snapshotWrapper,'\$Scenes\s*=\s*@\(([^)]*)\)').Groups[1].Value
$snapshotStages=@([regex]::Matches($snapshotArray,"'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$snapshotStages
$snapshotStages.Count
```

### C9：参考工程与Python

```powershell
Test-Path -LiteralPath '../../BackpackBattles_Godot461_Local/project/project.godot'
py --version
```

### C10：原始文档指纹

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:/Users/Asus/Downloads/20261026_架构重构设计方案.md','C:/Users/Asus/Downloads/20261026_M0_开发规划提示词.md'
```
