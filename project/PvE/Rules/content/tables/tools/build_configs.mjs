import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { normalizeFacts } from "./audit_facts.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function csvCell(value) {
  const text = value == null ? "" : Array.isArray(value) ? value.join("|") : String(value);
  return /[",\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function writeCsv(name, columns, rows) {
  const lines = [columns.join(",")];
  for (const row of rows) lines.push(columns.map((column) => csvCell(row[column])).join(","));
  fs.writeFileSync(path.join(ROOT, name), `${lines.join("\n")}\n`, "utf8");
}

function writeText(name, text) {
  fs.writeFileSync(path.join(ROOT, name), `${text.trim()}\n`, "utf8");
}

const tables = {};
function table(name, columns, rows, description) {
  tables[name] = { columns, rows, description };
}

const loc = new Map();
function addLoc(key, zh, en) {
  loc.set(key, { key, zh_cn: zh, en });
  return key;
}

const tags = [
  ["weapon", "武器", "Weapon", "可主动造成物理伤害的物品"],
  ["armor", "护甲", "Armor", "生成护甲或依赖护甲的物品"],
  ["stamina", "耐力", "Stamina", "生成、节省或消耗耐力的物品"],
  ["tempo", "节奏", "Tempo", "修改冷却、推进或触发频率的物品"],
  ["heavy", "重型", "Heavy", "高伤害、高占格或长冷却物品"],
  ["combo", "连击", "Combo", "依靠多次命中与连续激活的物品"],
  ["counter", "反击", "Counter", "在受击、获得护甲或格挡后触发"],
  ["poison", "毒素", "Poison", "施加或利用毒层数"],
  ["burn", "灼烧", "Burn", "施加或利用灼烧层数"],
  ["healing", "治疗", "Healing", "恢复生命、再生或治疗转化"],
  ["cleanse", "净化", "Cleanse", "移除负面状态"],
  ["potion", "药剂", "Potion", "调配师常用的消耗与状态容器"],
  ["herb", "草药", "Herb", "恢复、毒素与合成材料"],
  ["spatial", "空间", "Spatial", "依赖邻接、方向、同行、同列或星位"],
  ["economy", "经济", "Economy", "影响金币、商店、刷新或出售"],
  ["utility", "工具", "Utility", "提供通用构筑功能"],
];

table("tags.csv", ["id", "name_key", "description_key", "category"], tags.map(([id, zh, en, desc]) => ({
  id,
  name_key: addLoc(`tag.${id}.name`, zh, en),
  description_key: addLoc(`tag.${id}.desc`, desc, desc),
  category: ["weapon", "armor", "stamina", "poison", "burn", "healing"].includes(id) ? "mechanic" : "support",
})), "物品、敌人和流派共用的标签字典。");

const shapes = [
  ["shape_1", "0:0", "0|90|180|270"],
  ["shape_2_h", "0:0|1:0", "0|90"],
  ["shape_3_i", "0:0|1:0|2:0", "0|90"],
  ["shape_3_l", "0:0|0:1|1:1", "0|90|180|270"],
  ["shape_3_v", "0:0|1:0|2:0|0:1|2:1", "0|90|180|270"],
  ["shape_4_o", "0:0|1:0|0:1|1:1", "0|90|180|270"],
  ["shape_4_t", "0:0|1:0|2:0|1:1", "0|90|180|270"],
  ["shape_4_z", "0:0|1:0|1:1|2:1", "0|90"],
  ["shape_4_l", "0:0|0:1|0:2|1:2", "0|90|180|270"],
  ["shape_5_p", "0:0|1:0|0:1|1:1|0:2", "0|90|180|270"],
];
table("item_shapes.csv", ["id", "cells", "allowed_rotations", "cell_count"], shapes.map(([id, cells, rotations]) => ({
  id, cells, allowed_rotations: rotations, cell_count: cells.split("|").length,
})), "普通物品形状模板。相对坐标使用 x:y，列表使用竖线分隔。");

const spatialTemplates = [
  ["none", "none", 0, "0:0", false],
  ["adjacent_4", "adjacent_4", 1, "-1:0|1:0|0:-1|0:1", true],
  ["adjacent_8", "adjacent_8", 1, "-1:-1|0:-1|1:-1|-1:0|1:0|-1:1|0:1|1:1", true],
  ["front_1", "front", 1, "1:0", true],
  ["front_2", "front", 2, "1:0|2:0", true],
  ["front_3", "front", 3, "1:0|2:0|3:0", true],
  ["same_row", "same_row", 9, "", false],
  ["same_column", "same_column", 7, "", false],
  ["star_cell", "star_cell", 1, "", false],
  ["same_bag", "same_bag", 0, "", false],
  ["global_same_tag", "global_same_tag", 0, "", false],
];
table("spatial_templates.csv", ["id", "relation_type", "range", "relative_cells", "rotates_with_source"], spatialTemplates.map(([id, relation_type, range, relative_cells, rotates]) => ({ id, relation_type, range, relative_cells, rotates_with_source: rotates })), "首发允许使用的空间关系模板。");

const triggers = [
  ["combat_start", "战斗开始", "Combat Start", 10],
  ["cooldown_ready", "冷却完成", "Cooldown Ready", 50],
  ["attack_hit", "攻击命中", "Attack Hit", 60],
  ["critical_hit", "造成暴击", "Critical Hit", 70],
  ["target_activated", "目标激活后", "Target Activated", 80],
  ["damage_taken", "受到伤害", "Damage Taken", 90],
  ["armor_gained", "获得护甲", "Armor Gained", 100],
  ["status_applied", "施加状态", "Status Applied", 110],
  ["first_low_health", "首次低生命", "First Low Health", 120],
  ["interval", "定时", "Interval", 130],
  ["fatigue_start", "疲劳开始", "Fatigue Start", 140],
];
table("trigger_templates.csv", ["id", "name_key", "priority", "default_internal_cooldown"], triggers.map(([id, zh, en, priority]) => ({
  id, name_key: addLoc(`trigger.${id}.name`, zh, en), priority, default_internal_cooldown: ["attack_hit", "damage_taken", "armor_gained", "status_applied", "target_activated"].includes(id) ? 0.5 : 0,
})), "战斗事件触发器模板。");

const conditions = [
  ["always", "始终满足", "Always"],
  ["source_has_tag", "来源拥有标签", "Source Has Tag"],
  ["target_has_tag", "目标拥有标签", "Target Has Tag"],
  ["spatial_target_count", "空间目标数量", "Spatial Target Count"],
  ["health_below_pct", "生命低于比例", "Health Below Percent"],
  ["health_above_pct", "生命高于比例", "Health Above Percent"],
  ["resource_at_least", "资源不少于", "Resource At Least"],
  ["status_stacks_at_least", "状态层数不少于", "Status Stacks At Least"],
  ["trigger_count_max", "触发次数上限", "Trigger Count Maximum"],
  ["build_tag_count", "构筑标签数量", "Build Tag Count"],
  ["enemy_has_status", "敌人拥有状态", "Enemy Has Status"],
  ["overheal_positive", "存在溢出治疗", "Overheal Positive"],
];
table("condition_templates.csv", ["id", "name_key", "param_format"], conditions.map(([id, zh, en]) => ({
  id, name_key: addLoc(`condition.${id}.name`, zh, en), param_format: id === "always" ? "" : "key:value",
})), "触发条件模板。首发条件组合只支持全部满足。");

const effects = [
  ["physical_damage", "造成物理伤害", "Deal Physical Damage", "amount"],
  ["true_damage", "造成真实伤害", "Deal True Damage", "amount"],
  ["gain_armor", "获得护甲", "Gain Armor", "amount"],
  ["heal", "恢复生命", "Heal", "amount"],
  ["gain_stamina", "获得耐力", "Gain Stamina", "amount"],
  ["apply_status", "施加状态", "Apply Status", "status_id|stacks|duration"],
  ["remove_status", "移除状态", "Remove Status", "status_id|stacks"],
  ["convert_status", "转化状态", "Convert Status", "from|to|ratio"],
  ["modify_cooldown_pct", "修改冷却比例", "Modify Cooldown Percent", "value|duration"],
  ["modify_damage_flat", "修改伤害", "Modify Damage", "value|duration"],
  ["modify_crit_chance", "修改暴击率", "Modify Critical Chance", "value|duration"],
  ["modify_status_power", "修改状态强度", "Modify Status Power", "value|duration"],
  ["advance_cooldown", "推进目标冷却", "Advance Target Cooldown", "seconds"],
  ["gain_gold", "获得金币", "Gain Gold", "amount"],
  ["free_refresh", "获得免费刷新", "Gain Free Refresh", "count"],
  ["max_health", "修改最大生命", "Modify Maximum Health", "amount"],
];
table("effect_templates.csv", ["id", "name_key", "param_format", "combat_only"], effects.map(([id, zh, en, format]) => ({
  id, name_key: addLoc(`effect.${id}.name`, zh, en), param_format: format, combat_only: !["gain_gold", "free_refresh", "max_health"].includes(id),
})), "通用效果模板。运行时由 EffectResolver 统一解释。");

const rarityRows = [
  ["common", "普通", "Common", 1, 2, 6, 1],
  ["rare", "稀有", "Rare", 2, 6, 9, 1.35],
  ["legendary", "传奇", "Legendary", 3, 10, 14, 1.75],
];
table("rarities.csv", ["id", "name_key", "sort_order", "price_min", "price_max", "power_scalar"], rarityRows.map(([id, zh, en, order, min, max, scalar]) => ({
  id, name_key: addLoc(`rarity.${id}.name`, zh, en), sort_order: order, price_min: min, price_max: max, power_scalar: scalar,
})), "首发三档稀有度与内容制作边界。");

const statusRows = [
  ["poison", "毒", "Poison", "negative", 99, 1, "damage_equal_stacks", 1, "decrease_flat", 1],
  ["burn", "灼烧", "Burn", "negative", 99, 0.5, "damage_half_stacks_min1", 1, "decrease_flat", 1],
  ["slow", "减速", "Slow", "negative", 10, 1, "cooldown_progress_down_pct", 0.05, "duration", 4],
  ["regeneration", "再生", "Regeneration", "positive", 30, 1, "heal_equal_stacks", 1, "decrease_flat", 1],
  ["lifesteal", "吸血", "Lifesteal", "positive", 10, 0, "lifesteal_pct", 0.03, "duration", 5],
  ["vulnerable", "易伤", "Vulnerable", "negative", 10, 0, "life_damage_taken_pct", 0.04, "duration", 4],
  ["haste", "加速", "Haste", "positive", 10, 0, "cooldown_progress_up_pct", 0.04, "duration", 4],
  ["fortified", "坚固", "Fortified", "positive", 10, 0, "physical_damage_reduction_pct", 0.04, "duration", 4],
];
table("statuses.csv", ["id", "name_key", "description_key", "polarity", "stack_cap", "tick_interval", "tick_rule", "value_per_stack", "decay_rule", "default_duration"], statusRows.map(([id, zh, en, polarity, cap, tick, rule, value, decay, duration]) => ({
  id,
  name_key: addLoc(`status.${id}.name`, zh, en),
  description_key: addLoc(`status.${id}.desc`, `${zh}的统一战斗规则。`, `${en} uses the shared combat status rule.`),
  polarity, stack_cap: cap, tick_interval: tick, tick_rule: rule, value_per_stack: value, decay_rule: decay, default_duration: duration,
})), "持续状态配置。护甲与净化是即时战斗资源/效果，不在本表。");

const itemSpecs = [];
function item(id, zh, en, owner, rarity, price, chapter, shape, tagsList, cooldown, stamina, trigger, effectType, amount, target = "enemy", spatial = "none", condition = "always", flags = "shop") {
  const descriptionZh = describeItemZh(trigger, effectType, amount, target, spatial, condition, cooldown, stamina);
  const descriptionEn = describeItemEn(trigger, effectType, amount, target, spatial, condition, cooldown, stamina);
  itemSpecs.push({ id, zh, en, owner, rarity, price, chapter, shape, tags: tagsList, cooldown, stamina, trigger, effectType, amount, target, spatial, condition, flags, descriptionZh, descriptionEn });
}

function describeItemZh(trigger, effect, amount, target, spatial, condition, cooldown, stamina) {
  const triggerText = { combat_start: "战斗开始", cooldown_ready: `每 ${cooldown.toFixed(1)} 秒`, attack_hit: "攻击命中后", critical_hit: "暴击后", target_activated: "作用目标激活后", damage_taken: "受到伤害后", armor_gained: "获得护甲后", status_applied: "施加状态后", first_low_health: "首次低生命时", interval: `每 ${cooldown.toFixed(1)} 秒`, fatigue_start: "疲劳开始时" }[trigger];
  const effectText = { physical_damage: `造成 ${amount} 点物理伤害`, true_damage: `造成 ${amount} 点真实伤害`, gain_armor: `获得 ${amount} 点护甲`, heal: `恢复 ${amount} 点生命`, gain_stamina: `获得 ${amount} 点耐力`, apply_status: `施加 ${amount}`, remove_status: `移除 ${amount} 层负面状态`, modify_cooldown_pct: `使目标冷却改变 ${amount}`, modify_damage_flat: `使目标伤害改变 ${amount}`, modify_crit_chance: `使目标暴击率改变 ${amount}`, modify_status_power: `使目标状态强度改变 ${amount}`, advance_cooldown: `推进目标 ${amount} 秒冷却`, gain_gold: `战后获得 ${amount} 金币`, free_refresh: `获得 ${amount} 次免费刷新` }[effect] ?? `${effect} ${amount}`;
  const extras = [];
  if (spatial !== "none") extras.push(`作用范围：${spatial}`);
  if (condition !== "always") extras.push(`条件：${condition}`);
  if (stamina > 0) extras.push(`消耗 ${stamina} 耐力`);
  return `${triggerText}：${effectText}。${extras.length ? `${extras.join("；")}。` : ""}`;
}

function describeItemEn(trigger, effect, amount, target, spatial, condition, cooldown, stamina) {
  const triggerText = { combat_start: "Combat start", cooldown_ready: `Every ${cooldown.toFixed(1)}s`, attack_hit: "After hitting", critical_hit: "After a critical hit", target_activated: "After a target activates", damage_taken: "After taking damage", armor_gained: "After gaining armor", status_applied: "After applying a status", first_low_health: "The first time health is low", interval: `Every ${cooldown.toFixed(1)}s`, fatigue_start: "When fatigue starts" }[trigger];
  const effectText = { physical_damage: `deal ${amount} physical damage`, true_damage: `deal ${amount} true damage`, gain_armor: `gain ${amount} armor`, heal: `heal ${amount}`, gain_stamina: `gain ${amount} stamina`, apply_status: `apply ${amount}`, remove_status: `remove ${amount} negative stacks`, modify_cooldown_pct: `change target cooldown by ${amount}`, modify_damage_flat: `change target damage by ${amount}`, modify_crit_chance: `change target critical chance by ${amount}`, modify_status_power: `change target status power by ${amount}`, advance_cooldown: `advance target cooldown by ${amount}s`, gain_gold: `gain ${amount} gold after combat`, free_refresh: `gain ${amount} free refresh` }[effect] ?? `${effect} ${amount}`;
  const extras = [];
  if (spatial !== "none") extras.push(`area: ${spatial}`);
  if (condition !== "always") extras.push(`condition: ${condition}`);
  if (stamina > 0) extras.push(`costs ${stamina} stamina`);
  return `${triggerText}: ${effectText}.${extras.length ? ` ${extras.join("; ")}.` : ""}`;
}

