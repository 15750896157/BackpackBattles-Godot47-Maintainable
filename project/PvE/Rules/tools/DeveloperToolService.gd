class_name PvEDeveloperToolService
extends RefCounted

var db
var builder
var placement

func _init(content = null):
	db = content
	builder = SnapshotBuilder.new(db)
	placement = PlacementService.new(db)

func inspect_definition(id: String) -> Dictionary:
	var row = placement.definition(id)
	if row.is_empty(): return {"ok": false, "error": "unknown_definition"}
	var bag = str(row.kind) == "bag"
	var effects: Array = []
	for effect in db.rows("item_effects"):
		if str(effect.item_id) == id: effects.append(effect)
	var binding_data = JSON.parse_string(FileAccess.get_file_as_string("res://PvE/asset_bindings.json"))
	var binding = binding_data.get("bindings", {}).get(id, {}) if binding_data is Dictionary else {}
	return {"ok": true, "error": "", "id": id, "names": {"zh_CN": db.text(row.name_key, "zh_CN"), "en": db.text(row.name_key, "en")},
		"definition": row, "shape": db.get_row("bag_shapes" if bag else "item_shapes", str(row.shape_id)), "effects": effects,
		"original_asset_binding": binding, "asset_exists": FileAccess.file_exists(str(row.get("icon_ref", "")))}

func loadout_snapshot(id: String) -> Dictionary:
	var loadout = db.get_row("character_loadouts", id)
	if loadout.is_empty(): return {"ok": false, "error": "unknown_loadout"}
	var character = db.get_row("characters", str(loadout.character_id))
	var build = {"width": int(db.value("grid_width", 9)), "height": int(db.value("grid_height", 7)), "items": [], "bags": [], "storage": [], "storage_capacity": 2}
	build.bags.append({"uid": "starting_bag", "definition_id": loadout.starting_bag_id, "x": 0, "y": 0, "rotation": 0})
	for entry in db.rows("starting_build_items"):
		if entry.loadout_id == id: build.items.append({"uid": entry.instance_id, "definition_id": entry.item_id, "x": int(entry.origin_x), "y": int(entry.origin_y), "rotation": int(entry.rotation)})
	return builder.player({"run_id": "developer:" + id, "character_id": loadout.character_id, "max_health": character.max_health, "health": character.starting_health, "build": build})

func opponent_snapshot(id: String, difficulty: String = "standard", affixes = []) -> Dictionary:
	if not db.get_row("bosses", id).is_empty(): return builder.boss(id, difficulty)
	return builder.enemy(id, difficulty, affixes)

func build_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var build = {"width": int(db.value("grid_width", 9)), "height": int(db.value("grid_height", 7)), "items": [], "bags": [], "storage": [], "storage_capacity": 2}
	for field in ["items", "bags"]:
		for source in snapshot.get(field, []):
			var origin = source.get("origin", [source.get("x", 0), source.get("y", 0)])
			build[field].append({"uid": str(source.instance_id), "definition_id": str(source.def_id), "x": int(origin[0]), "y": int(origin[1]), "rotation": int(source.get("rotation", 0)), "phase": int(source.get("phase", 1))})
	return build

func validate_import(value) -> Dictionary:
	if not value is Dictionary: return {"ok": false, "error": "snapshot_schema"}
	var candidate = value.get("snapshot", value)
	if not candidate is Dictionary: return {"ok": false, "error": "snapshot_schema"}
	var snapshot: Dictionary = candidate
	var validation = CombatEngine.new(db).validate_snapshot(snapshot)
	if not validation.ok: return validation
	if str(snapshot.get("content_version", "")) != str(db.content_version) or str(snapshot.get("content_sha256", "")) != str(db.content_sha256):
		return {"ok": false, "error": "snapshot_content_hash_mismatch"}
	for field in ["items", "bags"]:
		if not snapshot.get(field, []) is Array: return {"ok": false, "error": "snapshot_layout"}
		for entry in snapshot.get(field, []):
			if not entry is Dictionary or not entry.get("origin", []) is Array or entry.get("origin", []).size() != 2: return {"ok": false, "error": "snapshot_layout"}
			for coordinate in entry.origin:
				if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or float(coordinate) != floor(float(coordinate)): return {"ok": false, "error": "snapshot_layout"}
			if placement.definition(str(entry.get("def_id", ""))).is_empty(): return {"ok": false, "error": "unknown_definition"}
	var layout = placement.validate(build_from_snapshot(snapshot))
	if not layout.ok: return layout
	return {"ok": true, "error": "", "snapshot": snapshot.duplicate(true)}

