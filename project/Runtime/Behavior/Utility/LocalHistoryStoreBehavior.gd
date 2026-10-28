extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/LocalHistoryStore.gd")

static func open(subject: Receiver) -> bool:
	subject.last_error = ""
	subject.recovery_message = ""
	subject._runs.clear()
	subject._rounds.clear()
	subject._revision = 0
	var best: Dictionary = {}
	var best_path = ""
	var invalid_paths: Array[String] = []
	for candidate_path in [subject.path, subject.path + ".bak", subject.path + ".tmp"]:
		if not FileAccess.file_exists(candidate_path):
			continue
		var candidate = subject._read_snapshot(candidate_path)
		if candidate.is_empty():
			invalid_paths.append(candidate_path)
		elif best.is_empty() or int(candidate.revision) > int(best.revision):
			best = candidate
			best_path = candidate_path
	if best.is_empty():
		if not invalid_paths.is_empty():
			for invalid_path in invalid_paths:
				subject._preserve_corrupt_file(invalid_path)
			subject.recovery_message = "Unreadable history was preserved; a new local history was created."
		return subject.last_error == ""
	subject._apply_snapshot(best)
	if best_path != subject.path or subject.path in invalid_paths:
		if subject.path in invalid_paths:
			subject._preserve_corrupt_file(subject.path)
		subject.recovery_message = "Local history recovered from a validated backup or pending save."
		# The valid source stays intact until the replacement is flushed.
		if not subject._write_snapshot(best, subject.path + ".restore") or not subject._replace_file(subject.path + ".restore", subject.path):
			subject.last_error = "History loaded, but the recovered primary file could not be restored."
			return false
	return true

static func read_rounds(subject: Receiver) -> Array:
	var result: Array = []
	var ids = subject._rounds.keys()
	ids.sort()
	for run_id in ids:
		var round_ids = subject._rounds[run_id].keys()
		round_ids.sort()
		for round_id in round_ids:
			result.append(subject._rounds[run_id][round_id].duplicate(true))
	return result

static func update_run(subject: Receiver, run_id: int, fields: Dictionary) -> bool:
	if not subject._runs.has(run_id):
		return subject._fail("Cannot update an unsaved run.")
	var row: Dictionary = subject._runs[run_id].duplicate(true)
	for key in fields:
		if key not in subject.SPECIAL_FIELDS:
			return subject._fail("Unsupported history update: " + str(key))
		row[key] = fields[key]
	return subject.write_run(row)

static func write_round(subject: Receiver, value: Dictionary) -> bool:
	var row = subject._normalize_round(value)
	if row.is_empty() or not subject._runs.has(row.runID):
		return subject._fail("Invalid round history data or missing parent run.")
	var next_rounds = subject._rounds.duplicate(true)
	if not next_rounds.has(row.runID):
		next_rounds[row.runID] = {}
	# Repeated notifications replace a round instead of duplicating it.
	next_rounds[row.runID][row.roundID] = row
	return subject._commit(subject._runs, next_rounds)

static func prune(subject: Receiver, max_runs: int, minimum_run_id: int) -> bool:
	var retained: Dictionary = {}
	var ids = subject._runs.keys()
	ids.sort()
	for run_id in ids:
		if int(run_id) >= minimum_run_id:
			retained[run_id] = subject._runs[run_id]
	var retained_ids = retained.keys()
	retained_ids.sort()
	while retained_ids.size() > maxi(0, max_runs):
		retained.erase(retained_ids.pop_front())
	if retained.size() == subject._runs.size():
		return true
	var rounds: Dictionary = {}
	for run_id in retained:
		if subject._rounds.has(run_id):
			rounds[run_id] = subject._rounds[run_id]
	return subject._commit(retained, rounds)

static func _commit(subject: Receiver, runs: Dictionary, rounds: Dictionary) -> bool:
	subject.last_error = ""
	var snapshot = subject._snapshot(runs, rounds, subject._revision + 1)
	if subject._normalize_snapshot(snapshot).is_empty():
		return subject._fail("History validation failed before saving.")
	if not subject._write_snapshot(snapshot, subject.path + ".tmp") or not subject._replace_file(subject.path + ".tmp", subject.path):
		return false
	subject._apply_snapshot(snapshot)
	# The backup represents the latest completed save, including its last round.
	if not subject._write_snapshot(snapshot, subject.path + ".bak.tmp") or not subject._replace_file(subject.path + ".bak.tmp", subject.path + ".bak"):
		subject.recovery_message = "History saved, but its backup could not be updated."
	return true

static func _snapshot(subject: Receiver, runs: Dictionary, rounds: Dictionary, revision: int) -> Dictionary:
	var run_rows: Array = []
	var round_rows: Array = []
	var ids = runs.keys()
	ids.sort()
	for run_id in ids:
		run_rows.append(runs[run_id].duplicate(true))
		if rounds.has(run_id):
			var round_ids = rounds[run_id].keys()
			round_ids.sort()
			for round_id in round_ids:
				round_rows.append(rounds[run_id][round_id].duplicate(true))
	return {"format": subject.FORMAT, "schema_version": subject.SCHEMA_VERSION, "revision": revision,
		"runs": run_rows, "rounds": round_rows}

