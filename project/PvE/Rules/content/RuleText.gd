class_name RuleText
extends RefCounted

var db

func _init(content = null): db = content

func _b(zh: String, en: String, language: String) -> String:
	return zh if language.to_lower().begins_with("zh") else en

func _n(value) -> String:
	var text = str(snappedf(float(value), 0.001))
	if "." in text:
		while text.ends_with("0"): text = text.left(-1)
		if text.ends_with("."): text = text.left(-1)
	return "0" if text == "-0" else text

func _params(raw) -> Dictionary:
	# Combat shorthand such as "weapon" and "6" means a value, not a flag.
	return SnapshotBuilder.parse_params(raw)

func _pct(value) -> String: return _n(float(value) * 100.0) + "%"
func _signed(value, percentage: bool = false) -> String:
	return ("+" if float(value) >= 0.0 else "") + (_pct(value) if percentage else _n(value))

func term(table: String, id: String, language: String = "zh_CN") -> String:
	var row = db.get_row(table, id)
	if row.has("name_key"):
		var value = db.text(str(row.name_key), language)
		if value != str(row.name_key): return value
	if table == "spatial_templates":
		var names = {"none": ["无", "None"], "adjacent_4": ["四向相邻", "Orthogonal adjacency"], "adjacent_8": ["八向相邻", "Eight-way adjacency"], "front_1": ["前方1格", "1 cell forward"], "front_2": ["前方2格", "2 cells forward"], "front_3": ["前方3格", "3 cells forward"], "same_row": ["同行", "Same row"], "same_column": ["同列", "Same column"], "star_cell": ["星位", "Star"], "same_bag": ["同包", "Same bag"], "global_same_tag": ["同标签全局", "All matching tags"]}
		if names.has(id): return _b(names[id][0], names[id][1], language)
	if table == "rarities":
		var names = {"common": ["普通", "Common"], "rare": ["稀有", "Rare"], "legendary": ["传奇", "Legendary"]}
		if names.has(id): return _b(names[id][0], names[id][1], language)
	return _b("未知词条", "Unknown term", language)

func trigger(id: String, language: String = "zh_CN", context: Dictionary = {}) -> String:
	match id:
		"combat_start": return _b("战斗开始时", "At combat start", language)
		"cooldown_ready":
			var cooldown = float(context.get("cooldown", 0))
			return _b("每%s秒冷却就绪时", "When its %s-second cooldown is ready", language) % _n(cooldown) if cooldown > 0 else _b("自身冷却就绪时", "When its cooldown is ready", language)
		"attack_hit": return _b("本方物理攻击命中后", "After an allied physical attack hits", language)
		"critical_hit": return _b("本方物理攻击暴击后", "After an allied physical critical hit", language)
		"target_activated": return _b("关联物品激活后", "After a linked item activates", language)
		"damage_taken": return _b("本方受到生命伤害后", "After taking health damage", language)
		"armor_gained": return _b("本方获得护甲后", "After gaining armor", language)
		"status_applied": return _b("本方成功施加状态后", "After successfully applying a status", language)
		"first_low_health": return _b("本场生命首次降至%s及以下时", "The first time health falls to %s or less", language) % _pct(db.value("first_low_health_threshold", 0.35))
		"interval": return _b("每%s秒", "Every %s seconds", language) % _n(context.get("interval", 1))
		"fatigue_start": return _b("进入疲劳阶段时", "When fatigue starts", language)
	return _b("未知触发器", "Unknown trigger", language)

func spatial(id: String, language: String = "zh_CN") -> String:
	match id:
		"none": return _b("无空间要求", "No spatial requirement", language)
		"adjacent_4": return _b("四向相邻：任一占格上下左右接触", "Orthogonally adjacent: any occupied cells touch on an edge", language)
		"adjacent_8": return _b("八向相邻：包含斜角接触", "Adjacent in eight directions, including diagonals", language)
		"front_1", "front_2", "front_3": return _b("朝向前方%s格；旋转会改变方向", "%s cells forward; rotation changes the direction", language) % id.trim_prefix("front_")
		"same_row": return _b("同行：归一化中心位于同一行", "Same row, using the floored center cell", language)
		"same_column": return _b("同列：归一化中心位于同一列", "Same column, using the floored center cell", language)
		"star_cell": return _b("所在背包的星位及其四向相邻物品", "Items on or orthogonally adjacent to stars in the source item's bags", language)
		"same_bag": return _b("同包：至少共享一个覆盖背包", "Same bag: share at least one bag covering their cells", language)
		"global_tag", "global_same_tag": return _b("构筑内符合标签的全部物品；不含仓库", "All matching items in the active build; storage is excluded", language)
	return _b("未知作用范围", "Unknown spatial template", language)