// Public pool: 44 items.
item("utility_knife", "便携小刀", "Utility Knife", "public", "common", 2, 1, "shape_1", ["weapon", "combo"], 2.4, 1, "cooldown_ready", "physical_damage", 4);
item("iron_sword", "铁脊长剑", "Ironspine Sword", "public", "rare", 7, 1, "shape_3_i", ["weapon", "combo"], 3.4, 2, "cooldown_ready", "physical_damage", 10, "enemy", "front_1", "spatial_target_count>=1", "crafted");
item("broad_axe", "宽刃斧", "Broad Axe", "public", "common", 5, 1, "shape_3_l", ["weapon", "heavy"], 5.5, 3, "cooldown_ready", "physical_damage", 14);
item("stone_hammer", "石击锤", "Stone Hammer", "public", "common", 5, 1, "shape_3_i", ["weapon", "heavy"], 6.2, 3, "cooldown_ready", "physical_damage", 16);
item("hunting_spear", "猎路长矛", "Trail Spear", "public", "common", 4, 1, "shape_3_i", ["weapon", "spatial"], 4.5, 2, "cooldown_ready", "physical_damage", 11, "enemy", "front_2");
item("twin_needles", "双针", "Twin Needles", "public", "common", 4, 1, "shape_2_h", ["weapon", "combo"], 2.1, 1, "cooldown_ready", "physical_damage", 4);
item("sling", "机索投带", "Gear Sling", "public", "common", 3, 1, "shape_2_h", ["weapon", "tempo"], 3.0, 1, "cooldown_ready", "physical_damage", 6);
item("heavy_cleaver", "断梁重刃", "Beam Cleaver", "public", "rare", 8, 2, "shape_4_l", ["weapon", "heavy"], 6.8, 4, "cooldown_ready", "physical_damage", 24, "enemy", "front_1", "always", "crafted");
item("buckler", "圆扣盾", "Round Buckler", "public", "common", 3, 1, "shape_2_h", ["armor", "counter"], 4.0, 0, "cooldown_ready", "gain_armor", 5, "self");
item("plated_vest", "拼片甲", "Patchplate Vest", "public", "common", 5, 1, "shape_4_o", ["armor"], 5.0, 0, "cooldown_ready", "gain_armor", 8, "self");
item("tower_shield", "高壁盾", "Highwall Shield", "public", "rare", 8, 2, "shape_4_l", ["armor", "heavy"], 6.5, 0, "cooldown_ready", "gain_armor", 13, "self");
item("spiked_guard", "棘面护板", "Spiked Guard", "public", "rare", 7, 1, "shape_3_l", ["armor", "counter"], 0, 0, "damage_taken", "physical_damage", 4, "enemy", "none", "trigger_count_max:8", "crafted");
item("leather_wrap", "韧皮缠带", "Tough Wrap", "public", "common", 3, 1, "shape_2_h", ["armor", "utility"], 5.0, 0, "cooldown_ready", "gain_armor", 4, "self", "adjacent_4");
item("repair_kit", "修缮包", "Repair Kit", "public", "common", 4, 1, "shape_3_l", ["armor", "healing", "utility"], 6.0, 0, "cooldown_ready", "heal", 4, "self", "adjacent_4", "target_has_tag:armor");
item("stamina_flask", "耐力壶", "Stamina Flask", "public", "common", 3, 1, "shape_2_h", ["stamina", "potion"], 5.0, 0, "cooldown_ready", "gain_stamina", 3, "self");
item("travel_ration", "行军口粮", "Trail Ration", "public", "common", 3, 1, "shape_2_h", ["healing", "stamina"], 7.0, 0, "cooldown_ready", "heal", 4, "self");
item("bandage_roll", "绷带卷", "Bandage Roll", "public", "common", 2, 1, "shape_1", ["healing", "utility"], 6.0, 0, "cooldown_ready", "heal", 3, "self");
item("cleansing_salt", "澄净盐", "Cleansing Salt", "public", "common", 4, 1, "shape_1", ["cleanse", "utility"], 8.0, 0, "cooldown_ready", "remove_status", 3, "self");
item("sharpening_stone", "磨锋石", "Sharpening Stone", "public", "common", 3, 1, "shape_1", ["weapon", "spatial"], 0, 0, "combat_start", "modify_damage_flat", 2, "spatial_targets", "adjacent_4", "target_has_tag:weapon");
item("clockwork_spring", "发条簧", "Clockwork Spring", "public", "common", 4, 1, "shape_2_h", ["tempo", "spatial"], 0, 0, "combat_start", "modify_cooldown_pct", -0.08, "spatial_targets", "adjacent_4");
item("lucky_coin", "缺角幸运币", "Notched Lucky Coin", "public", "common", 3, 1, "shape_1", ["economy", "utility"], 0, 0, "combat_start", "gain_gold", 1, "self", "none", "health_above_pct:0.5");
item("scout_lens", "斥候镜", "Scout Lens", "public", "common", 3, 1, "shape_2_h", ["utility", "spatial"], 0, 0, "combat_start", "modify_crit_chance", 0.06, "spatial_targets", "front_2", "target_has_tag:weapon");
item("merchant_token", "商路筹码", "Trade Token", "public", "common", 3, 1, "shape_1", ["economy"], 0, 0, "combat_start", "free_refresh", 1, "self", "none", "trigger_count_max:1");
item("storage_hook", "仓储挂钩", "Storage Hook", "public", "common", 4, 1, "shape_2_h", ["utility", "spatial"], 0, 0, "combat_start", "gain_armor", 2, "self", "same_bag", "spatial_target_count>=3");
item("gear_link", "联动齿节", "Gear Link", "public", "common", 3, 1, "shape_1", ["tempo", "spatial"], 0, 0, "target_activated", "advance_cooldown", 0.25, "spatial_targets", "adjacent_4", "trigger_count_max:10");
item("focus_prism", "聚焦棱镜", "Focus Prism", "public", "rare", 6, 1, "shape_3_l", ["spatial", "utility"], 0, 0, "combat_start", "modify_damage_flat", 3, "spatial_targets", "front_3", "target_has_tag:weapon");
item("row_banner", "横列旗", "Row Banner", "public", "common", 5, 1, "shape_3_i", ["spatial", "utility"], 0, 0, "combat_start", "modify_damage_flat", 1, "spatial_targets", "same_row");
item("column_standard", "纵阵标", "Column Standard", "public", "common", 5, 1, "shape_3_i", ["spatial", "armor"], 0, 0, "combat_start", "gain_armor", 2, "spatial_targets", "same_column");
item("star_compass", "星位罗盘", "Star Compass", "public", "rare", 7, 2, "shape_3_l", ["spatial", "tempo"], 0, 0, "combat_start", "modify_cooldown_pct", -0.12, "spatial_targets", "star_cell");
item("compact_rack", "紧凑支架", "Compact Rack", "public", "common", 4, 1, "shape_2_h", ["spatial", "utility"], 0, 0, "combat_start", "gain_armor", 3, "self", "adjacent_8", "spatial_target_count>=4");
item("resonant_bell", "共鸣铃", "Resonant Bell", "public", "rare", 6, 2, "shape_2_h", ["tempo", "spatial"], 0, 0, "target_activated", "gain_stamina", 1, "self", "adjacent_4", "trigger_count_max:8");
item("counterweight", "平衡配重", "Counterweight", "public", "common", 4, 1, "shape_3_l", ["heavy", "spatial"], 0, 0, "combat_start", "modify_damage_flat", 4, "spatial_targets", "front_1", "target_has_tag:heavy");
item("venom_needle", "毒刺针", "Venom Needle", "public", "common", 3, 1, "shape_1", ["weapon", "poison"], 3.5, 1, "cooldown_ready", "apply_status", "poison:2", "enemy");
item("ember_stone", "余烬石", "Ember Stone", "public", "common", 3, 1, "shape_2_h", ["burn", "spatial"], 4.0, 0, "cooldown_ready", "apply_status", "burn:2", "enemy");
item("healing_herb", "愈合草", "Mending Herb", "public", "common", 3, 1, "shape_1", ["healing", "herb"], 5.5, 0, "cooldown_ready", "heal", 4, "self");
item("regeneration_leaf", "复生叶", "Renewal Leaf", "public", "common", 4, 1, "shape_2_h", ["healing", "herb"], 6.0, 0, "cooldown_ready", "apply_status", "regeneration:3", "self");
item("fracture_charm", "裂痕符", "Fracture Charm", "public", "common", 4, 1, "shape_1", ["utility", "combo"], 4.5, 0, "cooldown_ready", "apply_status", "vulnerable:1", "enemy");
item("quicksand_vial", "流沙瓶", "Quicksand Vial", "public", "rare", 6, 2, "shape_2_h", ["potion", "tempo"], 6.0, 0, "cooldown_ready", "apply_status", "slow:2", "enemy");
item("blood_cup", "赤液杯", "Crimson Cup", "public", "rare", 7, 2, "shape_2_h", ["healing", "combo"], 0, 0, "attack_hit", "apply_status", "lifesteal:1", "self", "none", "trigger_count_max:6");
item("cooling_fan", "散热扇", "Cooling Fan", "public", "common", 4, 1, "shape_3_l", ["tempo", "burn"], 0, 0, "status_applied", "advance_cooldown", 0.3, "spatial_targets", "front_2", "enemy_has_status:burn");
item("iron_nail", "铆接铁钉", "Rivet Nail", "public", "common", 2, 1, "shape_1", ["armor", "counter"], 0, 0, "armor_gained", "physical_damage", 2, "enemy", "none", "trigger_count_max:8");
item("glass_bead", "折光玻珠", "Refracting Bead", "public", "common", 3, 1, "shape_1", ["spatial", "utility"], 0, 0, "combat_start", "modify_status_power", 0.1, "spatial_targets", "adjacent_8");
item("field_manual", "随军手册", "Field Manual", "public", "rare", 6, 2, "shape_3_l", ["utility", "spatial"], 0, 0, "combat_start", "modify_damage_flat", 1, "spatial_targets", "global_same_tag", "build_tag_count:4");
item("salvage_pouch", "回收钱袋", "Salvage Pouch", "public", "rare", 6, 2, "shape_2_h", ["economy", "utility"], 0, 0, "combat_start", "gain_gold", 2, "self", "none", "health_above_pct:0.6", "crafted");

// Armorer pool: 14 items.
item("arsenal_bracer", "武库腕轮", "Arsenal Bracer", "armorer", "common", 4, 1, "shape_2_h", ["weapon", "combo", "spatial"], 0, 0, "combat_start", "modify_crit_chance", 0.04, "spatial_targets", "adjacent_4", "target_has_tag:weapon");
item("chain_blade", "链节刃", "Chain Blade", "armorer", "rare", 8, 2, "shape_4_z", ["weapon", "combo", "tempo"], 3.0, 2, "cooldown_ready", "physical_damage", 11, "enemy", "adjacent_4", "spatial_target_count>=2", "crafted");
item("repeater_crossbow", "轮转弩", "Repeater Crossbow", "armorer", "rare", 8, 2, "shape_4_t", ["weapon", "combo", "stamina"], 2.0, 1, "cooldown_ready", "physical_damage", 7, "enemy", "front_2", "always", "crafted");
item("crescent_glaive", "新月战镰", "Crescent Glaive", "armorer", "rare", 9, 2, "shape_5_p", ["weapon", "heavy", "spatial"], 5.8, 3, "cooldown_ready", "physical_damage", 21, "enemy", "front_3", "spatial_target_count>=1", "crafted");
item("siege_maul", "攻城槌", "Siege Maul", "armorer", "legendary", 13, 3, "shape_5_p", ["weapon", "heavy"], 7.5, 5, "cooldown_ready", "physical_damage", 30, "enemy", "front_1", "always", "crafted");
item("momentum_gear", "势能齿轮", "Momentum Gear", "armorer", "rare", 7, 2, "shape_3_l", ["tempo", "stamina", "spatial"], 0, 0, "target_activated", "gain_stamina", 1, "self", "adjacent_4", "trigger_count_max:8", "crafted");
item("duelist_mark", "决斗印记", "Duelist Mark", "armorer", "rare", 7, 2, "shape_2_h", ["combo", "spatial"], 0, 0, "critical_hit", "advance_cooldown", 0.5, "spatial_targets", "same_row", "trigger_count_max:6", "crafted");
item("overdrive_ratchet", "超载棘轮", "Overdrive Ratchet", "armorer", "legendary", 12, 3, "shape_4_t", ["tempo", "stamina", "combo"], 0, 0, "attack_hit", "advance_cooldown", 0.2, "spatial_targets", "adjacent_8", "trigger_count_max:12", "crafted");
item("bastion_core", "壁垒核心", "Bastion Core", "armorer", "legendary", 12, 3, "shape_4_o", ["armor", "counter"], 4.0, 0, "cooldown_ready", "gain_armor", 12, "self", "same_bag", "build_tag_count:3", "crafted");
item("layered_plates", "叠层甲片", "Layered Plates", "armorer", "rare", 8, 2, "shape_4_z", ["armor", "counter"], 5.0, 0, "cooldown_ready", "gain_armor", 10, "self", "adjacent_4", "target_has_tag:armor", "crafted");
item("retaliation_spikes", "回击尖刺", "Retaliation Spikes", "armorer", "rare", 7, 2, "shape_3_l", ["armor", "counter"], 0, 0, "armor_gained", "physical_damage", 5, "enemy", "none", "trigger_count_max:8", "crafted");
item("guardian_standard", "守阵旗", "Guardian Standard", "armorer", "common", 5, 1, "shape_3_i", ["armor", "spatial"], 0, 0, "combat_start", "gain_armor", 3, "spatial_targets", "same_column", "target_has_tag:armor");
item("charging_weight", "蓄势铁坠", "Charging Weight", "armorer", "common", 4, 1, "shape_3_l", ["heavy", "stamina"], 6.0, 0, "cooldown_ready", "gain_stamina", 4, "self");
item("execution_anvil", "终击砧", "Execution Anvil", "armorer", "legendary", 14, 3, "shape_5_p", ["heavy", "spatial", "weapon"], 0, 0, "combat_start", "modify_damage_flat", 8, "spatial_targets", "front_1", "target_has_tag:heavy", "crafted");

// Alchemist pool: 14 items.
item("toxin_bottle", "毒素瓶", "Toxin Bottle", "alchemist", "common", 5, 1, "shape_2_h", ["potion", "poison"], 4.0, 0, "cooldown_ready", "apply_status", "poison:4", "enemy", "none", "always", "crafted");
item("thorn_extract", "棘刺萃液", "Thorn Extract", "alchemist", "common", 4, 1, "shape_1", ["herb", "poison", "spatial"], 0, 0, "status_applied", "apply_status", "poison:1", "enemy", "adjacent_4", "target_has_tag:poison");
item("spore_jar", "孢尘罐", "Spore Jar", "alchemist", "common", 5, 1, "shape_3_l", ["potion", "poison"], 6.0, 0, "cooldown_ready", "apply_status", "poison:6", "enemy");
item("venom_distiller", "剧毒蒸馏器", "Venom Distiller", "alchemist", "rare", 8, 2, "shape_4_t", ["potion", "poison", "tempo"], 0, 0, "status_applied", "advance_cooldown", 0.4, "spatial_targets", "adjacent_4", "enemy_has_status:poison", "crafted");
item("plague_retort", "瘴雾曲颈瓶", "Plague Retort", "alchemist", "legendary", 13, 3, "shape_5_p", ["potion", "poison"], 5.0, 0, "cooldown_ready", "apply_status", "poison:10", "enemy", "same_bag", "build_tag_count:4", "crafted");
item("caustic_coil", "蚀液盘管", "Caustic Coil", "alchemist", "rare", 7, 2, "shape_4_z", ["poison", "spatial"], 0, 0, "status_applied", "true_damage", 2, "enemy", "adjacent_8", "enemy_has_status:poison");
item("ember_phial", "焰芯瓶", "Ember Phial", "alchemist", "common", 5, 1, "shape_2_h", ["potion", "burn"], 3.5, 0, "cooldown_ready", "apply_status", "burn:4", "enemy", "none", "always", "crafted");
item("coal_burner", "炭火炉", "Coal Burner", "alchemist", "common", 5, 1, "shape_3_l", ["burn", "spatial"], 5.0, 0, "cooldown_ready", "apply_status", "burn:5", "enemy", "front_2");
item("ignition_lens", "引燃透镜", "Ignition Lens", "alchemist", "rare", 7, 2, "shape_3_l", ["burn", "spatial", "tempo"], 0, 0, "status_applied", "advance_cooldown", 0.35, "spatial_targets", "front_3", "enemy_has_status:burn", "crafted");
item("wildfire_alembic", "野火蒸馏釜", "Wildfire Alembic", "alchemist", "legendary", 13, 3, "shape_5_p", ["potion", "burn", "tempo"], 4.5, 0, "cooldown_ready", "apply_status", "burn:9", "enemy", "adjacent_8", "spatial_target_count>=3", "crafted");
item("tonic_bottle", "复元补剂", "Restorative Tonic", "alchemist", "common", 5, 1, "shape_2_h", ["potion", "healing"], 5.0, 0, "cooldown_ready", "heal", 7, "self", "none", "always", "crafted");
item("renewal_mortar", "生息研钵", "Renewal Mortar", "alchemist", "rare", 7, 2, "shape_3_l", ["herb", "healing", "spatial"], 0, 0, "status_applied", "apply_status", "regeneration:1", "self", "adjacent_4", "source_has_tag:healing");
item("transfusion_tube", "回流导管", "Transfusion Tube", "alchemist", "rare", 8, 2, "shape_4_z", ["healing", "combo"], 0, 0, "attack_hit", "heal", 2, "self", "adjacent_4", "trigger_count_max:8", "crafted");
item("philosophers_kettle", "回生炼釜", "Revival Kettle", "alchemist", "legendary", 14, 3, "shape_4_o", ["potion", "healing"], 0, 0, "first_low_health", "heal", 24, "self", "same_bag", "trigger_count_max:1", "crafted");

