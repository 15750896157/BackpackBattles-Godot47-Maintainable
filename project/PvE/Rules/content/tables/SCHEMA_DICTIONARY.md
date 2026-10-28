# 配置表数据字典

版本：0.1.3 原素材、布局与D02修正基线。字段类型由Python导入器记录，Godot读JSON后恢复整数列；CSV本身只承载文本表示。

## 通用字段规则

- `id`：稳定主键或复合主键的一部分。
- `*_id`：外键；空字符串表示该关系不适用。
- `*_key`：本地化键，必须同时存在于简体中文与英文表。
- `*_pct` / `*_chance` / `*_scalar`：浮点比例或倍率。
- `*_seconds` / `cooldown`：秒。
- `weight`：正数相对权重，由所属池内合法条目归一化。
- `params`：小型结构化参数串。导入后必须转换为 Dictionary，不应在战斗热路径重复解析。
- `items.crafted_only`：配方成品标记，普通商店禁售，不禁止显式奖励/事件赠送；`shop_enabled`为普通商店入池开关。
- `bosses.bag_layout`：`bag_id:x:y:rotation|...`，敌人和Boss遵守同一背包几何规则，第二阶段与第一阶段物品累计校验。
- `tags.category=intel`：情报预览词汇，不作为物品的新玩法标签，不引入数值倍率。
- `upgrade_item`：只复用已定义的一阶到二阶配方转换；无可选对象时下次商店20%券。不存在numeric_tier或独立强化等级。
- `ignore_chapter_gate:true`：仅Boss独立赠礼显式绕过章节门槛，其他奖励不得使用。

### tags.csv

物品、敌人和流派共用的标签字典。

- 字段：`id`、`name_key`、`description_key`、`category`
- 初始行数：21

### item_shapes.csv

普通物品形状模板。相对坐标使用 x:y，列表使用竖线分隔。

- 字段：`id`、`cells`、`allowed_rotations`、`cell_count`
- 初始行数：10

### spatial_templates.csv

首发允许使用的空间关系模板。

- 字段：`id`、`relation_type`、`range`、`relative_cells`、`rotates_with_source`
- 初始行数：11

### trigger_templates.csv

战斗事件触发器模板。

- 字段：`id`、`name_key`、`priority`、`default_internal_cooldown`
- 初始行数：11

### condition_templates.csv

触发条件模板。首发条件组合只支持全部满足。

- 字段：`id`、`name_key`、`param_format`
- 初始行数：12

### effect_templates.csv

通用效果模板。运行时由 EffectResolver 统一解释。

- 字段：`id`、`name_key`、`param_format`、`combat_only`
- 初始行数：16

### rarities.csv

首发三档稀有度与内容制作边界。

- 字段：`id`、`name_key`、`sort_order`、`price_min`、`price_max`、`power_scalar`
- 初始行数：3

### statuses.csv

持续状态配置。护甲与净化是即时战斗资源/效果，不在本表。

- 字段：`id`、`name_key`、`description_key`、`polarity`、`stack_cap`、`tick_interval`、`tick_rule`、`value_per_stack`、`decay_rule`、`default_duration`
- 初始行数：8

### items.csv

普通物品主定义。表现资源路径是待美术生产的稳定占位引用。

- 字段：`id`、`name_key`、`description_key`、`owner_pool`、`rarity`、`base_price`、`chapter_min`、`shape_id`、`tags`、`cooldown`、`stamina_cost`、`shop_enabled`、`crafted_only`、`power_score`、`icon_ref`、`vfx_ref`
- 初始行数：72

### item_effects.csv

物品触发器、条件、空间目标和效果明细。一个物品可通过追加行拥有第二效果。

- 字段：`id`、`item_id`、`sequence`、`trigger_id`、`internal_cooldown`、`condition_id`、`condition_params`、`spatial_template_id`、`target_selector`、`effect_type`、`effect_params`、`chain_depth_cost`
- 初始行数：72

### characters.csv

首发角色基础属性。

- 字段：`id`、`name_key`、`description_key`、`max_health`、`starting_health`、`stamina_max`、`stamina_regen_per_sec`、`base_crit_chance`、`base_crit_multiplier`、`passive_id`、`exclusive_tags`
- 初始行数：2

### character_passives.csv

角色常驻被动，全部使用通用触发和效果解释器。

- 字段：`id`、`character_id`、`trigger_id`、`condition_id`、`condition_params`、`effect_type`、`effect_params`、`per_combat_limit`
- 初始行数：2

### character_archetypes.csv

六种核心流派及商店倾向标签。

- 字段：`id`、`character_id`、`name_key`、`description_key`、`primary_tags`、`counter_tags`、`shop_bias_weight`
- 初始行数：6

### character_loadouts.csv

每个角色两套开局配置。

- 字段：`id`、`character_id`、`name_key`、`archetype_hint`、`starting_items`、`starting_bag_id`、`starting_gold`
- 初始行数：4

### starting_build_items.csv

开局普通物品的关系型布局。最终合法性由 Godot PlacementService 校验。

- 字段：`loadout_id`、`instance_id`、`item_id`、`origin_x`、`origin_y`、`rotation`
- 初始行数：8