func _count(params: Dictionary, language: String) -> String:
	var parts: Array = []
	if params.has("min"): parts.append(_b("至少%s", "at least %s", language) % _n(params.min))
	if params.has("max"): parts.append(_b("至多%s", "at most %s", language) % _n(params.max))
	if params.has("equals"): parts.append(_b("恰好%s", "exactly %s", language) % _n(params.equals))
	if parts.is_empty(): parts.append(_b("至少%s", "at least %s", language) % _n(params.get("value", 1)))
	return _b("且", " and ", language).join(parts)

func condition(id: String, raw, language: String = "zh_CN") -> String:
	var p = _params(raw); var value = p.get("value", 0)
	match id:
		"always", "": return _b("无额外条件", "No additional condition", language)
		"source_has_tag": return _b("自身具有“%s”标签", "The source has the %s tag", language) % term("tags", str(p.get("tag", value)), language)
		"target_has_tag": return _b("作用目标具有“%s”标签", "The target has the %s tag", language) % term("tags", str(p.get("tag", value)), language)
		"spatial_target_count": return _b("关联目标数量%s", "The linked target count is %s", language) % _count(p, language)
		"health_below_pct": return _b("生命严格低于%s", "Health is strictly below %s", language) % _pct(p.get("threshold", value))
		"health_above_pct": return _b("生命严格高于%s", "Health is strictly above %s", language) % _pct(p.get("threshold", value))
		"resource_at_least":
			var resource = _b("护甲", "armor", language) if str(p.get("resource", "armor")) == "armor" else _b("耐力", "stamina", language)
			return _b("%s至少%s", "%s is at least %s", language) % [resource, _n(p.get("amount", value))]
		"status_stacks_at_least": return _b("%s至少%s层", "%s has at least %s stacks", language) % [term("statuses", str(p.get("status_id", p.get("status", "poison"))), language), _n(p.get("stacks", value))]
		"trigger_count_max":
			if p.has("new_negative_status_only"): return _b("每种新负面状态本场仅首次触发", "Only the first application of each new negative status this combat", language)
			return _b("本场最多触发%s次", "At most %s triggers per combat", language) % _n(p.get("max", value))
		"build_tag_count":
			if p.has("distinct_weapon_shapes"): return _b("武器形状本场尚未计入；相同形状只计一次", "This weapon shape has not been counted this combat; each shape counts once", language)
			if str(p.get("tag", "")).is_empty(): return _b("构筑内物品数量%s（不计仓库）", "The active build contains %s items (storage excluded)", language) % _count(p, language)
			return _b("构筑内“%s”物品数量%s（不计仓库）", "The active build contains %s items %s (storage excluded)", language) % [term("tags", str(p.get("tag", "")), language), _count(p, language)]
		"enemy_has_status": return _b("敌方具有%s", "The enemy has %s", language) % term("statuses", str(p.get("status_id", value)), language)
		"overheal_positive": return _b("本次触发链存在溢出治疗", "This trigger chain has overhealing", language)
	return _b("未知条件", "Unknown condition", language)