table("items.csv", ["id", "name_key", "description_key", "owner_pool", "rarity", "base_price", "chapter_min", "shape_id", "tags", "cooldown", "stamina_cost", "shop_enabled", "crafted_only", "power_score", "icon_ref", "vfx_ref"], itemSpecs.map((it) => ({
  id: it.id,
  name_key: addLoc(`item.${it.id}.name`, it.zh, it.en),
  description_key: addLoc(`item.${it.id}.desc`, it.descriptionZh, it.descriptionEn),
  owner_pool: it.owner,
  rarity: it.rarity,
  base_price: it.price,
  chapter_min: it.chapter,
  shape_id: it.shape,
  tags: it.tags,
  cooldown: it.cooldown,
  stamina_cost: it.stamina,
  shop_enabled: !it.flags.includes("crafted"),
  crafted_only: it.flags.includes("crafted"),
  power_score: Math.round(it.price * ({ common: 1, rare: 1.35, legendary: 1.7 }[it.rarity]) * 10) / 10,
  icon_ref: `res://assets/items/${it.id}.png`,
  vfx_ref: `item_${it.effectType}`,
})), "普通物品主定义。表现资源路径是待美术生产的稳定占位引用。");

table("item_effects.csv", ["id", "item_id", "sequence", "trigger_id", "internal_cooldown", "condition_id", "condition_params", "spatial_template_id", "target_selector", "effect_type", "effect_params", "chain_depth_cost"], itemSpecs.map((it) => {
  const [condition_id, conditionValue = ""] = it.condition.includes(":") ? it.condition.split(":", 2) : it.condition.includes(">=") ? [it.condition.split(">=")[0], `min:${it.condition.split(">=")[1]}`] : [it.condition, ""];
  return {
    id: `${it.id}_effect_1`, item_id: it.id, sequence: 1, trigger_id: it.trigger,
    internal_cooldown: ["attack_hit", "damage_taken", "armor_gained", "status_applied", "target_activated", "critical_hit"].includes(it.trigger) ? 0.5 : 0,
    condition_id, condition_params: conditionValue,
    spatial_template_id: it.spatial, target_selector: it.target,
    effect_type: it.effectType, effect_params: `value:${it.amount}`,
    chain_depth_cost: ["modify_cooldown_pct", "advance_cooldown"].includes(it.effectType) ? 2 : 1,
  };
}), "物品触发器、条件、空间目标和效果明细。一个物品可通过追加行拥有第二效果。");

const characters = [
  { id: "armorer", zh: "铸阵师", en: "Forge Warden", hp: 105, stamina: 10, regen: 1.7, crit: 0.05, passive: "armorer_shape_mastery", tags: "weapon|armor|tempo" },
  { id: "alchemist", zh: "调律师", en: "Field Alchemist", hp: 95, stamina: 10, regen: 1.8, crit: 0.05, passive: "alchemist_first_reaction", tags: "potion|poison|burn|healing" },
];
table("characters.csv", ["id", "name_key", "description_key", "max_health", "starting_health", "stamina_max", "stamina_regen_per_sec", "base_crit_chance", "base_crit_multiplier", "passive_id", "exclusive_tags"], characters.map((c) => ({
  id: c.id,
  name_key: addLoc(`character.${c.id}.name`, c.zh, c.en),
  description_key: addLoc(`character.${c.id}.desc`, c.id === "armorer" ? "使用武器形状、护甲与耐力联动建立稳定阵线。" : "使用毒、灼烧和治疗转化控制战斗节奏。", c.id === "armorer" ? "Builds stable formations through weapon shapes, armor, and stamina links." : "Controls combat tempo with poison, burn, and healing conversion."),
  max_health: c.hp, starting_health: c.hp, stamina_max: c.stamina, stamina_regen_per_sec: c.regen,
  base_crit_chance: c.crit, base_crit_multiplier: 1.5, passive_id: c.passive, exclusive_tags: c.tags,
})), "首发角色基础属性。");

table("character_passives.csv", ["id", "character_id", "trigger_id", "condition_id", "condition_params", "effect_type", "effect_params", "per_combat_limit"], [
  { id: "armorer_shape_mastery", character_id: "armorer", trigger_id: "attack_hit", condition_id: "build_tag_count", condition_params: "distinct_weapon_shapes:1", effect_type: "modify_damage_flat", effect_params: "value:1|max_stacks:3", per_combat_limit: 3 },
  { id: "alchemist_first_reaction", character_id: "alchemist", trigger_id: "status_applied", condition_id: "trigger_count_max", condition_params: "new_negative_status_only:true", effect_type: "heal", effect_params: "value:2", per_combat_limit: 3 },
], "角色常驻被动，全部使用通用触发和效果解释器。");

const archetypes = [
  ["combo_arsenal", "armorer", "连击武库", "Combo Arsenal", "combo|weapon|stamina", "armor", 1],
  ["armor_counter", "armorer", "护甲反击", "Armor Counter", "armor|counter", "poison|burn", 1],
  ["heavy_charge", "armorer", "重击蓄力", "Heavy Charge", "heavy|weapon|spatial", "slow|armor", 1],
  ["toxin_stack", "alchemist", "毒素累积", "Toxin Stack", "poison|potion|tempo", "cleanse|burst", 1],
  ["burn_rhythm", "alchemist", "灼烧节奏", "Burn Rhythm", "burn|tempo|spatial", "healing|cleanse", 1],
  ["healing_conversion", "alchemist", "治疗转化", "Healing Conversion", "healing|herb|combo", "heavy|burst", 1],
];
table("character_archetypes.csv", ["id", "character_id", "name_key", "description_key", "primary_tags", "counter_tags", "shop_bias_weight"], archetypes.map(([id, character_id, zh, en, primary, counter, weight]) => ({
  id, character_id, name_key: addLoc(`archetype.${id}.name`, zh, en),
  description_key: addLoc(`archetype.${id}.desc`, `围绕${zh}构建空间与经济决策。`, `Build spatial and economic decisions around ${en}.`),
  primary_tags: primary, counter_tags: counter, shop_bias_weight: weight,
})), "六种核心流派及商店倾向标签。");

const loadouts = [
  ["armorer_blades", "armorer", "轻装连击", "Light Arsenal", "combo_arsenal", "utility_knife|twin_needles", "bag_canvas_frame", 8],
  ["armorer_guard", "armorer", "守势反击", "Guard Line", "armor_counter", "buckler|iron_nail", "bag_corner_satchel", 8],
  ["alchemist_toxin", "alchemist", "毒素起手", "Toxin Start", "toxin_stack", "venom_needle|healing_herb", "bag_canvas_frame", 8],
  ["alchemist_ember", "alchemist", "火愈循环", "Ember Cycle", "burn_rhythm", "ember_stone|bandage_roll", "bag_corner_satchel", 8],
];
table("character_loadouts.csv", ["id", "character_id", "name_key", "archetype_hint", "starting_items", "starting_bag_id", "starting_gold"], loadouts.map(([id, character_id, zh, en, archetype, items, bag, gold]) => ({
  id, character_id, name_key: addLoc(`loadout.${id}.name`, zh, en), archetype_hint: archetype, starting_items: items, starting_bag_id: bag, starting_gold: gold,
})), "每个角色两套开局配置。");

table("starting_build_items.csv", ["loadout_id", "instance_id", "item_id", "origin_x", "origin_y", "rotation"], loadouts.flatMap(([loadoutId, , , , , items]) =>
  items.split("|").map((itemId, index) => ({
    loadout_id: loadoutId,
    instance_id: `${loadoutId}_item_${index + 1}`,
    item_id: itemId,
    origin_x: index * 2,
    origin_y: 0,
    rotation: 0,
  })),
), "开局普通物品的关系型布局。最终合法性由 Godot PlacementService 校验。");

const bagShapes = [
  ["bag_shape_rect_3x3", "0:0|1:0|2:0|0:1|1:1|2:1|0:2|1:2|2:2"],
  ["bag_shape_corner_9", "0:0|1:0|2:0|0:1|1:1|2:1|0:2|1:2|0:3"],
  ["bag_shape_strip_6", "0:0|1:0|2:0|0:1|1:1|2:1"],
  ["bag_shape_l_7", "0:0|0:1|0:2|0:3|1:3|2:3|1:2"],
  ["bag_shape_t_7", "0:0|1:0|2:0|1:1|1:2|0:2|2:2"],
  ["bag_shape_z_6", "0:0|1:0|1:1|2:1|2:2|3:2"],
  ["bag_shape_cross_9", "0:0|1:0|0:1|1:1|2:1|1:2|2:2|1:3|1:4"],
  ["bag_shape_ring_8", "0:0|1:0|2:0|0:1|2:1|0:2|1:2|2:2"],
  ["bag_shape_step_8", "0:0|1:0|0:1|1:1|2:1|1:2|2:2|3:2"],
  ["bag_shape_wing_8", "0:0|2:0|0:1|1:1|2:1|0:2|1:2|2:2"],
];
table("bag_shapes.csv", ["id", "cells", "cell_count", "allowed_rotations"], bagShapes.map(([id, cells]) => ({ id, cells, cell_count: cells.split("|").length, allowed_rotations: "0|90|180|270" })), "背包提供有效格的形状模板。");

const bags = [
  ["bag_canvas_frame", "帆布方框", "Canvas Frame", "common", 0, 1, "bag_shape_rect_3x3", "none", "", "", "starter"],
  ["bag_corner_satchel", "折角挎包", "Corner Satchel", "common", 0, 1, "bag_shape_corner_9", "none", "", "", "starter"],
  ["bag_tool_roll", "工具卷袋", "Tool Roll", "common", 3, 1, "bag_shape_strip_6", "enhanced_cell", "1:0", "cooldown_pct:-0.05", "shop"],
  ["bag_guard_harness", "守阵挂架", "Guard Harness", "common", 4, 1, "bag_shape_l_7", "star_cell", "0:2", "armor_on_start:3", "shop"],
  ["bag_herbal_tray", "草药托盘", "Herbal Tray", "common", 4, 1, "bag_shape_t_7", "enhanced_cell", "1:1", "status_power:0.08", "shop"],
  ["bag_gear_sling", "齿轮吊带", "Gear Sling Bag", "rare", 6, 2, "bag_shape_z_6", "star_cell", "2:1", "stamina_on_start:2", "shop"],
  ["bag_cross_brace", "十字撑架", "Cross Brace", "rare", 7, 2, "bag_shape_cross_9", "enhanced_cell", "1:2", "damage_flat:1", "shop"],
  ["bag_hollow_ring", "空心环袋", "Hollow Ring", "rare", 7, 2, "bag_shape_ring_8", "star_cell", "0:1|2:1", "cooldown_pct:-0.06", "shop"],
  ["bag_step_case", "阶梯匣", "Step Case", "legendary", 8, 3, "bag_shape_step_8", "enhanced_cell", "1:1|2:2", "crit_chance:0.04", "boss_reward"],
  ["bag_twin_wing", "双翼背架", "Twin Wing Rig", "legendary", 8, 3, "bag_shape_wing_8", "star_cell", "1:1", "status_power:0.12", "boss_reward"],
];
table("bags.csv", ["id", "name_key", "description_key", "rarity", "base_price", "chapter_min", "shape_id", "special_cell_type", "special_cells", "special_effect", "availability", "power_score"], bags.map(([id, zh, en, rarity, price, chapter, shape, cellType, cells, effect, availability]) => ({
  id, name_key: addLoc(`bag.${id}.name`, zh, en),
  description_key: addLoc(`bag.${id}.desc`, `${zh}提供固定有效格，并带有${cellType === "none" ? "无" : cellType}空间效果。`, `${en} provides fixed valid cells and a ${cellType} spatial rule.`),
  rarity, base_price: price, chapter_min: chapter, shape_id: shape, special_cell_type: cellType, special_cells: cells, special_effect: effect, availability,
  power_score: bagShapes.find((s) => s[0] === shape)[1].split("|").length + (cellType === "none" ? 0 : 1.5),
})), "背包层配置。开局背包价格为 0 且不进入商店。");

const recipes = [
  ["recipe_iron_sword", "utility_knife", "sharpening_stone", "iron_sword", 1],
  ["recipe_chain_blade", "iron_sword", "gear_link", "chain_blade", 2],
  ["recipe_heavy_cleaver", "broad_axe", "counterweight", "heavy_cleaver", 1],
  ["recipe_siege_maul", "stone_hammer", "charging_weight", "siege_maul", 1],
  ["recipe_crescent_glaive", "hunting_spear", "focus_prism", "crescent_glaive", 1],
  ["recipe_repeater_crossbow", "twin_needles", "clockwork_spring", "repeater_crossbow", 1],
  ["recipe_spiked_guard", "buckler", "iron_nail", "spiked_guard", 1],
  ["recipe_layered_plates", "plated_vest", "repair_kit", "layered_plates", 1],
  ["recipe_bastion_core", "tower_shield", "guardian_standard", "bastion_core", 1],
  ["recipe_overdrive_ratchet", "stamina_flask", "momentum_gear", "overdrive_ratchet", 2],
  ["recipe_toxin_bottle", "venom_needle", "healing_herb", "toxin_bottle", 1],
  ["recipe_venom_distiller", "toxin_bottle", "thorn_extract", "venom_distiller", 2],
  ["recipe_plague_retort", "spore_jar", "caustic_coil", "plague_retort", 1],
  ["recipe_ember_phial", "ember_stone", "glass_bead", "ember_phial", 1],
  ["recipe_wildfire_alembic", "ember_phial", "coal_burner", "wildfire_alembic", 2],
  ["recipe_tonic_bottle", "healing_herb", "regeneration_leaf", "tonic_bottle", 1],
  ["recipe_philosophers_kettle", "tonic_bottle", "renewal_mortar", "philosophers_kettle", 2],
  ["recipe_transfusion_tube", "bandage_roll", "blood_cup", "transfusion_tube", 1],
  ["recipe_duelist_mark", "fracture_charm", "row_banner", "duelist_mark", 1],
  ["recipe_momentum_gear", "clockwork_spring", "gear_link", "momentum_gear", 1],
  ["recipe_salvage_pouch", "merchant_token", "lucky_coin", "salvage_pouch", 1],
  ["recipe_ignition_lens", "star_compass", "focus_prism", "ignition_lens", 1],
  ["recipe_retaliation_spikes", "repair_kit", "resonant_bell", "retaliation_spikes", 1],
  ["recipe_execution_anvil", "column_standard", "charging_weight", "execution_anvil", 1],
];
table("recipes.csv", ["id", "result_item_id", "tier", "placement_rule", "manual_confirm", "discovery_mode", "chapter_min"], recipes.map(([id, a, b, result, tier]) => ({
  id, result_item_id: result, tier, placement_rule: "adjacent_4", manual_confirm: true, discovery_mode: "place_to_discover", chapter_min: itemSpecs.find((i) => i.id === result).chapter,
})), "双材料、手动确认、最多两级的配方主表。");
table("recipe_ingredients.csv", ["recipe_id", "slot", "item_id", "consume"], recipes.flatMap(([id, a, b]) => [
  { recipe_id: id, slot: 1, item_id: a, consume: true },
  { recipe_id: id, slot: 2, item_id: b, consume: true },
]), "配方材料明细。");

