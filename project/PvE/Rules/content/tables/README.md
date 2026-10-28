# 游戏数值配置表

本目录是 **0.1.3 原工程素材与D02路线修正基线**，用于 Godot 4.7 的单机 PvE 实现、联调和试玩。原始0.1.0输入保存在开发工作区；本目录为已修正的副本。战斗强度、经济效率和掉落概率仍需通过自动模拟与人工试玩迭代。

## 内容范围

- 2 名角色、6 种流派、4 套开局配置。
- 72 件普通物品、10 个背包、24 个配方。
- 3 章路线、30 套敌人构筑、8 个遭遇词缀、3 个 Boss 与 6 个 Boss 阶段。
- 五槽商店、递增刷新、锁定、促销、背包保底、利息和章节经济。
- 5 个奖励表、20 条奖励项、12 个事件、35 个事件选择、2 个休息动作。
- 16 个玩法标签和5个只用于预览的情报词汇，543组中英内容文本键。
- 教学、标准、进阶、挑战 1 至 5，共 8 档难度。
- 16 步教学、20 个成就、24 个本地采集指标、19 个派生档案统计和中英文本。

## 文件约定

- 编码：UTF-8，无 BOM；换行：LF；格式：RFC 4180 CSV。
- ID：稳定 snake_case。保存数据只记录 ID，不保存数组下标。
- 布尔值：`true` 或 `false`；比例：`0.0` 至 `1.0`；时间：秒。
- 列表：使用 `|` 分隔；二维格坐标：`x:y`；参数：`key:value|key:value`。
- 空值：空字符串。读取器必须区分空字符串、0 与 false。
- `config_manifest.csv` 不列出自身；`row_count` 统计每张业务配置表的数据行数，不包含表头。
- 源配置保持明文，目录内的 .gdignore 阻止Godot误当翻译表导入CSV。运行时只读 content/compiled/content.json，不使用 .csv.import 或 .translation。
- items.crafted_only 表示配方成品在普通随机商店禁售；专用奖励与事件仍可授予。shop_enabled 是普通商店的独立入池开关。
- Boss的两种传奇赠礼显式 ignore_chapter_gate:true，精英传奇只在第三章出现，其他物品奖励遵守章节门槛。

## Godot 4.7 导入建议

1. 项目根目录 tools/import_content.py 按CSV、复合主键和字段类型编译确定性的JSON缓存，并生成文件SHA-256清单。
2. 数值与布尔字段保留类型；管道列表和参数保持String，由ContentDB.list_values/parse_params解析并复制。get_definition提供可序列化的只读Resource视图。
3. 每次导入运行完整validate_content.py，覆盖schema、主键、外键、双语、冻结范围、真实占格、候选约束与奖励池非空；旧tools/validate_configs.mjs保留作基础检查。
4. `ContentDB` 只暴露按稳定 ID 的只读查询；运行时实例不得回写定义。
5. 敌人、Boss 和开局坐标必须再经过 Godot `PlacementService` 的真实旋转与占格校验。
6. 发布构建记录 `content_version`、每个文件的 SHA-256 和最终 PCK 哈希，以便存档迁移和问题定位。

## 使用命令

```bash
python tools/import_content.py
python tools/import_content.py
python tools/validate_content.py
```

生成器是配置事实源。需要批量调整时修改生成器并重新生成，不要同时手工修改生成 CSV。

## 0.1.3 路线更正

冻结D02要求12至15场战斗。原三章各5混合节点允许每章两个纯非战斗节点，曾产生最低9场的不一致。现以game_rules.max_noncombat_nodes_per_act=1明确限制每章最多一个商人/事件/休息；保留2至3候选、确定性战斗fallback及必经Boss，实际可达12至15战斗。旧9至15警告已移除，验证器直接阻断违反新规则的配置。内容版本变化时，战斗中存档按原流程退回安全整理阶段，不提交旧规则结果。

原CSV数值与72/10素材绑定保持；未生成SVG、音乐或音效。配置编译的推荐入口是交付包tools/import_content.py，调试编辑/重放入口是tools/developer_tools.py。