func effect(row: Dictionary, language: String = "zh_CN", context: Dictionary = {}) -> String:
	var p = _params(row.get("effect_params", "")); var value = p.get("value", p.get("amount", 0)); var kind = str(row.get("effect_type", ""))
	var text = ""
	match kind:
		"physical_damage": text = _b("造成%s点物理伤害；先扣护甲再扣生命", "Deal %s physical damage; armor absorbs it before health", language) % _n(value)
		"true_damage": text = _b("造成%s点真实伤害；无视护甲", "Deal %s true damage, ignoring armor", language) % _n(value)
		"gain_armor": text = _b("获得%s点护甲", "Gain %s armor", language) % _n(value)
		"heal": text = _b("恢复%s点生命；默认不保留溢出治疗", "Restore %s health; overhealing is discarded by default", language) % _n(value)
		"gain_stamina": text = _b("恢复%s点耐力", "Restore %s stamina", language) % _n(value) if float(value) >= 0 else _b("消耗%s点耐力", "Consume %s stamina", language) % _n(-float(value))
		"apply_status":
			if p.has("repeat_pct"):
				text = _b("向原目标额外施加本次状态层数的%s（向下取整，至少1层）", "Reapply %s of the status stacks to their original target (round down, minimum 1)", language) % _pct(p.repeat_pct)
			else:
				var parts = str(value).split(":"); var id = str(p.get("status_id", parts[0] if parts.size() > 1 else "")); var stacks = p.get("stacks", parts[1] if parts.size() > 1 else 1)
				text = _b("施加%s层%s", "Apply %s stacks of %s", language) % [_n(stacks), term("statuses", id, language)]
		"remove_status": text = _b("移除%s层%s", "Remove %s stacks of %s", language) % [_n(p.get("stacks", value)), _b("负面状态", "negative statuses", language) if str(p.get("status_id", "negative")) == "negative" else term("statuses", str(p.status_id), language)]
		"convert_status": text = _b("将%s转化为%s，转化比例%s，向下取整", "Convert %s into %s at %s, rounding down", language) % [term("statuses", str(p.get("from", "poison")), language), term("statuses", str(p.get("to", "regeneration")), language), _pct(p.get("ratio", 1))]
		"modify_cooldown_pct": text = _b("本场冷却时间%s；最短%s秒", "Cooldown duration %s this combat; minimum %s seconds", language) % [_signed(value, true), _n(db.value("minimum_cooldown_seconds", 0.5))]
		"modify_damage_flat": text = _b("本场每次直接伤害%s", "Direct damage %s this combat", language) % _signed(value)
		"modify_crit_chance": text = _b("本场暴击率%s；总上限%s", "Critical chance %s this combat; total cap %s", language) % [_signed(value, true), _pct(db.value("crit_chance_cap", 0.75))]
		"modify_status_power": text = _b("本场状态与直接治疗强度%s", "Status and direct-healing power %s this combat", language) % _signed(value, true)
		"advance_cooldown": text = _b("立即推进%s秒冷却；同一根事件每目标上限%s秒", "Advance cooldown by %s seconds; cap %s seconds per target per root event", language) % [_n(p.get("seconds", value)), _n(db.value("cooldown_advance_cap_per_root", 1))]
		"gain_gold": text = _b("战斗结算获得%s金币", "Gain %s gold at combat settlement", language) % _n(value)
		"free_refresh": text = _b("战斗结算获得%s次免费刷新", "Gain %s free refreshes at combat settlement", language) % _n(p.get("count", value))
		"max_health": text = _b("本局最大生命%s，并恢复同等生命", "Run maximum health %s; restore the same amount", language) % _signed(value)
		_: text = _b("未知效果", "Unknown effect", language)
	var selector = str(row.get("target_selector", "self"))
	if not p.has("repeat_pct"):
		var target = {"self": _b("本方角色", "allied character", language), "enemy": _b("敌方角色", "enemy character", language), "source_item": _b("该物品", "this item", language), "spatial_targets": _b("范围内关联物品", "linked items in range", language)}.get(selector, "")
		if not str(target).is_empty(): text += _b("；作用于%s", "; target: %s", language) % target
	if float(p.get("duration", 0)) > 0: text += _b("，持续%s秒", ", for %s seconds", language) % _n(p.duration)
	var ctx = context.duplicate(true); ctx["interval"] = p.get("interval", row.get("interval", 1))
	text = trigger(str(row.get("trigger_id", "combat_start")), language, ctx) + _b("：", ": ", language) + text
	var condition_id = str(row.get("condition_id", "always"))
	if condition_id not in ["always", ""]: text += _b("。条件：", ". Condition: ", language) + condition(condition_id, row.get("condition_params", ""), language)
	var space = str(row.get("spatial_template_id", "none"))
	if space != "none": text += _b("。范围：", ". Range: ", language) + spatial(space, language)
	var count = row.get("per_combat_limit", p.get("limit", p.get("max_stacks", 0)))
	if float(count) > 0: text += _b("。本场最多%s次", ". At most %s times per combat", language) % _n(count)
	var trigger_row = db.get_row("trigger_templates", str(row.get("trigger_id", "")))
	var internal = float(row.get("internal_cooldown", 0 if row.has("character_id") else trigger_row.get("default_internal_cooldown", 0)))
	if internal > 0: text += _b("。触发间隔至少%s秒", ". Internal cooldown: %s seconds", language) % _n(internal)
	return text