table("game_rules.csv", ["key", "value", "value_type", "scope", "description"], [
  ["content_version", "0.1.0", "string", "global", "v0.1 初始平衡基线"],
  ["grid_width", 9, "int", "backpack", "逻辑画布宽度"],
  ["grid_height", 7, "int", "backpack", "逻辑画布高度"],
  ["shop_slots", 5, "int", "shop", "标准商店槽位"],
  ["shop_lock_limit", 2, "int", "shop", "最多锁定商品"],
  ["shop_discount_pct", 0.25, "float", "shop", "促销折扣"],
  ["bag_pity_shops", 3, "int", "shop", "背包保底计数"],
  ["interest_step_gold", 5, "int", "economy", "每档利息金币"],
  ["interest_cap", 2, "int", "economy", "利息上限"],
  ["used_sell_ratio", 0.5, "float", "economy", "已参战物品出售比例"],
  ["storage_start", 2, "int", "run", "初始仓库格"],
  ["storage_cap", 4, "int", "run", "仓库上限"],
  ["fixed_step_seconds", 0.05, "float", "combat", "战斗固定步长"],
  ["stamina_retry_seconds", 0.2, "float", "combat", "耐力不足重试间隔"],
  ["chain_depth_limit", 8, "int", "combat", "触发链最大深度"],
  ["crit_chance_cap", 0.75, "float", "combat", "暴击率上限"],
  ["damage_reduction_cap", 0.7, "float", "combat", "总减伤上限"],
  ["slow_cap", 0.5, "float", "combat", "减速上限"],
  ["fatigue_start_seconds", 85, "float", "combat", "疲劳开始时间"],
  ["fatigue_tick_seconds", 2, "float", "combat", "疲劳结算间隔"],
  ["fatigue_base_damage", 4, "float", "combat", "首次疲劳真实伤害"],
  ["fatigue_damage_growth", 3, "float", "combat", "每次疲劳增长"],
  ["fatigue_healing_reduction_per_tick", 0.08, "float", "combat", "疲劳治疗衰减"],
  ["undo_history_limit", 20, "int", "backpack", "整理阶段撤销步数"],
].map(([key, value, value_type, scope, description]) => ({ key, value, value_type, scope, description })), "全局规则常量，不应散落在代码中。");

table("combat_rules.csv", ["id", "normal_min_seconds", "normal_max_seconds", "elite_min_seconds", "elite_max_seconds", "boss_min_seconds", "boss_max_seconds", "event_order", "simultaneous_death_result"], [{
  id: "default", normal_min_seconds: 30, normal_max_seconds: 60, elite_min_seconds: 45, elite_max_seconds: 75, boss_min_seconds: 60, boss_max_seconds: 90,
  event_order: "time|priority|side|instance_id", simultaneous_death_result: "player_loss",
}], "战斗时长与稳定排序规则。");

table("shop_rules.csv", ["id", "slots", "discount_slots", "discount_pct", "lock_limit", "bag_pity_count", "pool_public_weight", "pool_character_weight", "pool_archetype_weight", "duplicate_decay"], [{
  id: "standard", slots: 5, discount_slots: 1, discount_pct: 0.25, lock_limit: 2, bag_pity_count: 3,
  pool_public_weight: 0.6, pool_character_weight: 0.25, pool_archetype_weight: 0.15, duplicate_decay: 0.35,
}], "标准商店生成参数。");
table("shop_slot_rules.csv", ["shop_rule_id", "slot_index", "allowed_content", "discount_eligible", "locked_persists"], Array.from({ length: 5 }, (_, index) => ({
  shop_rule_id: "standard", slot_index: index + 1, allowed_content: "item|bag", discount_eligible: true, locked_persists: true,
})), "五个标准商店槽的行为定义。");
table("shop_rarity_curve.csv", ["act_id", "common_weight", "rare_weight", "legendary_weight"], [
  { act_id: "act_1", common_weight: 0.8, rare_weight: 0.2, legendary_weight: 0 },
  { act_id: "act_2", common_weight: 0.55, rare_weight: 0.4, legendary_weight: 0.05 },
  { act_id: "act_3", common_weight: 0.35, rare_weight: 0.5, legendary_weight: 0.15 },
], "章节商店稀有度权重，每行总和必须为 1。");
table("shop_pool_weights.csv", ["id", "source_pool", "weight", "max_effective_weight", "requires_detected_archetype"], [
  { id: "public", source_pool: "public", weight: 0.6, max_effective_weight: 0.7, requires_detected_archetype: false },
  { id: "character", source_pool: "character", weight: 0.25, max_effective_weight: 0.35, requires_detected_archetype: false },
  { id: "archetype", source_pool: "archetype", weight: 0.15, max_effective_weight: 0.25, requires_detected_archetype: true },
], "商店池来源权重。");
table("economy_curve.csv", ["act_id", "normal_gold", "elite_bonus_gold", "boss_gold", "post_battle_heal_pct", "interest_step", "interest_cap", "reward_skip_gold"], [
  { act_id: "act_1", normal_gold: 5, elite_bonus_gold: 2, boss_gold: 0, post_battle_heal_pct: 0.05, interest_step: 5, interest_cap: 2, reward_skip_gold: 2 },
  { act_id: "act_2", normal_gold: 6, elite_bonus_gold: 2, boss_gold: 0, post_battle_heal_pct: 0.04, interest_step: 5, interest_cap: 2, reward_skip_gold: 2 },
  { act_id: "act_3", normal_gold: 7, elite_bonus_gold: 2, boss_gold: 0, post_battle_heal_pct: 0.03, interest_step: 5, interest_cap: 2, reward_skip_gold: 3 },
], "章节经济与战后恢复曲线。");

const acts = [
  ["act_1", "锈林边境", "Rustwood Verge", 1, 4, 1, 1, 38, 58, 12, 16, 0],
  ["act_2", "熔渠工坊", "Cinderworks", 2, 4, 1, 1, 58, 82, 16, 21, 1],
  ["act_3", "星炉深庭", "Starforge Court", 3, 4, 1, 1, 82, 112, 20, 26, 1],
];
table("acts.csv", ["id", "name_key", "order", "regular_node_count", "boss_node_count", "storage_slots_gain", "enemy_budget_min", "enemy_budget_max", "target_cells_min", "target_cells_max", "elite_min_candidates"], acts.map(([id, zh, en, order, regular, boss, storage, min, max, cellsMin, cellsMax, elite]) => ({
  id, name_key: addLoc(`act.${id}.name`, zh, en), order, regular_node_count: regular, boss_node_count: boss,
  storage_slots_gain: order === 1 ? 0 : 1, enemy_budget_min: min, enemy_budget_max: max,
  target_cells_min: cellsMin, target_cells_max: cellsMax, elite_min_candidates: elite,
})), "三章结构与成长目标。");

table("act_progression.csv", ["act_id", "checkpoint", "target_item_min", "target_item_max", "tier1_recipe_min", "tier1_recipe_max", "tier2_recipe_min", "tier2_recipe_max", "expected_gold_min", "expected_gold_max"], [
  { act_id: "act_1", checkpoint: "start", target_item_min: 2, target_item_max: 2, tier1_recipe_min: 0, tier1_recipe_max: 0, tier2_recipe_min: 0, tier2_recipe_max: 0, expected_gold_min: 8, expected_gold_max: 8 },
  { act_id: "act_1", checkpoint: "pre_boss", target_item_min: 5, target_item_max: 8, tier1_recipe_min: 0, tier1_recipe_max: 1, tier2_recipe_min: 0, tier2_recipe_max: 0, expected_gold_min: 2, expected_gold_max: 12 },
  { act_id: "act_2", checkpoint: "pre_boss", target_item_min: 8, target_item_max: 12, tier1_recipe_min: 1, tier1_recipe_max: 3, tier2_recipe_min: 0, tier2_recipe_max: 1, expected_gold_min: 3, expected_gold_max: 15 },
  { act_id: "act_3", checkpoint: "pre_boss", target_item_min: 10, target_item_max: 15, tier1_recipe_min: 2, tier1_recipe_max: 4, tier2_recipe_min: 0, tier2_recipe_max: 2, expected_gold_min: 4, expected_gold_max: 18 },
], "章节检查点的健康区间，不作为硬限制。");

const nodeTemplates = [
  ["normal_combat", "普通战", "Normal Combat", "combat", 1, "reward_normal", "standard"],
  ["danger_combat", "危险战", "Danger Combat", "combat", 1.15, "reward_danger", "standard"],
  ["elite_combat", "精英战", "Elite Combat", "combat", 1.25, "reward_elite", "standard"],
  ["merchant", "商人", "Merchant", "shop", 0, "reward_none", "standard"],
  ["rest", "休息", "Rest", "rest", 0, "reward_none", "none"],
  ["event", "事件", "Event", "event", 0, "reward_none", "none"],
  ["boss", "Boss", "Boss", "boss", 1.5, "reward_boss", "standard"],
];
table("node_templates.csv", ["id", "name_key", "node_type", "enemy_budget_scalar", "reward_table_id", "shop_rule_id"], nodeTemplates.map(([id, zh, en, type, scalar, reward, shop]) => ({
  id, name_key: addLoc(`node.${id}.name`, zh, en), node_type: type, enemy_budget_scalar: scalar, reward_table_id: reward, shop_rule_id: shop,
})), "路线候选节点类型。");

const routeTemplates = [];
for (const [actId, , , order] of acts) {
  routeTemplates.push(
    { id: `${actId}_step_1`, act_id: actId, step: 1, candidate_count_min: 1, candidate_count_max: 1, allowed_nodes: "normal_combat", required_nodes: "normal_combat", forbid_previous_types: "" },
    { id: `${actId}_step_2`, act_id: actId, step: 2, candidate_count_min: 2, candidate_count_max: 2, allowed_nodes: "normal_combat|danger_combat|event|merchant", required_nodes: "", forbid_previous_types: "shop|event|rest" },
    { id: `${actId}_step_3`, act_id: actId, step: 3, candidate_count_min: 2, candidate_count_max: 3, allowed_nodes: order === 1 ? "normal_combat|danger_combat|event|rest" : "normal_combat|danger_combat|elite_combat|event|rest", required_nodes: order === 1 ? "event|rest" : "elite_combat", forbid_previous_types: "shop|event|rest" },
    { id: `${actId}_step_4`, act_id: actId, step: 4, candidate_count_min: 2, candidate_count_max: 3, allowed_nodes: "normal_combat|elite_combat|rest|merchant", required_nodes: "rest|event", forbid_previous_types: "shop|event|rest" },
    { id: `${actId}_boss`, act_id: actId, step: 5, candidate_count_min: 1, candidate_count_max: 1, allowed_nodes: "boss", required_nodes: "boss", forbid_previous_types: "" },
  );
}
table("route_templates.csv", ["id", "act_id", "step", "candidate_count_min", "candidate_count_max", "allowed_nodes", "required_nodes", "forbid_previous_types"], routeTemplates, "进入章节时一次性生成并保存的路线候选约束。");

const enemyArchetypes = [
  ["quick_striker", "急袭者", "Quick Striker", "combo|weapon", "armor", "high_frequency"],
  ["shield_line", "盾阵者", "Shield Line", "armor|counter", "poison|burn", "armor_growth"],
  ["heavy_breaker", "重击者", "Heavy Breaker", "heavy|weapon", "tempo", "burst"],
  ["venom_brewer", "毒酿者", "Venom Brewer", "poison|potion", "cleanse", "poison_stack"],
  ["ember_runner", "逐焰者", "Ember Runner", "burn|tempo", "healing|cleanse", "burn_stack"],
  ["field_mender", "战地医师", "Field Mender", "healing|armor", "heavy|vulnerable", "sustain"],
  ["gear_conductor", "齿轮指挥", "Gear Conductor", "tempo|spatial", "heavy", "cooldown_chain"],
  ["mixed_raider", "混编掠夺者", "Mixed Raider", "weapon|utility", "focused_build", "balanced"],
  ["toxic_guard", "毒甲守卫", "Toxic Guard", "poison|armor", "cleanse|heavy", "attrition"],
  ["burning_bastion", "燃烧壁垒", "Burning Bastion", "burn|armor", "poison|true_damage", "counter_burn"],
  ["blood_engine", "回流机关", "Blood Engine", "healing|combo", "burst", "lifesteal"],
  ["star_artillery", "星位炮阵", "Star Artillery", "spatial|heavy", "tempo", "directional_burst"],
];
table("enemy_archetypes.csv", ["id", "name_key", "threat_tags", "weakness_tags", "behavior_summary"], enemyArchetypes.map(([id, zh, en, threat, weak, summary]) => ({
  id, name_key: addLoc(`enemy_archetype.${id}.name`, zh, en), threat_tags: threat, weakness_tags: weak, behavior_summary: summary,
})), "敌人构筑模板的机制分类。");

const enemyBuilds = [];
function enemy(id, act, kind, archetype, tier, hp, stamina, regen, budget, items, affix = "") {
  enemyBuilds.push({ id, act_id: act, node_type: kind, archetype_id: archetype, tier, max_health: hp, stamina_max: stamina, stamina_regen: regen, budget, items, affix });
}

enemy("rust_scout_a", "act_1", "normal", "quick_striker", 1, 68, 9, 1.5, 39, ["utility_knife", "twin_needles", "stamina_flask"]);
enemy("rust_scout_b", "act_1", "normal", "quick_striker", 2, 74, 10, 1.6, 45, ["utility_knife", "twin_needles", "arsenal_bracer", "stamina_flask"]);
enemy("road_guard_a", "act_1", "normal", "shield_line", 1, 78, 9, 1.5, 42, ["buckler", "leather_wrap", "iron_nail"]);
enemy("road_guard_b", "act_1", "normal", "shield_line", 2, 84, 10, 1.6, 48, ["buckler", "plated_vest", "iron_nail"]);
enemy("trail_breaker", "act_1", "normal", "heavy_breaker", 1, 76, 10, 1.5, 44, ["stone_hammer", "charging_weight"]);
enemy("marsh_brewer", "act_1", "normal", "venom_brewer", 1, 70, 10, 1.6, 41, ["venom_needle", "spore_jar", "healing_herb"]);
enemy("cinder_runner", "act_1", "normal", "ember_runner", 1, 72, 10, 1.7, 43, ["ember_stone", "cooling_fan", "bandage_roll"]);
enemy("camp_mender", "act_1", "normal", "field_mender", 1, 80, 9, 1.5, 46, ["plated_vest", "healing_herb", "regeneration_leaf"]);
enemy("gear_hunter_elite", "act_1", "elite", "gear_conductor", 2, 96, 11, 1.8, 58, ["twin_needles", "gear_link", "clockwork_spring", "stamina_flask"], "accelerated_opening");
enemy("thorn_wall_elite", "act_1", "elite", "toxic_guard", 2, 105, 10, 1.6, 60, ["buckler", "spiked_guard", "venom_needle", "repair_kit"], "armored_start");

enemy("furnace_duelist", "act_2", "normal", "quick_striker", 2, 92, 11, 1.8, 62, ["iron_sword", "arsenal_bracer", "stamina_flask"]);
enemy("plate_warden", "act_2", "normal", "shield_line", 2, 108, 10, 1.7, 68, ["tower_shield", "layered_plates", "repair_kit"]);
enemy("slag_breaker", "act_2", "normal", "heavy_breaker", 2, 98, 11, 1.7, 66, ["heavy_cleaver", "counterweight", "fracture_charm"]);
enemy("coil_brewer", "act_2", "normal", "venom_brewer", 2, 90, 10, 1.8, 64, ["toxin_bottle", "thorn_extract", "spore_jar"]);
enemy("kiln_runner", "act_2", "normal", "ember_runner", 2, 92, 11, 1.9, 65, ["ember_phial", "coal_burner", "cooling_fan"]);
enemy("red_medic", "act_2", "normal", "field_mender", 2, 104, 10, 1.7, 67, ["tonic_bottle", "renewal_mortar", "blood_cup"]);
enemy("relay_captain", "act_2", "normal", "gear_conductor", 2, 96, 11, 1.9, 69, ["repeater_crossbow", "gear_link", "resonant_bell"]);
enemy("foundry_raider", "act_2", "normal", "mixed_raider", 2, 100, 11, 1.8, 70, ["hunting_spear", "buckler", "quicksand_vial", "field_manual"]);
enemy("cinder_bastion_elite", "act_2", "elite", "burning_bastion", 3, 126, 11, 1.8, 82, ["bastion_core", "coal_burner", "retaliation_spikes", "ember_phial"], "reactive_armor");
enemy("blood_loom_elite", "act_2", "elite", "blood_engine", 3, 116, 12, 2.0, 84, ["transfusion_tube", "chain_blade", "blood_cup", "renewal_mortar"], "healing_surge");

