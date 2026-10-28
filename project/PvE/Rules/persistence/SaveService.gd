class_name SaveService
extends RefCounted

const SCHEMA = 2
var base_path: String
var notices: Array = []
var last_error: String = ""
var last_run_archive: String = ""

func _init(directory: String = "user://"):
	base_path = directory.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path))

func _path(kind: String, suffix: String = "") -> String:
	return base_path + kind + suffix + ".save"

func _envelope(data: Dictionary) -> Dictionary:
	var dto = data.duplicate(true)
	dto["schema_version"] = SCHEMA
	var payload = JSON.stringify(dto, "", true)
	return {"envelope_version": 1, "payload": payload, "sha256": payload.sha256_text()}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "error": "missing"}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {"ok": false, "error": "invalid_json"}
	var envelope = parser.data
	if not envelope is Dictionary: return {"ok": false, "error": "invalid_json"}
	var data = envelope
	if envelope.has("payload"):
		if not envelope.payload is String or envelope.payload.sha256_text() != envelope.get("sha256", ""):
			return {"ok": false, "error": "checksum_failed"}
		if parser.parse(envelope.payload) != OK: return {"ok": false, "error": "invalid_payload"}
		data = parser.data
	if not data is Dictionary: return {"ok": false, "error": "invalid_payload"}
	var version = int(data.get("schema_version", 1))
	if version > SCHEMA or version < 1: return {"ok": false, "error": "unsupported_schema"}
	return {"ok": true, "error": "", "data": data, "version": version}

func save(kind: String, data: Dictionary) -> bool:
	if kind not in ["run", "profile", "settings"]:
		last_error = "invalid_save_kind"
		return false
	var path = _path(kind)
	var temp = _path(kind, "_temporary")
	var backup = _path(kind, "_backup")
	var handle = FileAccess.open(temp, FileAccess.WRITE)
	if handle == null:
		last_error = "save_write_failed"
		return false
	handle.store_string(JSON.stringify(_envelope(data), "", true))
	handle.flush()
	handle.close()
	if not _read(temp).ok:
		last_error = "temporary_verification_failed"
		return false
	# Never replace the good backup with a damaged primary file.
	if FileAccess.file_exists(path) and _read(path).ok:
		var copy_error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
		if copy_error != OK:
			last_error = "backup_write_failed"
			return false
	var rename_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		last_error = "atomic_replace_failed"
		return false
	last_error = ""
	return true

func load_save(kind: String) -> Dictionary:
	var primary = _read(_path(kind))
	if not primary.ok:
		var backup = _read(_path(kind, "_backup"))
		if not backup.ok: return {"ok": false, "error": primary.error, "data": {}, "recovered": false}
		if FileAccess.file_exists(_path(kind)):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(_path(kind)), ProjectSettings.globalize_path(_path(kind, "_corrupt_" + str(Time.get_unix_time_from_system()).replace(".", "_"))))
		primary = backup
		primary["recovered"] = true
		notices.append("save_backup_recovered")
	else:
		primary["recovered"] = false
	if int(primary.version) < SCHEMA:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(_path(kind)), ProjectSettings.globalize_path(_path(kind, "_before_migration_v" + str(primary.version))))
		primary.data = migrate(kind, primary.data)
		notices.append("save_schema_migrated")
		save(kind, primary.data)
	return primary

func migrate(kind: String, original: Dictionary) -> Dictionary:
	var data = original.duplicate(true)
	while int(data.get("schema_version", 1)) < SCHEMA:
		match int(data.get("schema_version", 1)):
			1:
				if kind == "run":
					if data.has("current_health"):
						data["health"] = data.current_health
						data.erase("current_health")
					if not data.has("run_effects"): data["run_effects"] = []
					if not data.has("completed_nodes"): data["completed_nodes"] = []
					if not data.has("logs"): data["logs"] = []
					if not data.has("pending_rewards"): data["pending_rewards"] = []
					if not data.has("next_uid"): data["next_uid"] = 100
				if kind == "profile" and not data.has("pending_platform_achievements"):
					data["pending_platform_achievements"] = []
				data["schema_version"] = 2
	return data