func item(id: String, language: String = "zh_CN") -> String:
	var row = db.get_row("items", id)
	if row.is_empty(): return bag(id, language)
	var lines: Array = []
	if float(row.cooldown) > 0: lines.append(_b("基础冷却%s秒；每次激活消耗%s耐力。", "Base cooldown %s seconds; consume %s stamina per activation.", language) % [_n(row.cooldown), _n(row.stamina_cost)])
	for effect_row in db.rows("item_effects"):
		if effect_row.item_id == id: lines.append(effect(effect_row, language, {"cooldown": float(row.cooldown)}))
	return "\n".join(lines)

func bag(id: String, language: String = "zh_CN") -> String:
	var row = db.get_row("bags", id)
	if row.is_empty(): return _b("未知物品", "Unknown item", language)
	var shape = db.get_row("bag_shapes", str(row.shape_id))
	var text = _b("提供%s个有效格。", "Provides %s usable cells.", language) % _n(shape.get("cell_count", 0))
	if str(row.special_cell_type) == "none": return text
	text += _b("强化格仅影响覆盖该格的物品。", "Enhanced cells affect only items covering them.", language) if row.special_cell_type == "enhanced_cell" else _b("星位影响同包内覆盖星位或其四向相邻的物品。", "Stars affect same-bag items covering or orthogonally adjacent to the star.", language)
	var effects: Array = []; var params = _params(row.special_effect)
	for key in params:
		match key:
			"cooldown_pct": effects.append(_b("冷却时间%s", "cooldown duration %s", language) % _signed(params[key], true))
			"damage_flat": effects.append(_b("直接伤害%s", "direct damage %s", language) % _signed(params[key]))
			"crit_chance": effects.append(_b("暴击率%s", "critical chance %s", language) % _signed(params[key], true))
			"status_power": effects.append(_b("状态与直接治疗强度%s", "status and direct-healing power %s", language) % _signed(params[key], true))
			"armor_on_start": effects.append(_b("战斗开始获得%s护甲（每个背包一次）", "gain %s armor at combat start (once per bag)", language) % _n(params[key]))
			"stamina_on_start": effects.append(_b("战斗开始恢复%s耐力，不超过上限", "restore %s stamina at combat start, capped by maximum", language) % _n(params[key]))
	return text + _b("加成：", " Bonus: ", language) + _b("、", "; ", language).join(effects) + _b("。同类特殊格加成默认不叠加。", ". Matching special-cell bonuses do not stack by default.", language)

func affix(value, language: String = "zh_CN") -> String:
	var row = value if value is Dictionary else db.get_row("encounter_affixes", str(value))
	if row.is_empty(): return _b("无遭遇词缀", "No encounter affix", language)
	return term("encounter_affixes", str(row.id), language) + "\n" + effect(row, language)

func boss(id: String, language: String = "zh_CN", difficulty_id: String = "standard") -> String:
	var lines: Array = []
	var offset = 0.0
	var difficulty = db.get_row("difficulty_levels", difficulty_id)
	for modifier in db.rows("challenge_modifiers"):
		if int(modifier.challenge_level) <= int(difficulty.get("challenge_modifier_count", 0)):
			offset += float(db.parse_params(modifier.params).get("boss_threshold_offset", 0))
	for row in db.rows("boss_phases"):
		if row.boss_id != id: continue
		var p = _params(row.effect_params); var actions: Array = []
		for key in p:
			match key:
				"armor_gain": actions.append(_b("获得%s护甲", "gain %s armor", language) % _n(p[key]))
				"burn": actions.append(_b("向敌方施加%s层灼烧", "apply %s burn stacks to the enemy", language) % _n(p[key]))
				"heal": actions.append(_b("恢复%s生命", "restore %s health", language) % _n(p[key]))
				"front_damage_flat": actions.append(_b("最左武器前方3格内的武器直接伤害+%s；无目标时强化该武器", "give weapons within 3 cells ahead of the leftmost weapon +%s direct damage; buff that weapon if no target", language) % _n(p[key]))
		var threshold = clampf(float(row.health_threshold_pct) + (offset if int(row.phase) > 1 else 0.0), 0.0, 1.0)
		var text = _b("阶段%s：生命阈值%s，预告%s秒。每%s秒：", "Phase %s: health threshold %s; telegraph %s seconds. Every %s seconds: ", language) % [_n(row.phase), _pct(threshold), _n(row.telegraph_seconds), _n(p.get("interval", 5))]
		text += _b("；", "; ", language).join(actions)
		if p.has("cooldown_pct"): text += _b("；本阶段冷却时间%s", "; cooldown duration %s this phase", language) % _signed(p.cooldown_pct, true)
		if p.has("damage_flat"): text += _b("；护甲被击破后，本阶段每次直接伤害+%s", "; after armor breaks, direct damage +%s this phase", language) % _n(p.damage_flat)
		lines.append(text)
	return "\n".join(lines)