enemy("court_blades", "act_3", "normal", "quick_striker", 3, 118, 12, 2.0, 88, ["chain_blade", "repeater_crossbow", "momentum_gear"]);
enemy("astral_guard", "act_3", "normal", "shield_line", 3, 140, 11, 1.8, 92, ["bastion_core", "layered_plates", "retaliation_spikes"]);
enemy("anvil_judge", "act_3", "normal", "heavy_breaker", 3, 126, 12, 1.9, 94, ["siege_maul", "execution_anvil", "fracture_charm"]);
enemy("pale_distiller", "act_3", "normal", "venom_brewer", 3, 118, 11, 2.0, 90, ["venom_distiller", "plague_retort", "caustic_coil"]);
enemy("wildfire_choir", "act_3", "normal", "ember_runner", 3, 120, 12, 2.1, 91, ["wildfire_alembic", "ignition_lens", "cooling_fan"]);
enemy("revival_circle", "act_3", "normal", "field_mender", 3, 136, 11, 1.9, 93, ["philosophers_kettle", "transfusion_tube", "renewal_mortar"]);
enemy("star_gunner", "act_3", "normal", "star_artillery", 3, 122, 12, 2.0, 96, ["crescent_glaive", "focus_prism", "star_compass", "row_banner"]);
enemy("court_raider", "act_3", "normal", "mixed_raider", 3, 130, 12, 2.0, 95, ["iron_sword", "tower_shield", "quicksand_vial", "field_manual"]);
enemy("plague_oracle_elite", "act_3", "elite", "toxic_guard", 4, 150, 12, 2.0, 110, ["plague_retort", "bastion_core", "caustic_coil", "cleansing_salt"], "status_echo");
enemy("starbreaker_elite", "act_3", "elite", "star_artillery", 4, 146, 13, 2.1, 112, ["siege_maul", "execution_anvil", "star_compass", "focus_prism"], "precision_opening");

const enemyNames = {
  rust_scout_a: ["锈林斥候·轻装", "Rustwood Scout A"],
  rust_scout_b: ["锈林斥候·连击", "Rustwood Scout B"],
  road_guard_a: ["道路守卫·圆盾", "Road Guard A"],
  road_guard_b: ["道路守卫·板甲", "Road Guard B"],
  trail_breaker: ["荒径破阵者", "Trail Breaker"],
  marsh_brewer: ["沼地毒酿师", "Marsh Brewer"],
  cinder_runner: ["余烬疾行者", "Cinder Runner"],
  camp_mender: ["营地修补师", "Camp Mender"],
  gear_hunter_elite: ["精英·齿轮猎手", "Elite Gear Hunter"],
  thorn_wall_elite: ["精英·棘墙守卫", "Elite Thorn Wall"],
  furnace_duelist: ["熔炉决斗者", "Furnace Duelist"],
  plate_warden: ["叠甲监工", "Plate Warden"],
  slag_breaker: ["炉渣粉碎者", "Slag Breaker"],
  coil_brewer: ["盘管毒酿师", "Coil Brewer"],
  kiln_runner: ["窑火疾行者", "Kiln Runner"],
  red_medic: ["赤衣医师", "Red Medic"],
  relay_captain: ["传动队长", "Relay Captain"],
  foundry_raider: ["铸坊掠夺者", "Foundry Raider"],
  cinder_bastion_elite: ["精英·烬火壁垒", "Elite Cinder Bastion"],
  blood_loom_elite: ["精英·血织机", "Elite Blood Loom"],
  court_blades: ["深庭刃舞队", "Court Blades"],
  astral_guard: ["星辉守卫", "Astral Guard"],
  anvil_judge: ["铁砧裁决者", "Anvil Judge"],
  pale_distiller: ["苍白蒸馏师", "Pale Distiller"],
  wildfire_choir: ["野火合唱团", "Wildfire Choir"],
  revival_circle: ["回生环阵", "Revival Circle"],
  star_gunner: ["星位炮手", "Star Gunner"],
  court_raider: ["深庭掠袭者", "Court Raider"],
  plague_oracle_elite: ["精英·疫雾先知", "Elite Plague Oracle"],
  starbreaker_elite: ["精英·碎星者", "Elite Starbreaker"],
};

table("enemy_builds.csv", ["id", "name_key", "act_id", "node_type", "archetype_id", "tier", "max_health", "stamina_max", "stamina_regen", "power_budget", "difficulty_min", "difficulty_max", "threat_tags", "weakness_tags", "affix_id", "layout_version"], enemyBuilds.map((b) => {
  const archetype = enemyArchetypes.find((a) => a[0] === b.archetype_id);
  const [zhName, enName] = enemyNames[b.id];
  return {
    id: b.id, name_key: addLoc(`enemy.${b.id}.name`, zhName, enName),
    act_id: b.act_id, node_type: b.node_type, archetype_id: b.archetype_id, tier: b.tier,
    max_health: b.max_health, stamina_max: b.stamina_max, stamina_regen: b.stamina_regen, power_budget: b.budget,
    difficulty_min: "tutorial", difficulty_max: "challenge_5", threat_tags: archetype[3], weakness_tags: archetype[4], affix_id: b.affix, layout_version: 1,
  };
}), "24 套普通敌人与 6 套精英敌人构筑。");

table("enemy_build_bags.csv", ["enemy_build_id", "instance_id", "bag_id", "origin_x", "origin_y", "rotation"], enemyBuilds.flatMap((b) => [
  { enemy_build_id: b.id, instance_id: `${b.id}_bag_1`, bag_id: "bag_canvas_frame", origin_x: 0, origin_y: 0, rotation: 0 },
  { enemy_build_id: b.id, instance_id: `${b.id}_bag_2`, bag_id: b.act_id === "act_1" ? "bag_tool_roll" : b.act_id === "act_2" ? "bag_guard_harness" : "bag_cross_brace", origin_x: 3, origin_y: 1, rotation: 0 },
]), "敌人构筑使用的背包实例布局。");

const placementSlots = [[0, 0, 0], [1, 0, 90], [0, 2, 0], [3, 1, 0], [4, 2, 90]];
table("enemy_build_items.csv", ["enemy_build_id", "instance_id", "item_id", "origin_x", "origin_y", "rotation", "numeric_tier"], enemyBuilds.flatMap((b) => b.items.map((itemId, index) => ({
  enemy_build_id: b.id, instance_id: `${b.id}_item_${index + 1}`, item_id: itemId,
  origin_x: placementSlots[index][0], origin_y: placementSlots[index][1], rotation: placementSlots[index][2], numeric_tier: b.tier,
}))), "敌人普通物品布局。导入编辑器后应再次通过 PlacementService 验证。");

const affixes = [
  ["accelerated_opening", "急速开场", "Accelerated Opening", "combat_start", "modify_cooldown_pct", "value:-0.1|duration:8", 1.08],
  ["armored_start", "披甲", "Armored Start", "combat_start", "gain_armor", "value:15", 1.08],
  ["reactive_armor", "反应装甲", "Reactive Armor", "damage_taken", "gain_armor", "value:2|limit:8", 1.1],
  ["healing_surge", "治疗涌流", "Healing Surge", "first_low_health", "heal", "value:18", 1.1],
  ["status_echo", "状态回响", "Status Echo", "status_applied", "apply_status", "repeat_pct:0.25|limit:8", 1.12],
  ["precision_opening", "精准开场", "Precision Opening", "combat_start", "modify_crit_chance", "value:0.15|duration:10", 1.12],
  ["thick_hide", "厚皮", "Thick Hide", "combat_start", "gain_armor", "value:10", 1.06],
  ["restless", "不息", "Restless", "fatigue_start", "modify_damage_flat", "value:4", 1.07],
];
table("encounter_affixes.csv", ["id", "name_key", "description_key", "trigger_id", "effect_type", "effect_params", "budget_scalar"], affixes.map(([id, zh, en, trigger, effect, params, scalar]) => ({
  id, name_key: addLoc(`affix.${id}.name`, zh, en), description_key: addLoc(`affix.${id}.desc`, `${zh}会公开改变本场敌人的战斗参数。`, `${en} openly modifies this encounter.`), trigger_id: trigger, effect_type: effect, effect_params: params, budget_scalar: scalar,
})), "危险战与精英可用的公开词缀。");

table("encounter_templates.csv", ["id", "act_id", "node_type", "enemy_build_pool", "affix_pool", "reward_table_id", "repeat_limit", "preview_detail"], acts.flatMap(([actId]) => [
  { id: `${actId}_normal`, act_id: actId, node_type: "normal_combat", enemy_build_pool: enemyBuilds.filter((b) => b.act_id === actId && b.node_type === "normal").map((b) => b.id), affix_pool: "", reward_table_id: "reward_normal", repeat_limit: 2, preview_detail: "full_build" },
  { id: `${actId}_danger`, act_id: actId, node_type: "danger_combat", enemy_build_pool: enemyBuilds.filter((b) => b.act_id === actId && b.node_type === "normal").map((b) => b.id), affix_pool: "thick_hide|restless|accelerated_opening", reward_table_id: "reward_danger", repeat_limit: 1, preview_detail: "full_build" },
  { id: `${actId}_elite`, act_id: actId, node_type: "elite_combat", enemy_build_pool: enemyBuilds.filter((b) => b.act_id === actId && b.node_type === "elite").map((b) => b.id), affix_pool: enemyBuilds.filter((b) => b.act_id === actId && b.node_type === "elite").map((b) => b.affix), reward_table_id: "reward_elite", repeat_limit: 1, preview_detail: "full_build" },
]), "章节遭遇池与重复限制。");

const bosses = [
  ["boss_iron_beast", "act_1", "铆甲巨兽", "Rivetback Colossus", 165, 11, 1.8, "armor|counter", "poison|burn", "armor_break_frenzy"],
  ["boss_cinder_engine", "act_2", "熔流机心", "Cinderflow Engine", 230, 12, 2.0, "burn|tempo|armor", "cleanse|heavy", "heat_cycle"],
  ["boss_star_regent", "act_3", "星炉执政", "Starforge Regent", 310, 13, 2.1, "spatial|heavy|healing", "tempo|vulnerable", "star_alignment"],
];
table("bosses.csv", ["id", "name_key", "description_key", "act_id", "max_health", "stamina_max", "stamina_regen", "threat_tags", "weakness_tags", "persistent_rule_id", "reward_table_id"], bosses.map(([id, act, zh, en, hp, stamina, regen, threat, weak, rule]) => ({
  id, name_key: addLoc(`boss.${id}.name`, zh, en), description_key: addLoc(`boss.${id}.desc`, `${zh}拥有公开的阶段规则与可针对弱点。`, `${en} has an openly previewed phase rule and exploitable weakness.`),
  act_id: act, max_health: hp, stamina_max: stamina, stamina_regen: regen, threat_tags: threat, weakness_tags: weak, persistent_rule_id: rule, reward_table_id: "reward_boss",
})), "三个章节 Boss 主属性。");
table("boss_phases.csv", ["boss_id", "phase", "health_threshold_pct", "rule_id", "effect_params", "telegraph_seconds"], [
  { boss_id: "boss_iron_beast", phase: 1, health_threshold_pct: 1, rule_id: "armor_break_frenzy", effect_params: "armor_gain:8|interval:5", telegraph_seconds: 0 },
  { boss_id: "boss_iron_beast", phase: 2, health_threshold_pct: 0.5, rule_id: "armor_break_frenzy", effect_params: "armor_gain:5|damage_flat:3|interval:4", telegraph_seconds: 2 },
  { boss_id: "boss_cinder_engine", phase: 1, health_threshold_pct: 1, rule_id: "heat_cycle", effect_params: "burn:3|interval:5", telegraph_seconds: 0 },
  { boss_id: "boss_cinder_engine", phase: 2, health_threshold_pct: 0.45, rule_id: "heat_cycle", effect_params: "burn:4|cooldown_pct:-0.12|interval:4", telegraph_seconds: 2 },
  { boss_id: "boss_star_regent", phase: 1, health_threshold_pct: 1, rule_id: "star_alignment", effect_params: "front_damage_flat:4|interval:6", telegraph_seconds: 0 },
  { boss_id: "boss_star_regent", phase: 2, health_threshold_pct: 0.4, rule_id: "star_alignment", effect_params: "front_damage_flat:7|heal:6|interval:5", telegraph_seconds: 3 },
], "每个 Boss 最多一次生命阈值阶段变化。");
table("boss_build_items.csv", ["boss_id", "phase", "instance_id", "item_id", "origin_x", "origin_y", "rotation"], [
  ["boss_iron_beast", 1, "b1", "bastion_core", 0, 0, 0], ["boss_iron_beast", 1, "b2", "retaliation_spikes", 2, 0, 90], ["boss_iron_beast", 1, "b3", "stone_hammer", 0, 3, 0],
  ["boss_iron_beast", 2, "b4", "charging_weight", 3, 3, 0],
  ["boss_cinder_engine", 1, "c1", "wildfire_alembic", 0, 0, 0], ["boss_cinder_engine", 1, "c2", "ignition_lens", 3, 0, 90], ["boss_cinder_engine", 1, "c3", "coal_burner", 0, 3, 0],
  ["boss_cinder_engine", 2, "c4", "cooling_fan", 4, 3, 180],
  ["boss_star_regent", 1, "s1", "execution_anvil", 0, 0, 0], ["boss_star_regent", 1, "s2", "crescent_glaive", 4, 0, 90], ["boss_star_regent", 1, "s3", "philosophers_kettle", 0, 4, 0],
  ["boss_star_regent", 2, "s4", "star_compass", 5, 4, 180],
].map(([boss_id, phase, instance_id, item_id, origin_x, origin_y, rotation]) => ({ boss_id, phase, instance_id, item_id, origin_x, origin_y, rotation })), "Boss 固定构筑及第二阶段追加组件。");

const runEffectTemplates = [
  ["gold", "金币变更", "Gold Change", "amount:int"],
  ["heal_flat", "固定治疗", "Flat Healing", "amount:int"],
  ["heal_pct", "比例治疗", "Percent Healing", "amount:float"],
  ["damage_pct", "比例失去生命", "Percent Health Loss", "amount:float|min_health:int"],
  ["item_pool", "物品池奖励", "Item Pool Reward", "rarity:string|owner:string|count:int"],
  ["bag_pool", "背包池奖励", "Bag Pool Reward", "rarity:string|count:int"],
  ["specific_item", "指定物品", "Specific Item", "item_id:string|count:int"],
  ["remove_item", "移除物品", "Remove Item", "selector:string|count:int"],
  ["upgrade_item", "升级物品", "Upgrade Item", "selector:string|numeric_tier_delta:int"],
  ["free_refresh", "免费刷新", "Free Refresh", "amount:int|duration_nodes:int"],
  ["shop_discount", "商店折扣", "Shop Discount", "amount:float|duration_shops:int"],
  ["sell_ratio_bonus", "出售加成", "Sell Ratio Bonus", "amount:float|duration_nodes:int"],
  ["interest_cap_delta", "利息上限变更", "Interest Cap Change", "amount:int|duration_battles:int"],
  ["storage_slot", "仓库扩容", "Storage Slot", "amount:int|fallback_gold:int"],
  ["recipe_discovery", "发现配方", "Recipe Discovery", "tier:int|count:int"],
  ["execute_recipe", "执行配方", "Execute Recipe", "tier_max:int|selector:string"],
  ["cleanse_run_debuff", "清除单局减益", "Cleanse Run Debuff", "count:int"],
];
table("run_effect_templates.csv", ["id", "name_key", "param_format"], runEffectTemplates.map(([id, zh, en, format]) => ({
  id,
  name_key: addLoc(`run_effect.${id}.name`, zh, en),
  param_format: format,
})), "奖励、事件和休息节点使用的单局效果类型。");

const rewardTables = [
  ["reward_none", "无额外奖励", "No Extra Reward", 0, 0, false, 0, "none"],
  ["reward_normal", "普通战奖励", "Normal Combat Reward", 3, 1, true, 2, "weighted_without_replacement"],
  ["reward_danger", "危险战奖励", "Danger Combat Reward", 3, 1, true, 3, "weighted_without_replacement"],
  ["reward_elite", "精英战奖励", "Elite Combat Reward", 3, 1, true, 4, "quality_shift_once"],
  ["reward_boss", "Boss 奖励", "Boss Reward", 3, 1, false, 0, "boss_unique_first"],
];
table("reward_tables.csv", ["id", "name_key", "choice_count", "pick_count", "allow_skip", "skip_gold", "selection_policy"], rewardTables.map(([id, zh, en, choices, picks, skip, skipGold, policy]) => ({
  id,
  name_key: addLoc(`reward.${id}.name`, zh, en),
  choice_count: choices,
  pick_count: picks,
  allow_skip: skip,
  skip_gold: skipGold,
  selection_policy: policy,
})), "节点奖励选择规则。");

