纯规则隔离回归

在交付包根目录运行：
  python tools/run_rule_tests.py
  python tools/run_rule_tests.py --campaign

第一项运行9套检查，第二项另运行四个固定种子的真实公开流程自动玩家。
默认报告位于verification/rule_test_rerun，可用--output更改。整个交付包搬移后仍可执行。
只需要Python标准库及包内Godot4.7。引擎与工程也可通过--engine、--project指定。

测试启动器在系统临时目录建立独立工程，仅复制正式Rules、被绑定原PNG及字体，没有旧Game或Steam autoload。
不启动原游戏，不覆盖正式工程或已有用户存档，不改CSV或数值，也不生成替代美术/声音。
测试目录保留可审查；报告中的stage可用于检查实际载入源码。工具使用独立BackpackPvEDeveloperTools47用户目录。

测试来源：
combat_tests：119条战斗模板/触发/状态/死亡/确定性等断言。
inventory_economy_tests：151条背包/特殊格/经济/合成等断言。
flow_contract_tests：310条流程/交易/保存等断言。居中开局的合成fixture仅平移坐标，原有断言保留。
content_tests：232条内容/原PNG/实际布局/Resource序列化检查，版本与12–15路线要求已按D02更新。
quality_rule_tests：195条坏快照、通用被动、多词缀、预览一致、耐力统计和开发工具边界。
rule_text_tests：397条中英结构化触发、效果、条件、空间、词缀、Boss及词典检查。
tools_ui_tests：14条真实开发工具控件/编辑/导入导出/Resource/摘要/布局检查。
route_contract_tests：88,231条路线检查，16,480条完整章节路径；4开局×8难度×8种子×3章节。
content_migration_tests：20条旧0.1.2真实存档迁移与回退后重新开战检查。
合计89,669条断言；同一断言重复运行不重复计入此数字。

migration_fixtures是旧0.1.2正式规则与配置（SHA d57d5fbaa99dbf7faada01fb6eac3c2293131e820ad77cdfbe8ebb8597c8a0aa）
通过公开GameFlow操作创建的校验存档，不是正式用户存档。启动器先复制到临时工程，再测试内容迁移，永不覆盖包内fixture。
战斗中fixture需安全回到整理并保留生命、金币、坐标、RNG、日志；路线fixture需重算候选，不能多领本章纯非战斗节点。

--campaign仅使用公开商店/配方/路线/事件/奖励API作决策，没有额外发钱、改血量或强制胜利。
当前四个固定种子包含两职业教学各12战通关，以及标准难度自然失败；这不代表真实新玩家胜率或平衡验收。