static func _apply_snapshot(subject: Receiver, snapshot: Dictionary):
	subject._runs.clear()
	subject._rounds.clear()
	subject._revision = int(snapshot.revision)
	for row in snapshot.runs:
		subject._runs[int(row.runID)] = row.duplicate(true)
	for row in snapshot.rounds:
		var run_id = int(row.runID)
		if not subject._rounds.has(run_id):
			subject._rounds[run_id] = {}
		subject._rounds[run_id][int(row.roundID)] = row.duplicate(true)

static func _read_snapshot(subject: Receiver, file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > subject.MAX_FILE_BYTES:
		return {}
	var text = file.get_as_text()
	file.close()
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return {}
	return subject._normalize_snapshot(parser.data)

static func _normalize_snapshot(subject: Receiver, value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format") != subject.FORMAT:
		return {}
	if not subject._is_integer(value.get("schema_version")) or int(value.schema_version) != subject.SCHEMA_VERSION:
		return {}
	if not subject._is_integer(value.get("revision")) or int(value.revision) < 0:
		return {}
	if not value.get("runs") is Array or not value.get("rounds") is Array:
		return {}
	var seen_runs: Dictionary = {}
	var seen_rounds: Dictionary = {}
	var runs: Array = []
	var rounds: Array = []
	for raw_row in value.runs:
		var row = subject._normalize_run(raw_row)
		if row.is_empty() or seen_runs.has(row.runID):
			return {}
		seen_runs[row.runID] = true
		runs.append(row)
	for raw_row in value.rounds:
		var row = subject._normalize_round(raw_row)
		if row.is_empty() or not seen_runs.has(row.runID):
			return {}
		var key = str(row.runID) + ":" + str(row.roundID)
		if seen_rounds.has(key):
			return {}
		seen_rounds[key] = true
		rounds.append(row)
	return {"format": subject.FORMAT, "schema_version": subject.SCHEMA_VERSION, "revision": int(value.revision),
		"runs": runs, "rounds": rounds}

static func _normalize_run(subject: Receiver, value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var row: Dictionary = {}
	for key in subject.RUN_INTS:
		if not subject._is_integer(value.get(key)):
			return {}
		row[key] = int(value[key])
	if row.runID < 0 or row["class"] < 0 or row.version < 0 or row.time < 0:
		return {}
	if not (value.get("rank") is int or value.get("rank") is float) or not is_finite(float(value.rank)):
		return {}
	row.rank = float(value.rank)
	if not value.get("custom") is String:
		return {}
	row.custom = value.custom
	for key in subject.SPECIAL_FIELDS:
		var index = value.get(key)
		if index != null and (not subject._is_integer(index) or int(index) < 0):
			return {}
		row[key] = null if index == null else int(index)
	return row

static func _normalize_round(subject: Receiver, value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var row: Dictionary = {}
	for key in subject.ROUND_INTS:
		if not subject._is_integer(value.get(key)):
			return {}
		row[key] = int(value[key])
	if row.runID < 0 or row.roundID <= 0 or row.tries < 0 or row.health < 0 or row.stamina < 0:
		return {}
	if not value.get("buildInfo") is String:
		return {}
	row.buildInfo = value.buildInfo
	return row

static func _write_snapshot(subject: Receiver, snapshot: Dictionary, file_path: String) -> bool:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return subject._fail("Cannot create the history save directory.")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return subject._fail("Cannot open history save: " + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or subject._read_snapshot(file_path).is_empty():
		return subject._fail("History save could not be verified after writing.")
	return true

static func _replace_file(subject: Receiver, source: String, destination: String) -> bool:
	var absolute_source = ProjectSettings.globalize_path(source)
	var absolute_destination = ProjectSettings.globalize_path(destination)
	if FileAccess.file_exists(destination):
		var remove_error = DirAccess.remove_absolute(absolute_destination)
		if remove_error != OK:
			return subject._fail("Cannot replace history save: " + error_string(remove_error))
	var rename_error = DirAccess.rename_absolute(absolute_source, absolute_destination)
	if rename_error != OK:
		return subject._fail("Cannot complete history save: " + error_string(rename_error))
	return true

static func _preserve_corrupt_file(subject: Receiver, file_path: String):
	var suffix = str(int(Time.get_unix_time_from_system() * 1000.0)) + "-" + str(Time.get_ticks_usec())
	var rename_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(file_path),
		ProjectSettings.globalize_path(file_path + ".corrupt." + suffix))
	if rename_error != OK:
		subject.last_error = "Unreadable history could not be moved aside: " + error_string(rename_error)

static func read_runs(subject: Receiver) -> Array:
	var result: Array = []
	var ids = subject._runs.keys()
	ids.sort()
	for run_id in ids:
		result.append(subject._runs[run_id].duplicate(true))
	return result

static func write_run(subject: Receiver, value: Dictionary) -> bool:
	var row = subject._normalize_run(value)
	if row.is_empty():
		return subject._fail("Invalid run history data.")
	var next_runs = subject._runs.duplicate(true)
	next_runs[row.runID] = row
	return subject._commit(next_runs, subject._rounds)

static func _is_integer(subject: Receiver, value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value) and abs(value) < 9007199254740992.0