const rewardEntries = [
  ["reward_normal", "normal_common_item", "item_pool", "", "rarity:common|owner:current_or_public|count:1", 48, 1, 3],
  ["reward_normal", "normal_rare_item", "item_pool", "", "rarity:rare|owner:current_or_public|count:1", 12, 1, 3],
  ["reward_normal", "normal_gold", "gold", "", "amount:3", 20, 1, 3],
  ["reward_normal", "normal_heal", "heal_pct", "", "amount:0.08", 15, 1, 3],
  ["reward_normal", "normal_refresh", "free_refresh", "", "amount:1|duration_nodes:2", 5, 1, 3],
  ["reward_danger", "danger_common_item", "item_pool", "", "rarity:common|owner:current_or_public|count:1", 30, 1, 3],
  ["reward_danger", "danger_rare_item", "item_pool", "", "rarity:rare|owner:current_or_public|count:1", 32, 1, 3],
  ["reward_danger", "danger_gold", "gold", "", "amount:5", 15, 1, 3],
  ["reward_danger", "danger_heal", "heal_pct", "", "amount:0.12", 13, 1, 3],
  ["reward_danger", "danger_recipe", "recipe_discovery", "", "tier:1|count:1", 10, 1, 3],
  ["reward_elite", "elite_rare_item", "item_pool", "", "rarity:rare|owner:current_or_public|count:1", 45, 1, 3],
  ["reward_elite", "elite_legendary_item", "item_pool", "", "rarity:legendary|owner:current_or_public|count:1", 10, 2, 3],
  ["reward_elite", "elite_bag", "bag_pool", "", "rarity:common_or_rare|count:1", 15, 1, 3],
  ["reward_elite", "elite_gold", "gold", "", "amount:7", 15, 1, 3],
  ["reward_elite", "elite_upgrade", "upgrade_item", "", "selector:player_choice|numeric_tier_delta:1", 15, 2, 3],
  ["reward_boss", "boss_legendary_item", "item_pool", "", "rarity:legendary|owner:current_or_public|count:1", 35, 1, 3],
  ["reward_boss", "boss_unique_bag", "bag_pool", "", "rarity:legendary|count:1", 25, 1, 3],
  ["reward_boss", "boss_recipe", "recipe_discovery", "", "tier:2|count:1", 15, 1, 3],
  ["reward_boss", "boss_upgrade", "upgrade_item", "", "selector:player_choice|numeric_tier_delta:1", 15, 1, 3],
  ["reward_boss", "boss_recovery", "heal_pct", "", "amount:0.25", 10, 1, 2],
];
table("reward_entries.csv", ["reward_table_id", "id", "reward_type", "content_id", "params", "weight", "act_min", "act_max"], rewardEntries.map(([reward, id, type, content, params, weight, actMin, actMax]) => ({
  reward_table_id: reward,
  id,
  reward_type: type,
  content_id: content,
  params,
  weight,
  act_min: actMin,
  act_max: actMax,
})), "奖励池明细。weight 只在同一奖励表和合法章节范围内归一化。");

const events = [
  ["event_abandoned_cart", "遗弃货车", "Abandoned Cart", "一辆倾覆的货车仍有可用货物。", "An overturned cart still holds usable goods.", 1, 3, 10, false, "economy|item"],
  ["event_field_smith", "流动铁匠", "Field Smith", "铁匠愿意用生命补给换取一次紧急加工。", "A field smith offers emergency work in exchange for supplies.", 1, 3, 9, false, "craft|health"],
  ["event_cracked_vault", "裂隙钱箱", "Cracked Strongbox", "钱箱的锁已经损坏，但机关仍在运作。", "The lock is broken, but the trap still works.", 1, 2, 8, true, "risk|gold"],
  ["event_herbal_camp", "草药营地", "Herbal Camp", "临时营地留下了药草与干净水源。", "A temporary camp holds herbs and clean water.", 1, 3, 10, false, "healing|item"],
  ["event_barter_table", "交换桌", "Barter Table", "一张无人看守的交换桌遵循等价交换规则。", "An unattended barter table follows an honor system.", 1, 3, 8, false, "item|economy"],
  ["event_broken_satchel", "破损挎包", "Broken Satchel", "修好挎包可以增加携带能力，也可以直接拆卖。", "The satchel can be repaired for capacity or stripped for value.", 1, 2, 7, true, "bag|storage"],
  ["event_clockwork_stall", "停摆齿轮摊", "Stalled Gear Stand", "停摆机关里还存着一次可释放的动能。", "A stalled mechanism still stores one useful impulse.", 2, 3, 8, false, "tempo|shop"],
  ["event_fume_chamber", "雾剂密室", "Fume Chamber", "密室中的药雾能强化药剂，也会伤害闯入者。", "The chamber fumes empower mixtures while harming intruders.", 2, 3, 7, true, "potion|risk"],
  ["event_quiet_ledger", "无声账本", "Silent Ledger", "账本记录着一套短期获利的方法。", "The ledger records a short-term profit scheme.", 2, 3, 8, true, "economy"],
  ["event_star_map", "残缺星图", "Fractured Star Map", "星图标注着稀有构件和危险捷径。", "The map marks rare components and a dangerous shortcut.", 2, 3, 7, true, "recipe|risk"],
  ["event_echo_forge", "回声锻炉", "Echo Forge", "锻炉能把旧构件压制成更稳定的版本。", "The forge can press an old component into a steadier form.", 3, 3, 6, true, "upgrade|health"],
  ["event_final_merchant", "终途商队", "Final Caravan", "商队只停留片刻，交易条件明确且昂贵。", "The caravan stops briefly with clear and costly terms.", 3, 3, 6, true, "shop|legendary"],
];
table("events.csv", ["id", "title_key", "description_key", "act_min", "act_max", "weight", "once_per_run", "preview_tags"], events.map(([id, zh, en, descZh, descEn, actMin, actMax, weight, once, tags]) => ({
  id,
  title_key: addLoc(`event.${id}.title`, zh, en),
  description_key: addLoc(`event.${id}.desc`, descZh, descEn),
  act_min: actMin,
  act_max: actMax,
  weight,
  once_per_run: once,
  preview_tags: tags,
})), "路线事件主表。所有代价在确认前完整展示。");

const eventChoices = [];
const eventChoiceEffects = [];
function eventChoice(eventId, choiceId, zh, en, requirements, effects) {
  const id = `${eventId}_${choiceId}`;
  eventChoices.push({
    id,
    event_id: eventId,
    text_key: addLoc(`event_choice.${id}.text`, zh, en),
    requirements,
    effect_count: effects.length,
  });
  effects.forEach(([effectType, params], index) => eventChoiceEffects.push({ choice_id: id, sequence: index + 1, effect_type: effectType, params }));
}
eventChoice("event_abandoned_cart", "search", "仔细搜寻", "Search carefully", "none", [["item_pool", "rarity:common|owner:current_or_public|count:1"]]);
eventChoice("event_abandoned_cart", "strip", "拆下零件", "Strip the fittings", "none", [["gold", "amount:5"]]);
eventChoice("event_abandoned_cart", "repair", "花 3 金币修复货箱", "Pay 3 gold to repair the crate", "gold_min:3", [["gold", "amount:-3"], ["bag_pool", "rarity:common|count:1"]]);
eventChoice("event_field_smith", "forge", "支付 4 金币加工一件物品", "Pay 4 gold to improve an item", "gold_min:4|item_count_min:1", [["gold", "amount:-4"], ["upgrade_item", "selector:player_choice|numeric_tier_delta:1"]]);
eventChoice("event_field_smith", "trade_health", "提供补给换取配方", "Trade supplies for a recipe", "health_above_pct:0.25", [["damage_pct", "amount:0.12|min_health:1"], ["recipe_discovery", "tier:1|count:1"]]);
eventChoice("event_field_smith", "leave", "离开", "Leave", "none", []);
eventChoice("event_cracked_vault", "force", "强行打开", "Force it open", "health_above_pct:0.35", [["damage_pct", "amount:0.18|min_health:1"], ["gold", "amount:12"]]);
eventChoice("event_cracked_vault", "tool", "消耗一件工具类物品拆除机关", "Consume a utility item to disarm it", "tag_item_min:utility:1", [["remove_item", "selector:player_choice_tag_utility|count:1"], ["gold", "amount:15"]]);
eventChoice("event_cracked_vault", "leave", "保持谨慎", "Walk away", "none", [["gold", "amount:2"]]);
eventChoice("event_herbal_camp", "rest", "饮水休整", "Rest and drink", "none", [["heal_pct", "amount:0.20"]]);
eventChoice("event_herbal_camp", "gather", "采集草药", "Gather herbs", "none", [["specific_item", "item_id:healing_herb|count:1"]]);
eventChoice("event_herbal_camp", "distill", "支付 2 金币就地调配", "Pay 2 gold to distill", "gold_min:2", [["gold", "amount:-2"], ["item_pool", "rarity:common|owner:alchemist_or_public|tag:potion|count:1"]]);
eventChoice("event_barter_table", "swap", "交出一件普通物品换取稀有候选", "Trade a common item for a rare offer", "rarity_item_min:common:1", [["remove_item", "selector:player_choice_rarity_common|count:1"], ["item_pool", "rarity:rare|owner:current_or_public|count:1"]]);
eventChoice("event_barter_table", "sell", "按较高价格出售一件物品", "Sell one item at a premium", "item_count_min:1", [["sell_ratio_bonus", "amount:0.25|duration_nodes:1"]]);
eventChoice("event_barter_table", "leave", "不做交换", "Make no trade", "none", []);
eventChoice("event_broken_satchel", "repair", "支付 5 金币修复仓库槽", "Pay 5 gold to repair a storage slot", "gold_min:5|storage_below:4", [["gold", "amount:-5"], ["storage_slot", "amount:1|fallback_gold:5"]]);
eventChoice("event_broken_satchel", "salvage", "拆卖金属件", "Salvage the fittings", "none", [["gold", "amount:6"]]);
eventChoice("event_clockwork_stall", "release", "释放机关动能", "Release the stored impulse", "none", [["free_refresh", "amount:2|duration_nodes:2"]]);
eventChoice("event_clockwork_stall", "study", "支付 3 金币研究结构", "Pay 3 gold to study it", "gold_min:3", [["gold", "amount:-3"], ["recipe_discovery", "tier:1|count:1"]]);
eventChoice("event_clockwork_stall", "break", "直接拆卖", "Break it for parts", "none", [["gold", "amount:4"]]);
eventChoice("event_fume_chamber", "inhale", "承受药雾并带走药剂", "Endure the fumes and take a mixture", "health_above_pct:0.30", [["damage_pct", "amount:0.15|min_health:1"], ["item_pool", "rarity:rare|owner:alchemist_or_public|tag:potion|count:1"]]);
eventChoice("event_fume_chamber", "vent", "支付 3 金币启动排风", "Pay 3 gold to vent the room", "gold_min:3", [["gold", "amount:-3"], ["item_pool", "rarity:common|owner:current_or_public|tag:cleanse_or_healing|count:1"]]);
eventChoice("event_fume_chamber", "leave", "封闭入口", "Seal the entrance", "none", [["heal_pct", "amount:0.06"]]);
eventChoice("event_quiet_ledger", "invest", "投入 5 金币提高三场利息上限", "Invest 5 gold to raise the interest cap for three wins", "gold_min:5", [["gold", "amount:-5"], ["interest_cap_delta", "amount:1|duration_battles:3"]]);
eventChoice("event_quiet_ledger", "coupon", "取走折扣券", "Take the discount note", "none", [["shop_discount", "amount:0.15|duration_shops:1"]]);
eventChoice("event_quiet_ledger", "cash", "出售账本", "Sell the ledger", "none", [["gold", "amount:4"]]);
eventChoice("event_star_map", "decode", "支付 4 金币解读星图", "Pay 4 gold to decode the map", "gold_min:4", [["gold", "amount:-4"], ["recipe_discovery", "tier:2|count:1"]]);
eventChoice("event_star_map", "shortcut", "走危险捷径", "Take the dangerous shortcut", "health_above_pct:0.30", [["damage_pct", "amount:0.10|min_health:1"], ["item_pool", "rarity:rare|owner:current_or_public|count:1"]]);
eventChoice("event_star_map", "sell", "卖出星图", "Sell the map", "none", [["gold", "amount:6"]]);
eventChoice("event_echo_forge", "temper", "损失 10% 生命升级一件物品", "Lose 10% health to temper an item", "health_above_pct:0.20|item_count_min:1", [["damage_pct", "amount:0.10|min_health:1"], ["upgrade_item", "selector:player_choice|numeric_tier_delta:1"]]);
eventChoice("event_echo_forge", "melt", "熔解一件物品并获得 10 金币", "Melt an item for 10 gold", "item_count_min:1", [["remove_item", "selector:player_choice|count:1"], ["gold", "amount:10"]]);
eventChoice("event_echo_forge", "warm", "利用余温恢复", "Use the residual warmth", "none", [["heal_pct", "amount:0.15"]]);
eventChoice("event_final_merchant", "legend", "支付 12 金币购买传奇候选", "Pay 12 gold for a legendary offer", "gold_min:12", [["gold", "amount:-12"], ["item_pool", "rarity:legendary|owner:current_or_public|count:1"]]);
eventChoice("event_final_merchant", "bag", "支付 8 金币购买稀有背包", "Pay 8 gold for a rare bag", "gold_min:8", [["gold", "amount:-8"], ["bag_pool", "rarity:rare|count:1"]]);
eventChoice("event_final_merchant", "service", "支付 5 金币获得三次免费刷新", "Pay 5 gold for three free refreshes", "gold_min:5", [["gold", "amount:-5"], ["free_refresh", "amount:3|duration_nodes:2"]]);

table("event_choices.csv", ["id", "event_id", "text_key", "requirements", "effect_count"], eventChoices, "事件选择及显示条件。");
table("event_choice_effects.csv", ["choice_id", "sequence", "effect_type", "params"], eventChoiceEffects, "事件选择的顺序化结果。空效果表示安全离开。");

const restActions = [
  ["rest_recover", "扎营恢复", "Make Camp", "恢复 25% 最大生命。", "Restore 25% of maximum health.", "always", 1],
  ["rest_field_craft", "现场加工", "Field Craft", "从已发现且材料齐全的一级配方中免费完成一次合成。", "Complete one discovered tier-1 recipe when all ingredients are present.", "craftable_tier_1", 1],
  ["rest_maintenance", "装备维护", "Maintain Gear", "选择一件物品提高 1 级本局数值层级，并恢复 8% 生命。", "Raise one item's run tier by 1 and restore 8% health.", "item_count_min:1", 1],
];
table("rest_actions.csv", ["id", "name_key", "description_key", "requirements", "effect_count", "uses_per_node"], restActions.map(([id, zh, en, descZh, descEn, req, uses]) => ({
  id,
  name_key: addLoc(`rest.${id}.name`, zh, en),
  description_key: addLoc(`rest.${id}.desc`, descZh, descEn),
  requirements: req,
  effect_count: id === "rest_maintenance" ? 2 : 1,
  uses_per_node: uses,
})), "休息节点三选一动作。每个节点只能执行一次。");
table("rest_action_effects.csv", ["rest_action_id", "sequence", "effect_type", "params"], [
  { rest_action_id: "rest_recover", sequence: 1, effect_type: "heal_pct", params: "amount:0.25" },
  { rest_action_id: "rest_field_craft", sequence: 1, effect_type: "execute_recipe", params: "tier_max:1|selector:player_choice" },
  { rest_action_id: "rest_maintenance", sequence: 1, effect_type: "upgrade_item", params: "selector:player_choice|numeric_tier_delta:1" },
  { rest_action_id: "rest_maintenance", sequence: 2, effect_type: "heal_pct", params: "amount:0.08" },
], "休息动作的顺序化效果。一次动作可以安全组合多个单局效果。");