func edit_snapshot(snapshot: Dictionary, uid: String, x: int, y: int, rotation: int) -> Dictionary:
	var validation = validate_import(snapshot)
	if not validation.ok: return validation
	var build = build_from_snapshot(snapshot)
	var result = placement.move(build, uid, x, y, rotation)
	if not result.ok: return result
	var updated = builder.from_build(build, snapshot.base_stats, str(snapshot.owner_id), str(snapshot.get("character_def_id", "")), snapshot)
	return {"ok": bool(updated.get("ok", false)), "error": str(updated.get("error", "")), "snapshot": updated}

func export_enemy(snapshot: Dictionary) -> Dictionary:
	var validation = validate_import(snapshot)
	if not validation.ok: return validation
	var id = str(snapshot.owner_id)
	var definition = db.get_row("enemy_builds", id)
	if definition.is_empty(): definition = db.get_row("bosses", id)
	definition = definition.duplicate(true)
	definition["id"] = id
	definition["max_health"] = float(snapshot.base_stats.max_health)
	definition["stamina_max"] = float(snapshot.base_stats.get("stamina_max", 10))
	definition["stamina_regen"] = float(snapshot.base_stats.get("stamina_regen", 1.7))
	var items: Array = []; var bags: Array = []
	var boss = str(snapshot.get("enemy_type", "")) == "boss"
	for entry in build_from_snapshot(snapshot).items:
		var row = {"instance_id": entry.uid, "item_id": entry.definition_id, "origin_x": entry.x, "origin_y": entry.y, "rotation": entry.rotation}
		row["boss_id" if boss else "enemy_build_id"] = id
		if boss: row["phase"] = entry.phase
		items.append(row)
	for entry in build_from_snapshot(snapshot).bags:
		bags.append({"enemy_build_id": id, "instance_id": entry.uid, "bag_id": entry.definition_id, "origin_x": entry.x, "origin_y": entry.y, "rotation": entry.rotation})
	return {"ok": true, "error": "", "format": "backpack-pve-enemy-draft", "definition_resource_type": "EnemyBuildDefinition", "definition": definition,
		"item_rows": items, "bag_rows": bags, "snapshot": snapshot.duplicate(true), "note": "Export is a draft; source CSVs are never overwritten. Scaled snapshot stats remain explicit."}

func batch(player: Dictionary, enemy: Dictionary, first_seed: int, count: int) -> Dictionary:
	if count < 1 or count > 2000: return {"ok": false, "error": "batch_count_range"}
	for snapshot in [player, enemy]:
		var validation = CombatEngine.new(db).validate_snapshot(snapshot)
		if not validation.ok: return validation
	var runs: Array = []
	for index in count:
		var result = CombatEngine.new(db).simulate(player, enemy, first_seed + index)
		if not result.ok: return result
		runs.append({"seed": first_seed + index, "winner_side": result.winner_side, "elapsed_time": result.elapsed_time, "player_remaining_health": result.player_remaining_health,
			"enemy_remaining_health": result.enemy_remaining_health, "replay_digest": result.replay_digest, "event_count": result.event_count, "stamina_starvation_time": result.stamina_starvation_time})
	return batch_summary(runs)

func batch_summary(runs: Array) -> Dictionary:
	var wins = 0; var seconds = 0.0; var health = 0.0
	for result in runs:
		wins += int(int(result.winner_side) == 0)
		seconds += float(result.elapsed_time)
		health += float(result.player_remaining_health)
	return {"ok": true, "error": "", "content_version": db.content_version, "content_sha256": db.content_sha256, "runs": runs,
		"count": runs.size(), "wins": wins, "win_rate": float(wins) / max(1, runs.size()), "average_seconds": seconds / max(1, runs.size()), "average_player_health": health / max(1, runs.size())}