func exists(kind: String) -> bool:
	return _read(_path(kind)).ok or _read(_path(kind, "_backup")).ok

func archive_current_run() -> bool:
	# The rolling backup protects the last write, not a whole previous adventure.
	# Preserve the previous run separately before a confirmed new run can replace it.
	var source = _path("run")
	var previous = _read(source)
	if not previous.ok:
		source = _path("run", "_backup")
		previous = _read(source)
	if not previous.ok:
		last_error = "archive_source_invalid"
		return false
	var identifier = str(previous.data.get("run_id", "run")).validate_filename()
	var folder = base_path.path_join("archives").path_join(identifier + "_" + str(Time.get_ticks_usec()))
	var directory = ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "archive_write_failed"
		return false
	var destination = folder.path_join("run.save")
	var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
	if error != OK or not _read(destination).ok or FileAccess.get_sha256(source) != FileAccess.get_sha256(destination):
		last_error = "archive_verification_failed"
		return false
	last_run_archive = folder
	last_error = ""
	return true

func validate_run(data: Dictionary, content) -> Dictionary:
	for key in ["run_id", "character_id", "difficulty_id", "loadout_id", "content_version", "build", "state", "rng", "health", "max_health", "gold", "act", "step", "visit", "next_uid", "completed_nodes", "pending_rewards", "current_node", "shop", "combat_checkpoint", "logs", "route_candidates"]:
		if not data.has(key): return {"ok": false, "error": "save_missing_" + key}
	if content.get_row("characters", str(data.character_id)).is_empty() or content.get_row("difficulty_levels", str(data.difficulty_id)).is_empty():
		return {"ok": false, "error": "save_unknown_definition"}
	if not data.build is Dictionary or not data.rng is Dictionary: return {"ok": false, "error": "save_invalid_structure"}
	for key in ["bags", "items", "storage"]:
		if not data.build.get(key) is Array: return {"ok": false, "error": "save_invalid_structure"}
		for entry in data.build[key]:
			if not entry is Dictionary: return {"ok": false, "error": "save_invalid_structure"}
			for field in ["uid", "definition_id", "x", "y", "rotation"]:
				if not entry.has(field): return {"ok": false, "error": "save_invalid_structure"}
	for key in ["route", "shop", "reward", "combat"]:
		if not data.rng.get(key) is float and not data.rng.get(key) is int: return {"ok": false, "error": "save_invalid_structure"}
		var value = float(data.rng[key])
		if value != floor(value) or value < 0 or value > 4294967295: return {"ok": false, "error": "save_invalid_rng"}
	for key in ["completed_nodes", "pending_rewards", "logs", "route_candidates"]:
		if not data[key] is Array: return {"ok": false, "error": "save_invalid_structure"}
	for key in ["current_node", "shop", "combat_checkpoint"]:
		if not data[key] is Dictionary: return {"ok": false, "error": "save_invalid_structure"}
	if float(data.max_health) <= 0 or float(data.health) < 0 or int(data.gold) < 0: return {"ok": false, "error": "save_invalid_values"}
	if str(data.state) in ["COMBAT_PREPARE", "COMBAT_RUNNING"]:
		var checkpoint: Dictionary = data.combat_checkpoint
		if not checkpoint.get("player") is Dictionary or not checkpoint.get("enemy") is Dictionary or not checkpoint.has("seed"): return {"ok": false, "error": "save_invalid_combat"}
	if int(data.get("act", 0)) not in [1, 2, 3] or int(data.get("step", 0)) < 1 or int(data.get("step", 0)) > 5:
		return {"ok": false, "error": "save_invalid_progress"}
	return {"ok": true, "error": ""}