const difficultyLevels = [
  ["tutorial", "教学", "Tutorial", 0, "tutorial", 0.72, 0.70, 0.75, 1.15, 0.90, -1, 1.50, 0, true],
  ["standard", "标准", "Standard", 1, "standard", 1.00, 1.00, 1.00, 1.00, 1.00, 0, 1.00, 0, false],
  ["advanced", "进阶", "Advanced", 2, "advanced", 1.08, 1.06, 1.08, 1.00, 1.00, 0, 0.90, 0, false],
  ["challenge_1", "挑战 1", "Challenge 1", 3, "challenge", 1.12, 1.08, 1.10, 1.00, 1.00, 0, 0.85, 1, false],
  ["challenge_2", "挑战 2", "Challenge 2", 4, "challenge", 1.16, 1.11, 1.13, 1.00, 1.00, 1, 0.82, 2, false],
  ["challenge_3", "挑战 3", "Challenge 3", 5, "challenge", 1.20, 1.14, 1.16, 0.95, 1.00, 1, 0.78, 3, false],
  ["challenge_4", "挑战 4", "Challenge 4", 6, "challenge", 1.25, 1.17, 1.20, 0.95, 1.05, 1, 0.74, 4, false],
  ["challenge_5", "挑战 5", "Challenge 5", 7, "challenge", 1.30, 1.20, 1.24, 0.90, 1.05, 1, 0.70, 5, false],
];
table("difficulty_levels.csv", ["id", "name_key", "description_key", "sort_order", "mode", "enemy_health_scalar", "enemy_damage_scalar", "enemy_status_scalar", "gold_reward_scalar", "shop_price_scalar", "refresh_cost_delta", "post_battle_heal_scalar", "challenge_modifier_count", "tutorial_prompts"], difficultyLevels.map(([id, zh, en, order, mode, hp, damage, status, gold, price, refresh, heal, modifierCount, prompts]) => ({
  id,
  name_key: addLoc(`difficulty.${id}.name`, zh, en),
  description_key: addLoc(`difficulty.${id}.desc`, `${zh}难度采用公开的固定修正。`, `${en} uses openly listed fixed modifiers.`),
  sort_order: order,
  mode,
  enemy_health_scalar: hp,
  enemy_damage_scalar: damage,
  enemy_status_scalar: status,
  gold_reward_scalar: gold,
  shop_price_scalar: price,
  refresh_cost_delta: refresh,
  post_battle_heal_scalar: heal,
  challenge_modifier_count: modifierCount,
  tutorial_prompts: prompts,
})), "教学、标准、进阶与挑战 1 至 5 的完整难度曲线。");

const challengeModifiers = [
  ["challenge_rule_1", 1, "敌势增强", "Enemy Momentum", "敌人生命与伤害提高，战后恢复降低。", "Enemies gain health and damage while post-battle healing is reduced.", "difficulty_scalars", "source:difficulty_levels"],
  ["challenge_rule_2", 2, "昂贵搜索", "Costly Search", "商店刷新费用增加 1。", "Shop refreshes cost 1 more gold.", "refresh_cost_delta", "amount:1"],
  ["challenge_rule_3", 3, "紧缩补给", "Tight Supplies", "战斗金币减少 5%，事件收益不变。", "Combat gold is reduced by 5%; event rewards are unchanged.", "gold_reward_scalar", "amount:0.95"],
  ["challenge_rule_4", 4, "精英复合词缀", "Elite Dual Affix", "第二章起精英战额外获得一个不同词缀。", "Elites from Act 2 onward gain one additional distinct affix.", "elite_affix_count", "act_min:2|extra:1"],
  ["challenge_rule_5", 5, "终局压迫", "Final Pressure", "利息上限减少 1，Boss 第二阶段提前 5% 生命触发。", "Interest cap is reduced by 1 and boss phase two starts 5% earlier.", "boss_and_interest", "interest_cap_delta:-1|boss_threshold_offset:0.05"],
];
table("challenge_modifiers.csv", ["id", "challenge_level", "name_key", "description_key", "rule_type", "params", "cumulative"], challengeModifiers.map(([id, level, zh, en, descZh, descEn, type, params]) => ({
  id,
  challenge_level: level,
  name_key: addLoc(`challenge.${id}.name`, zh, en),
  description_key: addLoc(`challenge.${id}.desc`, descZh, descEn),
  rule_type: type,
  params,
  cumulative: true,
})), "挑战难度按等级累积启用的公开规则。");

const unlockRules = [
  ["unlock_armorer", "character", "armorer", "default", "", true],
  ["unlock_alchemist", "character", "alchemist", "default", "", true],
  ["unlock_armorer_blades", "loadout", "armorer_blades", "default", "", true],
  ["unlock_alchemist_toxin", "loadout", "alchemist_toxin", "default", "", true],
  ["unlock_armorer_guard", "loadout", "armorer_guard", "boss_kill", "boss_iron_beast", true],
  ["unlock_alchemist_ember", "loadout", "alchemist_ember", "boss_kill", "boss_cinder_engine", true],
  ["unlock_advanced", "difficulty", "advanced", "run_clear", "difficulty:standard", true],
  ["unlock_challenge_1", "difficulty", "challenge_1", "run_clear", "difficulty:advanced", true],
  ["unlock_challenge_2", "difficulty", "challenge_2", "run_clear", "difficulty:challenge_1", true],
  ["unlock_challenge_3", "difficulty", "challenge_3", "run_clear", "difficulty:challenge_2", true],
  ["unlock_challenge_4", "difficulty", "challenge_4", "run_clear", "difficulty:challenge_3", true],
  ["unlock_challenge_5", "difficulty", "challenge_5", "run_clear", "difficulty:challenge_4", true],
];
table("unlock_rules.csv", ["id", "unlock_type", "target_id", "requirement_type", "requirement_params", "visible_before_unlock"], unlockRules.map(([id, type, target, requirement, params, visible]) => ({
  id,
  unlock_type: type,
  target_id: target,
  requirement_type: requirement,
  requirement_params: params,
  visible_before_unlock: visible,
})), "轻量解锁规则。没有经验等级、货币树或长期数值成长。");

const tutorialSteps = [
  ["tutorial_01_pickup", 1, "shop", "first_shop_open", true, "pick_up_item", "拿起物品", "Pick Up an Item", "从商店或背包中拿起一个物品。", "Pick up an item from the shop or backpack."],
  ["tutorial_02_rotate", 2, "shop", "item_held", true, "rotate_item", "旋转物品", "Rotate the Item", "旋转物品以适应背包形状。", "Rotate the item to fit the backpack shape."],
  ["tutorial_03_place", 3, "shop", "item_rotated", true, "place_item_valid", "完成放置", "Place the Item", "把物品放入全部有效的格子中。", "Place the item entirely inside valid cells."],
  ["tutorial_04_invalid", 4, "shop", "first_invalid_hover", false, "inspect_invalid_reason", "查看非法原因", "Inspect Invalid Placement", "查看越界或重叠提示。", "Inspect the out-of-bounds or overlap warning."],
  ["tutorial_05_buy", 5, "shop", "valid_shop_item_placed", true, "confirm_purchase", "确认购买", "Confirm Purchase", "确认购买并观察金币变化。", "Confirm the purchase and observe the gold change."],
  ["tutorial_06_info", 6, "shop", "purchase_complete", false, "open_item_details", "查看详情", "Inspect Details", "打开物品详情查看触发、范围和标签。", "Open item details to inspect triggers, area, and tags."],
  ["tutorial_07_enemy", 7, "shop", "combat_available", true, "open_enemy_preview", "查看敌人", "Preview the Enemy", "查看敌人构筑、威胁标签和弱点。", "Inspect the enemy build, threat tags, and weaknesses."],
  ["tutorial_08_combat", 8, "combat", "combat_started", false, "wait_for_first_activation", "观察激活", "Watch an Activation", "观察冷却、耐力和一次完整结算。", "Watch cooldown, stamina, and one complete resolution."],
  ["tutorial_09_result", 9, "result", "combat_won", true, "open_combat_stats", "查看统计", "Review Statistics", "查看伤害、治疗和触发次数。", "Review damage, healing, and activation counts."],
  ["tutorial_10_reward", 10, "reward", "reward_open", true, "select_reward", "选择奖励", "Choose a Reward", "选择一个奖励或领取跳过补偿。", "Choose a reward or take the skip compensation."],
  ["tutorial_11_refresh", 11, "shop", "second_shop_open", true, "refresh_shop", "刷新商店", "Refresh the Shop", "支付递增费用刷新五个商品槽。", "Pay the increasing cost to refresh five shop slots."],
  ["tutorial_12_lock", 12, "shop", "after_refresh", false, "lock_shop_item", "锁定商品", "Lock an Offer", "锁定商品使其保留到下一次标准商店。", "Lock an offer so it persists to the next standard shop."],
  ["tutorial_13_storage", 13, "shop", "storage_available", false, "move_item_to_storage", "使用仓库", "Use Storage", "仓库物品不参与战斗或空间关系。", "Stored items do not join combat or spatial checks."],
  ["tutorial_14_recipe", 14, "shop", "recipe_candidate_found", true, "confirm_recipe", "确认合成", "Confirm Crafting", "相邻材料只标记候选，必须手动确认。", "Adjacent ingredients only mark a candidate; confirm it manually."],
  ["tutorial_15_route", 15, "route", "route_open", true, "select_route_node", "选择路线", "Choose a Route", "比较风险标签、节点类型和奖励倾向。", "Compare risk tags, node types, and reward tendencies."],
  ["tutorial_16_complete", 16, "run", "tutorial_boss_won", false, "acknowledge", "教学完成", "Tutorial Complete", "标准难度现已可自由游玩。", "Standard difficulty is now available for unrestricted play."],
];
table("tutorial_steps.csv", ["id", "step_order", "scene_scope", "trigger", "blocking", "required_action", "title_key", "body_key"], tutorialSteps.map(([id, order, scope, trigger, blocking, action, zh, en, bodyZh, bodyEn]) => ({
  id,
  step_order: order,
  scene_scope: scope,
  trigger,
  blocking,
  required_action: action,
  title_key: addLoc(`tutorial.${id}.title`, zh, en),
  body_key: addLoc(`tutorial.${id}.body`, bodyZh, bodyEn),
})), "首局分段教学。非阻塞步骤允许玩家继续操作。");

const achievements = [
  ["first_victory", "FIRST_VICTORY", "初次凯旋", "First Victory", "完成一次标准或更高难度的 Run。", "Clear a run on Standard or higher.", false, "runs_cleared", ">=", 1],
  ["forge_clear", "FORGE_CLEAR", "铸阵通关", "Forge Clear", "使用铸阵师通关。", "Clear a run with the Forge Warden.", false, "armorer_clears", ">=", 1],
  ["alchemy_clear", "ALCHEMY_CLEAR", "调律通关", "Alchemy Clear", "使用调律师通关。", "Clear a run with the Field Alchemist.", false, "alchemist_clears", ">=", 1],
  ["challenge_three", "CHALLENGE_THREE", "压力测试", "Pressure Test", "完成挑战 3。", "Clear Challenge 3.", false, "highest_challenge_clear", ">=", 3],
  ["challenge_five", "CHALLENGE_FIVE", "终局构筑", "Final Build", "完成挑战 5。", "Clear Challenge 5.", false, "highest_challenge_clear", ">=", 5],
  ["master_packer", "MASTER_PACKER", "严丝合缝", "Perfect Packing", "单场战斗前使用至少 24 个有效格。", "Use at least 24 valid cells before one combat.", false, "max_used_cells", ">=", 24],
  ["first_recipe", "FIRST_RECIPE", "首次加工", "First Craft", "完成第一次合成。", "Complete the first recipe.", false, "recipes_crafted", ">=", 1],
  ["recipe_chain", "RECIPE_CHAIN", "二级成品", "Tier Two", "完成一个二级配方。", "Complete a tier-2 recipe.", false, "tier2_recipes_crafted", ">=", 1],
  ["recipe_book", "RECIPE_BOOK", "工艺手册", "Recipe Book", "发现全部 24 个配方。", "Discover all 24 recipes.", false, "recipes_discovered", ">=", 24],
  ["frugal", "FRUGAL", "精打细算", "Careful Saver", "单次 Run 获得 8 枚利息金币。", "Earn 8 interest gold in one run.", false, "run_interest_gold", ">=", 8],
  ["shop_regular", "SHOP_REGULAR", "常客", "Regular Customer", "累计刷新商店 50 次。", "Refresh shops 50 times.", false, "shop_refreshes", ">=", 50],
  ["collector", "COLLECTOR", "行囊收藏", "Pack Collector", "在图鉴中发现 60 件普通物品。", "Discover 60 regular items in the compendium.", false, "items_discovered", ">=", 60],
  ["poison_finish", "POISON_FINISH", "毒尽", "Venom Finish", "让毒素完成一次 Boss 击杀。", "Defeat a boss with poison damage.", false, "boss_kill_poison", ">=", 1],
  ["burn_finish", "BURN_FINISH", "燃尽", "Burn Finish", "让灼烧完成一次 Boss 击杀。", "Defeat a boss with burn damage.", false, "boss_kill_burn", ">=", 1],
  ["armor_peak", "ARMOR_PEAK", "不动阵线", "Unbroken Line", "单场战斗中达到 100 点护甲。", "Reach 100 armor in one combat.", false, "max_armor", ">=", 100],
  ["healing_peak", "HEALING_PEAK", "回生循环", "Renewal Loop", "单场战斗累计恢复 120 点生命。", "Heal 120 health in one combat.", false, "max_combat_healing", ">=", 120],
  ["fast_boss", "FAST_BOSS", "迅速拆解", "Rapid Dismantling", "在 45 秒内击败任意 Boss。", "Defeat any boss within 45 seconds.", false, "fastest_boss_seconds", "<=", 45],
  ["one_health", "ONE_HEALTH", "险胜", "Narrow Victory", "以 1 点生命赢得战斗。", "Win a combat with exactly 1 health.", true, "wins_at_one_health", ">=", 1],
  ["no_refresh", "NO_REFRESH", "就地取材", "Use What You Find", "不刷新商店完成标准难度 Run。", "Clear Standard without refreshing the shop.", true, "standard_clear_no_refresh", ">=", 1],
  ["all_events", "ALL_EVENTS", "旅途见闻", "Road Stories", "见过全部 12 个事件。", "See all 12 events.", false, "events_seen", ">=", 12],
];
table("achievements.csv", ["id", "steam_api_name", "name_key", "description_key", "hidden", "stat_key", "comparison", "target_value"], achievements.map(([id, api, zh, en, descZh, descEn, hidden, stat, comparison, target]) => ({
  id,
  steam_api_name: api,
  name_key: addLoc(`achievement.${id}.name`, zh, en),
  description_key: addLoc(`achievement.${id}.desc`, descZh, descEn),
  hidden,
  stat_key: stat,
  comparison,
  target_value: target,
})), "Steam 成就与本地统计映射。Steam API 名称发布后不得修改。");

const telemetryMetrics = [
  ["run_started", "run", "counter", "count", true, "local", "角色、难度与开局配置选择"],
  ["run_ended", "run", "event", "last", true, "local", "胜负、章节、节点数和时长"],
  ["combat_result", "combat", "event", "last", true, "local", "敌人、时长、剩余生命与主要伤害来源"],
  ["item_purchased", "shop", "event", "count", true, "local", "物品、价格、章节与槽位"],
  ["item_sold", "shop", "event", "count", true, "local", "物品、售价与是否参战"],
  ["shop_refreshed", "shop", "counter", "sum", true, "local", "刷新次数和实际费用"],
  ["shop_locked", "shop", "counter", "sum", true, "local", "锁定数量和最终购买结果"],
  ["shop_offer_generated", "shop", "event", "count", false, "development", "池来源、稀有度、促销和保底"],
  ["interest_awarded", "economy", "number", "sum", true, "local", "单局利息金币"],
  ["reward_selected", "reward", "event", "count", true, "local", "奖励表、候选与选择"],
  ["reward_skipped", "reward", "counter", "sum", true, "local", "跳过次数和补偿金币"],
  ["recipe_discovered", "craft", "event", "count", true, "local", "配方与发现章节"],
  ["recipe_crafted", "craft", "event", "count", true, "local", "配方、层级与节点"],
  ["placement_failed", "backpack", "event", "count", false, "development", "越界、无效格或重叠原因"],
  ["used_cell_count", "backpack", "number", "max", true, "local", "出战时已使用有效格"],
  ["storage_usage", "backpack", "number", "average", true, "local", "节点离开时仓库占用"],
  ["chain_limit_reached", "combat", "counter", "sum", false, "development", "触发链保护触发次数"],
  ["effect_activation", "combat", "event", "count", false, "development", "物品效果激活与贡献"],
  ["event_choice", "event", "event", "count", true, "local", "事件选择和资源变化"],
  ["route_choice", "route", "event", "count", true, "local", "候选节点和实际选择"],
  ["boss_phase_time", "combat", "number", "average", false, "development", "Boss 阶段切换时间"],
  ["difficulty_clear", "run", "event", "count", true, "local", "角色和难度通关"],
  ["tutorial_step", "tutorial", "event", "last", true, "local", "教学完成位置"],
  ["config_validation_error", "system", "event", "count", false, "development", "开发构建配置错误"],
];
table("telemetry_metrics.csv", ["id", "scope", "value_type", "aggregation", "enabled_in_release", "privacy_class", "description"], telemetryMetrics.map(([id, scope, type, aggregation, enabled, privacy, description]) => ({
  id,
  scope,
  value_type: type,
  aggregation,
  enabled_in_release: enabled,
  privacy_class: privacy,
  description,
})), "统计与平衡观测指标。release 默认仅保存在本地存档，不自动上传。");