### bag_shapes.csv

背包提供有效格的形状模板。

- 字段：`id`、`cells`、`cell_count`、`allowed_rotations`
- 初始行数：10

### bags.csv

背包层配置。开局背包价格为 0 且不进入商店。

- 字段：`id`、`name_key`、`description_key`、`rarity`、`base_price`、`chapter_min`、`shape_id`、`special_cell_type`、`special_cells`、`special_effect`、`availability`、`power_score`、`icon_ref`
- 初始行数：10

### recipes.csv

双材料、手动确认、最多两级的配方主表。

- 字段：`id`、`result_item_id`、`tier`、`placement_rule`、`manual_confirm`、`discovery_mode`、`chapter_min`
- 初始行数：24

### recipe_ingredients.csv

配方材料明细。

- 字段：`recipe_id`、`slot`、`item_id`、`consume`
- 初始行数：48

### game_rules.csv

全局规则常量，不应散落在代码中。

- 字段：`key`、`value`、`value_type`、`scope`、`description`
- 初始行数：24

### combat_rules.csv

战斗时长与稳定排序规则。

- 字段：`id`、`normal_min_seconds`、`normal_max_seconds`、`elite_min_seconds`、`elite_max_seconds`、`boss_min_seconds`、`boss_max_seconds`、`event_order`、`simultaneous_death_result`
- 初始行数：1

### shop_rules.csv

标准商店生成参数。

- 字段：`id`、`slots`、`discount_slots`、`discount_pct`、`lock_limit`、`bag_pity_count`、`pool_public_weight`、`pool_character_weight`、`pool_archetype_weight`、`duplicate_decay`
- 初始行数：1

### shop_slot_rules.csv

五个标准商店槽的行为定义。

- 字段：`shop_rule_id`、`slot_index`、`allowed_content`、`discount_eligible`、`locked_persists`
- 初始行数：5

### shop_rarity_curve.csv

章节商店稀有度权重，每行总和必须为 1。

- 字段：`act_id`、`common_weight`、`rare_weight`、`legendary_weight`
- 初始行数：3

### shop_pool_weights.csv

商店池来源权重。

- 字段：`id`、`source_pool`、`weight`、`max_effective_weight`、`requires_detected_archetype`
- 初始行数：3

### economy_curve.csv

章节经济与战后恢复曲线。

- 字段：`act_id`、`normal_gold`、`elite_bonus_gold`、`boss_gold`、`post_battle_heal_pct`、`interest_step`、`interest_cap`、`reward_skip_gold`
- 初始行数：3

### acts.csv

三章结构与成长目标。

- 字段：`id`、`name_key`、`order`、`regular_node_count`、`boss_node_count`、`storage_slots_gain`、`enemy_budget_min`、`enemy_budget_max`、`target_cells_min`、`target_cells_max`、`elite_min_candidates`
- 初始行数：3

### act_progression.csv

章节检查点的健康区间，不作为硬限制。

- 字段：`act_id`、`checkpoint`、`target_item_min`、`target_item_max`、`tier1_recipe_min`、`tier1_recipe_max`、`tier2_recipe_min`、`tier2_recipe_max`、`expected_gold_min`、`expected_gold_max`
- 初始行数：4

### node_templates.csv

路线候选节点类型。

- 字段：`id`、`name_key`、`node_type`、`enemy_budget_scalar`、`reward_table_id`、`shop_rule_id`
- 初始行数：7

### route_templates.csv

进入章节时一次性生成并保存的路线候选约束。

- 字段：`id`、`act_id`、`step`、`candidate_count_min`、`candidate_count_max`、`allowed_nodes`、`required_nodes`、`forbid_previous_types`
- 初始行数：15

### enemy_archetypes.csv

敌人构筑模板的机制分类。

- 字段：`id`、`name_key`、`threat_tags`、`weakness_tags`、`behavior_summary`
- 初始行数：12

### enemy_builds.csv

24 套普通敌人与 6 套精英敌人构筑。

- 字段：`id`、`name_key`、`act_id`、`node_type`、`archetype_id`、`tier`、`max_health`、`stamina_max`、`stamina_regen`、`power_budget`、`difficulty_min`、`difficulty_max`、`threat_tags`、`weakness_tags`、`affix_id`、`layout_version`
- 初始行数：30

### enemy_build_bags.csv

敌人构筑使用的背包实例布局。

- 字段：`enemy_build_id`、`instance_id`、`bag_id`、`origin_x`、`origin_y`、`rotation`
- 初始行数：60

### enemy_build_items.csv

敌人普通物品布局。导入编辑器后应再次通过 PlacementService 验证。

- 字段：`enemy_build_id`、`instance_id`、`item_id`、`origin_x`、`origin_y`、`rotation`
- 初始行数：99

### encounter_affixes.csv

危险战与精英可用的公开词缀。

- 字段：`id`、`name_key`、`description_key`、`trigger_id`、`effect_type`、`effect_params`、`budget_scalar`
- 初始行数：8

### encounter_templates.csv

章节遭遇池与重复限制。