func status(id: String, language: String = "zh_CN") -> String:
	var row = db.get_row("statuses", id)
	if row.is_empty(): return _b("未知状态", "Unknown status", language)
	var text = ""
	match id:
		"poison": text = _b("每%s秒造成等于当前层数的真实伤害，然后减少1层。", "Every %s seconds, deal true damage equal to current stacks, then lose 1 stack.", language) % _n(row.tick_interval)
		"burn": text = _b("每%s秒造成当前层数一半的真实伤害（向下取整，最低1），然后减少1层。", "Every %s seconds, deal true damage equal to half the stacks (round down, minimum 1), then lose 1 stack.", language) % _n(row.tick_interval)
		"regeneration": text = _b("每%s秒恢复等于当前层数的生命，然后减少1层。", "Every %s seconds, restore health equal to current stacks, then lose 1 stack.", language) % _n(row.tick_interval)
		"slow": text = _b("每层降低%s冷却推进速度，总减速上限%s。", "Each stack reduces cooldown progress speed by %s, capped at %s.", language) % [_pct(row.value_per_stack), _pct(db.value("slow_cap", 0.5))]
		"haste": text = _b("每层提高%s冷却推进速度；与减速分别计算。", "Each stack increases cooldown progress speed by %s; multiplies separately with slow.", language) % _pct(row.value_per_stack)
		"lifesteal": text = _b("物理攻击按实际造成的生命伤害，每层恢复%s；护甲吸收不计入。", "Physical attacks heal %s per stack of actual health damage dealt; absorbed damage does not count.", language) % _pct(row.value_per_stack)
		"vulnerable": text = _b("每层提高%s受到的生命伤害；不增加护甲吸收量。", "Each stack increases health damage taken by %s; armor absorption is unchanged.", language) % _pct(row.value_per_stack)
		"fortified": text = _b("每层减少%s受到的物理伤害，总减伤上限%s。", "Each stack reduces incoming physical damage by %s, capped at %s.", language) % [_pct(row.value_per_stack), _pct(db.value("damage_reduction_cap", 0.7))]
	text += _b("层数上限%s。", " Stack cap: %s.", language) % _n(row.stack_cap)
	if row.decay_rule == "duration": text += _b("默认持续%s秒；再次施加延长到较晚到期时间。", " Default duration: %s seconds; reapplying keeps the later expiry.", language) % _n(row.default_duration)
	return text