const statDefinitions = [
  ["runs_cleared", "run_ended", "count_if:result=clear", "profile", "integer", "never", 0, "累计通关次数。"],
  ["armorer_clears", "difficulty_clear", "count_if:character_id=armorer", "profile", "integer", "never", 0, "铸阵师累计通关次数。"],
  ["alchemist_clears", "difficulty_clear", "count_if:character_id=alchemist", "profile", "integer", "never", 0, "调律师累计通关次数。"],
  ["highest_challenge_clear", "difficulty_clear", "max:challenge_level", "profile", "integer", "never", 0, "已通关的最高挑战等级。"],
  ["max_used_cells", "used_cell_count", "max:value", "profile", "integer", "never", 0, "任意战斗前的最大有效格占用。"],
  ["recipes_crafted", "recipe_crafted", "count", "profile", "integer", "never", 0, "累计完成配方次数。"],
  ["tier2_recipes_crafted", "recipe_crafted", "count_if:tier=2", "profile", "integer", "never", 0, "累计完成二级配方次数。"],
  ["recipes_discovered", "recipe_discovered", "distinct_count:recipe_id", "profile", "integer", "never", 0, "已发现的不同配方数量。"],
  ["run_interest_gold", "interest_awarded", "sum:value", "run", "integer", "run_start", 0, "当前单局累计获得的利息金币。"],
  ["shop_refreshes", "shop_refreshed", "sum:value", "profile", "integer", "never", 0, "累计商店刷新次数。"],
  ["items_discovered", "item_purchased|reward_selected|recipe_crafted", "distinct_count:item_id_or_result_item_id", "profile", "integer", "never", 0, "图鉴中已发现的不同普通物品数量。"],
  ["boss_kill_poison", "combat_result", "count_if:enemy_type=boss&final_damage=poison", "profile", "integer", "never", 0, "由毒素完成最后一击的 Boss 数量。"],
  ["boss_kill_burn", "combat_result", "count_if:enemy_type=boss&final_damage=burn", "profile", "integer", "never", 0, "由灼烧完成最后一击的 Boss 数量。"],
  ["max_armor", "combat_result", "max:peak_armor", "profile", "integer", "never", 0, "单场战斗达到的最高护甲。"],
  ["max_combat_healing", "combat_result", "max:total_healing", "profile", "integer", "never", 0, "单场战斗累计治疗量的最高值。"],
  ["fastest_boss_seconds", "combat_result", "min_if:enemy_type=boss:duration_seconds", "profile", "float", "never", 999999, "Boss 战最短胜利时间；无记录时使用大哨兵值。"],
  ["wins_at_one_health", "combat_result", "count_if:result=win&remaining_health=1", "profile", "integer", "never", 0, "以 1 点生命取胜的战斗次数。"],
  ["standard_clear_no_refresh", "run_ended|shop_refreshed", "count_if:difficulty=standard&result=clear&run_refreshes=0", "profile", "integer", "never", 0, "标准难度零刷新通关次数。"],
  ["events_seen", "event_choice", "distinct_count:event_id", "profile", "integer", "never", 0, "已见过的不同事件数量。"],
];
table("stat_definitions.csv", ["id", "source_metric", "aggregation", "scope", "value_type", "reset_policy", "default_value", "description"], statDefinitions.map(([id, source, aggregation, scope, type, reset, defaultValue, description]) => ({
  id,
  source_metric: source,
  aggregation,
  scope,
  value_type: type,
  reset_policy: reset,
  default_value: defaultValue,
  description,
})), "由本地采集指标聚合得到的档案与单局统计定义，供成就和界面查询。");

normalizeFacts(tables, loc);

table("localization_zh_cn.csv", ["key", "text"], [...loc.values()].map((entry) => ({ key: entry.key, text: entry.zh_cn })), "简体中文文本。");
table("localization_en.csv", ["key", "text"], [...loc.values()].map((entry) => ({ key: entry.key, text: entry.en })), "英文文本。");

const compoundKeys={act_progression:'act_id|checkpoint',boss_build_items:'boss_id|phase|instance_id',boss_phases:'boss_id|phase',enemy_build_bags:'enemy_build_id|instance_id',enemy_build_items:'enemy_build_id|instance_id',event_choice_effects:'choice_id|sequence',recipe_ingredients:'recipe_id|slot',rest_action_effects:'rest_action_id|sequence',reward_entries:'reward_table_id|id',shop_slot_rules:'shop_rule_id|slot_index',starting_build_items:'loadout_id|instance_id'};
const manifestRows = Object.entries(tables).map(([file, spec], index) => ({
  file,
  schema_version: "0.1.3",
  load_order: index + 1,
  row_count: spec.rows.length,
  primary_key_hint: compoundKeys[file.replace('.csv','')] ?? spec.columns[0],
  description: spec.description,
}));
table("config_manifest.csv", ["file", "schema_version", "load_order", "row_count", "primary_key_hint", "description"], manifestRows, "配置文件清单与加载顺序。");

for (const [name, spec] of Object.entries(tables)) writeCsv(name, spec.columns, spec.rows);

const schemaSections = Object.entries(tables).map(([name, spec]) => {
  const columns = spec.columns.map((column) => `\`${column}\``).join("、");
  return `### ${name}\n\n${spec.description}\n\n- 字段：${columns}\n- 初始行数：${spec.rows.length}\n`;
}).join("\n");

writeText("README.md", `
# 游戏数值配置表

本目录是 **0.1.1 规划与布局审计基线**，用于 Godot 4.7 的单机 PvE 实现、联调和试玩。原始0.1.0输入保存在开发工作区；本目录为已修正的副本。战斗强度、经济效率和掉落概率仍需通过自动模拟与人工试玩迭代。

## 内容范围

- 2 名角色、6 种流派、4 套开局配置。
- 72 件普通物品、10 个背包、24 个配方。
- 3 章路线、30 套敌人构筑、8 个遭遇词缀、3 个 Boss 与 6 个 Boss 阶段。
- 五槽商店、递增刷新、锁定、促销、背包保底、利息和章节经济。
- 5 个奖励表、20 条奖励项、12 个事件、35 个事件选择、2 个休息动作。
- 16 个玩法标签和5个只用于预览的情报词汇，541组中英文本键。
- 教学、标准、进阶、挑战 1 至 5，共 8 档难度。
- 16 步教学、20 个成就、24 个本地采集指标、19 个派生档案统计和中英文本。

## 文件约定

- 编码：UTF-8，无 BOM；换行：LF；格式：RFC 4180 CSV。
- ID：稳定 snake_case。保存数据只记录 ID，不保存数组下标。
- 布尔值：\`true\` 或 \`false\`；比例：\`0.0\` 至 \`1.0\`；时间：秒。
- 列表：使用 \`|\` 分隔；二维格坐标：\`x:y\`；参数：\`key:value|key:value\`。
- 空值：空字符串。读取器必须区分空字符串、0 与 false。
- \`config_manifest.csv\` 不列出自身；\`row_count\` 统计每张业务配置表的数据行数，不包含表头。
- 源配置保持明文，目录内的 .gdignore 阻止Godot误当翻译表导入CSV。运行时只读 content/compiled/content.json，不使用 .csv.import 或 .translation。
- items.crafted_only 表示配方成品在普通随机商店禁售；专用奖励与事件仍可授予。shop_enabled 是普通商店的独立入池开关。
- Boss的两种传奇赠礼显式 ignore_chapter_gate:true，精英传奇只在第三章出现，其他物品奖励遵守章节门槛。

## Godot 4.7 导入建议

1. 项目根目录 tools/import_content.py 按CSV、复合主键和字段类型编译确定性的JSON缓存，并生成文件SHA-256清单。
2. 数值与布尔字段保留类型；管道列表和参数保持String，由ContentDB.list_values/parse_params解析并复制。get_definition提供可序列化的只读Resource视图。
3. 每次导入运行完整validate_content.py，覆盖schema、主键、外键、双语、冻结范围、真实占格、候选约束与奖励池非空；旧tools/validate_configs.mjs保留作基础检查。
4. \`ContentDB\` 只暴露按稳定 ID 的只读查询；运行时实例不得回写定义。
5. 敌人、Boss 和开局坐标必须再经过 Godot \`PlacementService\` 的真实旋转与占格校验。
6. 发布构建记录 \`content_version\`、每个文件的 SHA-256 和最终 PCK 哈希，以便存档迁移和问题定位。

## 使用命令

\`\`\`bash
node project/content/tables/tools/build_configs.mjs
python tools/import_content.py
python tools/validate_content.py
\`\`\`

生成器是配置事实源。需要批量调整时修改生成器并重新生成，不要同时手工修改生成 CSV。
`);

writeText("SCHEMA_DICTIONARY.md", `
# 配置表数据字典

版本：0.1.1 规划与真实布局修正基线。字段类型由Python导入器记录，Godot读JSON后恢复整数列；CSV本身只承载文本表示。

## 通用字段规则

- \`id\`：稳定主键或复合主键的一部分。
- \`*_id\`：外键；空字符串表示该关系不适用。
- \`*_key\`：本地化键，必须同时存在于简体中文与英文表。
- \`*_pct\` / \`*_chance\` / \`*_scalar\`：浮点比例或倍率。
- \`*_seconds\` / \`cooldown\`：秒。
- \`weight\`：正数相对权重，由所属池内合法条目归一化。
- \`params\`：小型结构化参数串。导入后必须转换为 Dictionary，不应在战斗热路径重复解析。
- \`items.crafted_only\`：配方成品标记，普通商店禁售，不禁止显式奖励/事件赠送；\`shop_enabled\`为普通商店入池开关。
- \`bosses.bag_layout\`：\`bag_id:x:y:rotation|...\`，敌人和Boss遵守同一背包几何规则，第二阶段与第一阶段物品累计校验。
- \`tags.category=intel\`：情报预览词汇，不作为物品的新玩法标签，不引入数值倍率。
- \`upgrade_item\`：只复用已定义的一阶到二阶配方转换；无可选对象时下次商店20%券。不存在numeric_tier或独立强化等级。
- \`ignore_chapter_gate:true\`：仅Boss独立赠礼显式绕过章节门槛，其他奖励不得使用。

${schemaSections}
`);

writeText("VALIDATION_RULES.md", `
# 配置校验规则

## 阻断发布的错误

1. CSV 无法解析、列数不一致、主键重复或稳定 ID 格式错误。
2. 角色、物品、背包、配方、遭遇、奖励、事件和本地化外键缺失。
3. 物品或背包形状不含原点、包含重复格、形状不连通、旋转值非法，或背包特殊格位于有效形状之外。
4. 商店章节稀有度权重不等于 1，或任何池权重小于等于 0。
5. 配方输出也是自身材料、配方有环、制作深度超过 2 或材料数量不是 2。
6. Boss 阶段不连续、生命阈值未递减、路线末步不是 Boss。
7. 高频触发器缺少至少 0.5 秒内部冷却，或单物品效果超过 2 个触发器。
8. 难度、事件、敌人、Boss、物品、背包和配方首发数量不满足冻结范围。

## 需要编辑器复核的内容

- 敌人、Boss 与开局布局的真实占格、旋转、背包有效格覆盖和特殊格命中。
- 多背包重叠规则、移除背包后的悬空物品处理和手柄操作焦点。
- 资源路径、图标尺寸、VFX 标识和本地化文本在实际 UI 中的截断情况。

## 首轮试玩重点

- 冷却推进链是否接近触发深度上限。
- 护甲获得与反击触发是否形成过高频率循环。
- 毒与灼烧在 30 至 90 秒战斗中的衰减效率。
- 治疗转化是否消除持续生命制的路线压力。
- 利息、递增刷新和促销是否形成唯一经济策略。
- Boss 第二阶段阈值、疲劳开始时间和治疗衰减是否合理。
`);

writeText("RELATIONSHIP_GRAPH.md", `
# 配置关系图

\`\`\`mermaid
graph TD
  Character --> CharacterPassive
  Character --> Archetype
  Character --> Loadout
  Loadout --> StartingBuildItem
  Loadout --> Bag
  StartingBuildItem --> Item
  Item --> ItemShape
  Item --> ItemEffect
  ItemEffect --> TriggerTemplate
  ItemEffect --> ConditionTemplate
  ItemEffect --> EffectTemplate
  ItemEffect --> SpatialTemplate
  Recipe --> RecipeIngredient
  RecipeIngredient --> Item
  Recipe --> Item
  Act --> RouteTemplate
  RouteTemplate --> NodeTemplate
  NodeTemplate --> RewardTable
  EncounterTemplate --> EnemyBuild
  EnemyBuild --> EnemyArchetype
  EnemyBuild --> EnemyBuildBag
  EnemyBuild --> EnemyBuildItem
  EnemyBuildBag --> Bag
  EnemyBuildItem --> Item
  Boss --> BossPhase
  Boss --> BossBuildItem
  BossBuildItem --> Item
  RewardTable --> RewardEntry
  Event --> EventChoice
  EventChoice --> EventChoiceEffect
  EventChoiceEffect --> RunEffectTemplate
  RestAction --> RestActionEffect
  RestActionEffect --> RunEffectTemplate
  Achievement --> StatDefinition
  StatDefinition --> TelemetryMetric
  Difficulty --> ChallengeModifier
  DisplayKey --> LocalizationZH
  DisplayKey --> LocalizationEN
\`\`\`

所有带 \`name_key\`、\`title_key\`、\`description_key\` 或 \`body_key\` 的记录都依赖两张本地化表。运行时业务数据只保存稳定 ID。
`);

writeText("CHANGELOG.md", `
# 配置变更记录

## 0.1.1 - 2026-10-14

- 重排4套开局、30敌人和3Boss累计阶段物品，所有物品须完全位于合法背包且不重叠；Boss新增显式背包规则。
- 修候选数量、强制候选与前序禁用冲突；记录固定15混合节点的实际9至15战斗范围。
- 移除独立物品数值强化，休息严格二选一，两角色各两套开局默认开放。
- 修Boss早期传奇和第2章精英传奇空池；修16条英文描述及补5个情报词双语。
- 使用真实SVG语义图标、VFX定义、类型化缓存、复合主键提示及完整发布审计。
- 修齿轮吊带满耐力开局回复无效果：改为现有星位关联物品5%冷却缩短，双语描述同步。

## 0.1.0 - 2026-10-12

- 建立 v0.1 初始平衡基线。
- 完成角色、流派、物品、背包、配方、商店、经济、战斗、状态与空间模板。
- 完成三章路线、30 套敌人、8 个词缀、3 个 Boss 和阶段配置。
- 完成奖励、事件、休息、难度、解锁、教学、成就、采集指标、派生统计和双语文本。
- 增加生成器、清单、数据字典、关系图与自动校验规则。
`);

console.log(`Generated ${Object.keys(tables).length} CSV files in ${ROOT}`);
console.log(`Items=${itemSpecs.length}, Bags=${bags.length}, Recipes=${recipes.length}, Enemies=${enemyBuilds.length}, Bosses=${bosses.length}, Events=${events.length}`);


