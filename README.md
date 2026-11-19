# 背包 · Backpack Battles（Godot 4.7 · Windows 本地 PvE）

当前版本：**V0.5**（见仓库根 `VERSION`）。游戏入口场景：`project/Code/Core/Main.tscn`。

> **协作者先读 [协作与验收指南.md](协作与验收指南.md)**：哪里能动、怎么换美术、怎么修 bug、怎么验收，都在那一份里。

## 这是什么

Backpack Battles 的 Godot 4.7 本地化维护版本，目标是让工程可读、可改、可验收，而不是复刻线上版。Windows GL Compatibility 环境验证，Android / iOS 尚未真机验收。

## 快速开始

1. 安装 [Git LFS](https://git-lfs.com/)，克隆仓库后执行 `git lfs pull` 取得引擎文件。
2. 双击 `launch-game.cmd` 直接玩；`launch-editor.cmd` 打开随仓库提供的 Godot 4.7 编辑器。
3. 也可用自装的兼容版本打开 `project/project.godot`。

其它入口：

| 文件 | 作用 |
| --- | --- |
| `verify-project.cmd` | 跑回归验收（隔离存档，不动你的正式存档） |
| `rebuild-config.cmd` | 重建配置 |
| `open-saves.cmd` | 打开本机存档目录 |

## 目录结构

仓库根：

```text
project/        游戏工程（Godot 项目本体）
engine/         随仓库提供的 Godot 4.7 引擎（Git LFS）
tools/          验收、数据校验、资源导入等脚本
docs/           维护文档（项目更新日志、代码维护索引）
licenses/       授权与归属说明
```

工程内 `project/` 按七大类组织（另有第三方与特殊根）：

| 目录 | 中文 | 放什么 |
| --- | --- | --- |
| `Art/` | 美术 | 图片、图集、材质、着色器；各批次素材按 `Supplied20261028`、`Supplied20261102`、`Supplied20261109`、`Supplied20261113` 等日期目录存放 |
| `Code/` | 代码 | 核心逻辑、运行时、兼容层、工具类 |
| `UI/` | 界面 | 场景与界面脚本 |
| `Data/` | 数据 | CSV 表格、翻译文件、数据视图 |
| `Audio/` | 音频 | 音效与背景音乐 |
| `Animation/` | 动画 | 动画资源与控制器 |
| `addons/` | 插件 | 第三方插件（不改动） |
| `PvE/` | 特殊根 | PvE 模式与验收场景，未并入七大类 |

## 验收

```powershell
.\verify-project.cmd
```

引擎直接调用方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\verify_native.ps1"
```

- 默认跑 **34 个原生场景**，覆盖核心流程、界面、存档持久化、加载契约等。
- 验收器自动设置隔离的 `APPDATA` 与独立存档目录，输出在 `verification\local_check_<时间戳>\`。
- 每个场景通过的标准：退出码 0、stderr 为空、无 `SCRIPT ERROR`、未超时。
- 可只跑子集：`-Scenes CoreFlowMain,SaveSafetyMain`。

## 参与修改

1. 先读 [协作与验收指南.md](协作与验收指南.md)。
2. 在 GitHub 点击 **Fork**，从自己的副本建分支；有写权限的协作者可直接推本仓库分支。
3. 提交游戏源文件、必要的导入设置和变更说明；Godot 缓存、玩家存档、验收截图与日志不提交。
4. 向 `main` 发起 Pull Request。

换美术请只走《美术替换工作流总纲》这一条入口，不要直接往 `Art/` 里堆文件。

## 版本与更新日志

- 发布标签：`V0.1` ~ `V0.5`，Release 说明见 GitHub Releases 页。
- 维护日志：[docs/项目更新日志.md](docs/项目更新日志.md)，按时间倒序记录每一轮改了什么、动了哪些文件、怎么验证。

## 授权

素材与代码的授权范围见 `licenses/` 及各资源目录内的许可文件。本仓库为私密本地维护版本，不改变原有素材的授权归属。
