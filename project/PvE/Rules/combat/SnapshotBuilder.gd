class_name SnapshotBuilder
extends RefCounted

const Spatial = preload("res://PvE/Rules/inventory/SpatialQueryService.gd")
const Placement = preload("res://PvE/Rules/inventory/PlacementService.gd")
var db
var spatial
var placement

func _init(content = null):
	db = content
	spatial = Spatial.new(content)
	placement = Placement.new(content)

func player(run: Dictionary) -> Dictionary:
	var character = db.get_row("characters", str(run.get("character_id", "")))
	if character.is_empty(): return {"ok": false, "error": "unknown_character"}
	var stats = {"max_health": float(run.get("max_health", character.max_health)), "health": float(run.get("health", character.starting_health)),
		"stamina_max": float(character.stamina_max), "stamina_regen": float(character.stamina_regen_per_sec),
		"crit_chance": float(character.base_crit_chance), "crit_multiplier": float(character.base_crit_multiplier), "damage_scalar": 1.0, "status_scalar": 1.0}
	var snapshot = _build(run.get("build", {}), stats, str(run.get("run_id", "player")), str(character.id))
	if not snapshot.get("ok", false): return snapshot
	for row in db.rows("character_passives"):
		if str(row.character_id) == str(character.id): snapshot.passives.append(row.duplicate(true))
	return _seal(snapshot)

func enemy(enemy_id: String, difficulty_id: String, affix_id = "") -> Dictionary:
	if db.get_row("difficulty_levels", difficulty_id).is_empty(): return {"ok": false, "error": "unknown_difficulty"}
	var row = db.get_row("enemy_builds", enemy_id)
	if row.is_empty(): return {"ok": false, "error": "unknown_enemy"}
	var build = _empty_build()
	for bag in db.rows("enemy_build_bags"):
		if str(bag.enemy_build_id) == enemy_id: build.bags.append(_entry(bag, "bag_id"))
	for item in db.rows("enemy_build_items"):
		if str(item.enemy_build_id) == enemy_id: build.items.append(_entry(item, "item_id"))
	var snapshot = _build(build, _enemy_stats(row, difficulty_id), enemy_id, "")
	if not snapshot.get("ok", false): return snapshot
	snapshot["enemy_type"] = str(row.get("node_type", "normal"))
	snapshot["threat_tags"] = _list(row.get("threat_tags", ""))
	var affixes: Array = db.list_values(affix_id)
	if affixes.is_empty(): affixes = db.list_values(row.get("affix_id", ""))
	var seen: Dictionary = {}
	for affix in affixes:
		if seen.has(str(affix)): continue
		seen[str(affix)] = true
		var modifier = db.get_row("encounter_affixes", affix)
		if modifier.is_empty(): return {"ok": false, "error": "unknown_affix"}
		snapshot.encounter_modifiers.append(modifier)
	return _seal(snapshot)

func boss(boss_id: String, difficulty_id: String) -> Dictionary:
	if db.get_row("difficulty_levels", difficulty_id).is_empty(): return {"ok": false, "error": "unknown_difficulty"}
	var row = db.get_row("bosses", boss_id)
	if row.is_empty(): return {"ok": false, "error": "unknown_boss"}
	var build = _empty_build()
	if db.has_method("boss_bags"):
		build.bags = db.boss_bags(boss_id)
	else:
		for token in str(row.get("bag_layout", "")).split("|", false):
			var fields = token.split(":")
			if fields.size() == 4: build.bags.append({"uid": "%s_bag_%d" % [boss_id, build.bags.size()], "definition_id": fields[0], "x": int(fields[1]), "y": int(fields[2]), "rotation": int(fields[3])})
	for item in db.rows("boss_build_items"):
		if str(item.boss_id) == boss_id:
			var entry = _entry(item, "item_id")
			entry["phase"] = int(item.get("phase", 1))
			build.items.append(entry)
	var snapshot = _build(build, _enemy_stats(row, difficulty_id), boss_id, "")
	if not snapshot.get("ok", false): return snapshot
	snapshot["enemy_type"] = "boss"
	snapshot["boss_rule_id"] = str(row.get("persistent_rule_id", ""))
	snapshot["boss_phases"] = []
	var threshold_offset = 0.0
	var difficulty = db.get_row("difficulty_levels", difficulty_id)
	for modifier in db.rows("challenge_modifiers"):
		if int(modifier.challenge_level) <= int(difficulty.get("challenge_modifier_count", 0)):
			threshold_offset += float(db.parse_params(modifier.params).get("boss_threshold_offset", 0))
	for phase in db.rows("boss_phases"):
		if str(phase.boss_id) == boss_id:
			var copy = phase.duplicate(true)
			if int(copy.phase) > 1: copy.health_threshold_pct = clampf(float(copy.health_threshold_pct) + threshold_offset, 0.0, 1.0)
			snapshot.boss_phases.append(copy)
	snapshot.boss_phases.sort_custom(func(a, b): return int(a.phase) < int(b.phase))
	return _seal(snapshot)

func _enemy_stats(row: Dictionary, difficulty_id: String) -> Dictionary:
	var difficulty = db.get_row("difficulty_levels", difficulty_id)
	var health = float(row.get("max_health", 100)) * float(difficulty.get("enemy_health_scalar", 1.0))
	return {"max_health": health, "health": health, "stamina_max": float(row.get("stamina_max", 10)),
		"stamina_regen": float(row.get("stamina_regen", 1.7)), "crit_chance": 0.05, "crit_multiplier": 1.5,
		"damage_scalar": float(difficulty.get("enemy_damage_scalar", 1.0)), "status_scalar": float(difficulty.get("enemy_status_scalar", 1.0))}