func dictionary(language: String = "zh_CN") -> Array:
	var result: Array = []
	for row in db.rows("statuses"): result.append({"id": str(row.id), "term": term("statuses", str(row.id), language), "definition": status(str(row.id), language), "category": _b("状态", "Status", language)})
	var terms = [
		["occupied_cells", "占格", "Occupied cells", "物品旋转后占用的整数格。贴图不参与逻辑碰撞。", "Integer cells occupied after rotation. Artwork never defines logical collision."],
		["valid_cells", "有效格", "Usable cells", "背包层提供的格；普通物品每格都必须被覆盖。", "Cells provided by bags; every ordinary item cell must be covered."],
		["bag_layer", "背包层", "Bag layer", "背包之间不能重叠；普通物品可与其覆盖格重合。", "Bags cannot overlap other bags; ordinary items occupy their usable cells."],
		["star", "星位", "Star", "同包星位及四向邻接可关联物品；星位配方要求至少一材料实际覆盖星位。", "Stars link same-bag items on or adjacent to them. Star recipes require a material actually covering a star."],
		["cooldown", "冷却", "Cooldown", "物品等待激活的时间；下限%s秒。", "Time until an item can activate; minimum %s seconds."],
		["stamina", "耐力", "Stamina", "激活武器等物品的资源；不足时每%s秒重试，不重置完整冷却。", "Resource consumed by weapons and other items. Insufficient stamina retries every %s seconds without resetting the full cooldown."],
		["critical", "暴击", "Critical hit", "仅物理攻击可暴击；暴击率上限%s，倍率由角色配置。", "Only physical attacks critically hit. Critical chance is capped at %s; multiplier comes from character data."],
		["armor", "护甲", "Armor", "先吸收物理伤害；真实伤害不消耗护甲。战斗结束清空，不是持续状态。", "Absorbs physical damage first. True damage bypasses armor. Cleared after combat; not a timed status."],
		["cleanse", "净化", "Cleanse", "即时移除指定总量负面状态层，不产生净化层数；按稳定状态顺序移除。", "Instantly removes a fixed total of negative stacks in stable status order; cleanse itself has no stacks."],
		["lock", "锁定", "Lock", "最多锁定%s件商品；跨一个标准商店保留原槽与价格，可重新锁定。", "Lock at most %s offers. Keep their slot and price for the next standard shop; they may be locked again."],
		["sale", "促销", "Sale", "每次生成恰好一个促销位，折扣%s，价格最低1金币。", "Exactly one sale slot per generation, discounted by %s, with a minimum price of 1 gold."],
		["interest", "利息", "Interest", "战胜普通或精英后，每%s结余金币获得1利息，通常上限%s；事件金币不再生利息。", "After a normal or elite victory, gain 1 interest per %s saved gold, normally capped at %s. Event gold does not trigger interest."],
		["refresh", "刷新", "Refresh", "保留锁定槽；标准费用1、1、2、2、3……，每商店重置，并应用难度修正。", "Keeps locked slots. Base costs: 1, 1, 2, 2, 3…; resets per shop and applies difficulty modifiers."],
		["craft", "合成", "Crafting", "两材料满足空间、章节和优先级后手动确认；最多二阶；无法放入的成品进入待处理区。", "Manually confirm two eligible materials after spatial, chapter and priority checks. Maximum tier 2; an unplaceable result enters pending rewards."],
		["storage", "仓库", "Storage", "初始%s格，最多%s格；入库物品不战斗、不提供标签或空间效果。", "Starts at %s slots, maximum %s. Stored items do not fight or provide tags or spatial effects."],
		["chain", "触发链", "Trigger chain", "根事件最多派生%s层；同物品同根事件默认一次；死亡会中断后续派生。", "Maximum derived depth %s per root event. Each item normally activates once per root; death interrupts later events."],
		["fatigue", "疲劳", "Fatigue", "%s秒后进入疲劳；每%s秒双方递增真实伤害并降低治疗；不触发受击效果，同时死亡玩家失败。", "Fatigue begins after %s seconds. Every %s seconds both sides take increasing true damage and healing is reduced. It triggers no damage-taken effects; simultaneous death is a player loss."]]
	var values = {"cooldown": [_n(db.value("minimum_cooldown_seconds", 0.5))], "stamina": [_n(db.value("stamina_retry_seconds", 0.2))], "critical": [_pct(db.value("crit_chance_cap", 0.75))], "lock": [_n(db.value("shop_lock_limit", 2))], "sale": [_pct(db.value("shop_discount_pct", 0.25))], "interest": [_n(db.value("interest_step_gold", 5)), _n(db.value("interest_cap", 2))], "storage": [_n(db.value("storage_start", 2)), _n(db.value("storage_cap", 4))], "chain": [_n(db.value("chain_depth_limit", 8))], "fatigue": [_n(db.value("fatigue_start_seconds", 85)), _n(db.value("fatigue_tick_seconds", 2))]}
	for row in terms:
		var text = _b(row[3], row[4], language)
		if values.has(row[0]): text = text % values[row[0]]
		result.append({"id": row[0], "term": _b(row[1], row[2], language), "definition": text, "category": _b("规则", "Rule", language)})
	for row in db.rows("spatial_templates"):
		if row.id != "none": result.append({"id": "spatial:" + str(row.id), "term": term("spatial_templates", str(row.id), language), "definition": spatial(str(row.id), language), "category": _b("空间", "Spatial", language)})
	return result

func describe_item(id: String, language: String = "zh_CN") -> String: return item(id, language)
func describe_effect(row: Dictionary, language: String = "zh_CN", context: Dictionary = {}) -> String: return effect(row, language, context)
func describe_affix(value, language: String = "zh_CN") -> String: return affix(value, language)