- 字段：`id`、`act_id`、`node_type`、`enemy_build_pool`、`affix_pool`、`reward_table_id`、`repeat_limit`、`preview_detail`
- 初始行数：9

### bosses.csv

三个章节 Boss 主属性。

- 字段：`id`、`name_key`、`description_key`、`act_id`、`max_health`、`stamina_max`、`stamina_regen`、`threat_tags`、`weakness_tags`、`persistent_rule_id`、`reward_table_id`、`bag_layout`
- 初始行数：3

### boss_phases.csv

每个 Boss 最多一次生命阈值阶段变化。

- 字段：`boss_id`、`phase`、`health_threshold_pct`、`rule_id`、`effect_params`、`telegraph_seconds`
- 初始行数：6

### boss_build_items.csv

Boss 固定构筑及第二阶段追加组件。

- 字段：`boss_id`、`phase`、`instance_id`、`item_id`、`origin_x`、`origin_y`、`rotation`
- 初始行数：12

### run_effect_templates.csv

奖励、事件和休息节点使用的单局效果类型。

- 字段：`id`、`name_key`、`param_format`
- 初始行数：17

### reward_tables.csv

节点奖励选择规则。

- 字段：`id`、`name_key`、`choice_count`、`pick_count`、`allow_skip`、`skip_gold`、`selection_policy`
- 初始行数：5

### reward_entries.csv

奖励池明细。weight 只在同一奖励表和合法章节范围内归一化。

- 字段：`reward_table_id`、`id`、`reward_type`、`content_id`、`params`、`weight`、`act_min`、`act_max`
- 初始行数：20

### events.csv

路线事件主表。所有代价在确认前完整展示。

- 字段：`id`、`title_key`、`description_key`、`act_min`、`act_max`、`weight`、`once_per_run`、`preview_tags`
- 初始行数：12

### event_choices.csv

事件选择及显示条件。

- 字段：`id`、`event_id`、`text_key`、`requirements`、`effect_count`
- 初始行数：35

### event_choice_effects.csv

事件选择的顺序化结果。空效果表示安全离开。

- 字段：`choice_id`、`sequence`、`effect_type`、`params`
- 初始行数：52

### rest_actions.csv

休息节点二选一：恢复生命或复用二阶配方升级，无法升级时提供商店折扣券。

- 字段：`id`、`name_key`、`description_key`、`requirements`、`effect_count`、`uses_per_node`
- 初始行数：2

### rest_action_effects.csv

休息动作的顺序化效果。一次动作可以安全组合多个单局效果。

- 字段：`rest_action_id`、`sequence`、`effect_type`、`params`
- 初始行数：2

### difficulty_levels.csv

教学、标准、进阶与挑战 1 至 5 的完整难度曲线。

- 字段：`id`、`name_key`、`description_key`、`sort_order`、`mode`、`enemy_health_scalar`、`enemy_damage_scalar`、`enemy_status_scalar`、`gold_reward_scalar`、`shop_price_scalar`、`refresh_cost_delta`、`post_battle_heal_scalar`、`challenge_modifier_count`、`tutorial_prompts`
- 初始行数：8

### challenge_modifiers.csv

挑战难度按等级累积启用的公开规则。

- 字段：`id`、`challenge_level`、`name_key`、`description_key`、`rule_type`、`params`、`cumulative`
- 初始行数：5

### unlock_rules.csv

轻量解锁规则。没有经验等级、货币树或长期数值成长。

- 字段：`id`、`unlock_type`、`target_id`、`requirement_type`、`requirement_params`、`visible_before_unlock`
- 初始行数：12

### tutorial_steps.csv

首局分段教学。非阻塞步骤允许玩家继续操作。

- 字段：`id`、`step_order`、`scene_scope`、`trigger`、`blocking`、`required_action`、`title_key`、`body_key`
- 初始行数：16

### achievements.csv

Steam 成就与本地统计映射。Steam API 名称发布后不得修改。

- 字段：`id`、`steam_api_name`、`name_key`、`description_key`、`hidden`、`stat_key`、`comparison`、`target_value`
- 初始行数：20

### telemetry_metrics.csv

统计与平衡观测指标。release 默认仅保存在本地存档，不自动上传。

- 字段：`id`、`scope`、`value_type`、`aggregation`、`enabled_in_release`、`privacy_class`、`description`
- 初始行数：24

### stat_definitions.csv

由本地采集指标聚合得到的档案与单局统计定义，供成就和界面查询。

- 字段：`id`、`source_metric`、`aggregation`、`scope`、`value_type`、`reset_policy`、`default_value`、`description`
- 初始行数：19

### localization_zh_cn.csv

简体中文文本。

- 字段：`key`、`text`
- 初始行数：543

### localization_en.csv

英文文本。

- 字段：`key`、`text`
- 初始行数：543

### config_manifest.csv

配置文件清单与加载顺序。

- 字段：`file`、`schema_version`、`load_order`、`row_count`、`primary_key_hint`、`description`
- 初始行数：56

max_noncombat_nodes_per_act：game_rules中的整数，全局默认1；限制每章纯商人/事件/休息节点总数。类型、来源、版本和内容摘要都由标准编译器验证。
