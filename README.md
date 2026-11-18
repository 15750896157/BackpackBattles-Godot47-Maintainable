# Backpack Battles Godot 4.7

Windows 本地 PvE 工程。游戏入口为 `project/Core/Main.tscn`。

## 运行与编辑

1. 安装 Git LFS，克隆仓库后运行 `git lfs pull` 取得随仓库提供的引擎。
2. 双击 `launch-game.cmd` 玩游戏，或用 `launch-editor.cmd` 打开工程。
3. 也可用已安装的 Godot 4.7 打开 `project/project.godot`。

`verify-project.cmd` 使用隔离存档运行回归。`rebuild-config.cmd` 是配置编译入口。旧绑定的源资源哈希校验仍会报告既有的修改，当前游戏使用已编译的配置。各文件的授权见 `licenses/` 和对应资源的许可文件。

## 参与修改

在 GitHub 点击 **Fork**，从自己的副本创建分支、提交并推送。完成后向此仓库的 `main` 发起 Pull Request。具有本仓库写权限的协作者可以直接推送本仓库的分支。

提交游戏源文件、必要的导入设置和变更说明。Godot 缓存、玩家存档、验收截图及日志无需提交。