func from_build(build: Dictionary, stats: Dictionary, owner_id: String, character_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	# Developer editors and imported fixtures use exactly the production spatial resolver.
	var snapshot = _build(build, stats.duplicate(true), owner_id, character_id)
	if not snapshot.get("ok", false): return snapshot
	for field in ["passives", "encounter_modifiers", "boss_phases", "boss_rule_id", "enemy_type", "threat_tags"]:
		if metadata.has(field): snapshot[field] = metadata[field].duplicate(true) if metadata[field] is Array or metadata[field] is Dictionary else metadata[field]
	return _seal(snapshot)

func _build(build: Dictionary, stats: Dictionary, owner_id: String, character_id: String) -> Dictionary:
	var validation = placement.validate(build)
	if not validation.ok: return {"ok": false, "error": "invalid_layout", "validation": validation}
	var snapshot = {"ok": true, "error": "", "snapshot_version": 2, "content_version": str(db.value("content_version", "0.1.0")),
		"content_sha256": str(db.content_sha256),
		"owner_id": owner_id, "character_def_id": character_id, "base_stats": stats, "bags": [], "items": [],
		"passives": [], "bag_effects": [], "resolved_spatial_links": [], "encounter_modifiers": [], "boss_phases": []}
	var derived = spatial.derived(build)
	for bag in build.get("bags", []):
		var copy = bag.duplicate(true)
		copy["instance_id"] = str(copy.uid)
		copy["def_id"] = str(copy.definition_id)
		copy["origin"] = [int(copy.x), int(copy.y)]
		snapshot.bags.append(copy)
	for entry in build.get("items", []):
		var row = db.get_row("items", str(entry.definition_id))
		var uid = str(entry.uid)
		var item = {"instance_id": uid, "def_id": str(row.id), "x": int(entry.x), "y": int(entry.y), "origin": [int(entry.x), int(entry.y)],
			"rotation": int(entry.rotation), "shape_id": str(row.shape_id), "tags": _list(row.tags), "cooldown": float(row.cooldown),
			"stamina_cost": float(row.stamina_cost), "phase": int(entry.get("phase", 1)), "effects": [], "static_modifiers": [], "relations": derived[uid].relations}
		for effect in db.rows("item_effects"):
			if str(effect.item_id) == str(row.id): item.effects.append(effect)
		item.effects.sort_custom(func(a, b): return int(a.sequence) < int(b.sequence))
		var applied_bags: Dictionary = {}
		for special in derived[uid].special_cells:
			if str(special.effect).is_empty(): continue
			var bag_id = str(special.bag_uid)
			var special_key = str(special.type) + ":" + str(special.effect)
			if applied_bags.has(special_key) and not bool(special.stackable): continue
			applied_bags[special_key] = true
			var params = parse_params(special.effect)
			for key in params:
				if key in ["cooldown_pct", "status_power", "damage_flat", "crit_chance"]: item.static_modifiers.append({"stat": key, "value": float(params[key]), "duration": 0.0})
			for pair in [["armor_on_start", "gain_armor"], ["stamina_on_start", "gain_stamina"]]:
				if params.has(pair[0]):
					var effect_id = bag_id + ":" + str(pair[0])
					if not snapshot.bag_effects.any(func(v): return str(v.id) == effect_id):
						snapshot.bag_effects.append({"id": effect_id, "phase": int(entry.get("phase", 1)), "trigger_id": "combat_start", "effect_type": pair[1], "effect_params": "value:" + str(params[pair[0]]), "target_selector": "self", "condition_id": "always", "chain_depth_cost": 1})
		snapshot.items.append(item)
		snapshot.resolved_spatial_links.append({"instance_id": uid, "relations": derived[uid].relations})
	snapshot.items.sort_custom(func(a, b): return _item_before(a, b))
	return snapshot

func _seal(snapshot: Dictionary) -> Dictionary:
	snapshot["validation_digest"] = JSON.stringify(snapshot, "", true, true).sha256_text()
	return snapshot

func _empty_build() -> Dictionary:
	return {"width": 9, "height": 7, "bags": [], "items": [], "storage": [], "storage_capacity": 2}

func _entry(row: Dictionary, id_key: String) -> Dictionary:
	return {"uid": str(row.instance_id), "definition_id": str(row[id_key]), "x": int(row.origin_x), "y": int(row.origin_y), "rotation": int(row.rotation), "used": false, "purchase_price": 0, "purchased_visit": 0}

func _item_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.y) != int(b.y): return int(a.y) < int(b.y)
	if int(a.x) != int(b.x): return int(a.x) < int(b.x)
	return str(a.instance_id) < str(b.instance_id)

func _list(raw) -> Array:
	if raw is Array: return raw.duplicate()
	return Array(str(raw).split("|", false))

static func parse_params(raw) -> Dictionary:
	if raw is Dictionary: return raw.duplicate(true)
	var result: Dictionary = {}
	for pair in str(raw).split("|", false):
		var fields = pair.split(":", true, 1)
		if fields.size() == 2: result[str(fields[0])] = str(fields[1])
		else: result["value"] = str(pair)
	return result
