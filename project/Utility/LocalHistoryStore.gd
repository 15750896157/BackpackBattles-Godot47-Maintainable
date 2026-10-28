extends RefCounted

# Native Godot 4 persistence; serialized inventory strings stay opaque.
const FORMAT = "backpack-battles-history"
const SCHEMA_VERSION = 1
const MAX_FILE_BYTES = 128 * 1024 * 1024
const RUN_INTS = ["runID", "class", "loadout", "version", "time"]
const ROUND_INTS = ["runID", "roundID", "result", "tries", "health", "stamina"]
const SPECIAL_FIELDS = ["subclass", "skill1", "skill2"]
var path: String
var last_error: String = ""
var recovery_message: String = ""
var _runs: Dictionary = {}
var _rounds: Dictionary = {}
var _revision: int = 0

func _init(storage_path: String = "user://local_history.json"):
	path = storage_path
	open()

func open() -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").open(self)

func verify() -> bool:
	return not _normalize_snapshot(_snapshot(_runs, _rounds, _revision)).is_empty()

func reset() -> bool:
	return _commit({}, {})

func read_runs() -> Array:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").read_runs(self)

func read_rounds() -> Array:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").read_rounds(self)

func write_run(value: Dictionary) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").write_run(self, value)

func update_run(run_id: int, fields: Dictionary) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").update_run(self, run_id, fields)

func write_round(value: Dictionary) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").write_round(self, value)

func prune(max_runs: int, minimum_run_id: int = 0) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd").prune(self, max_runs, minimum_run_id)

func _commit(runs: Dictionary, rounds: Dictionary) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._commit(self, runs, rounds)

func _snapshot(runs: Dictionary, rounds: Dictionary, revision: int) -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._snapshot(self, runs, rounds, revision)

func _apply_snapshot(snapshot: Dictionary):
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._apply_snapshot(self, snapshot)

func _read_snapshot(file_path: String) -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._read_snapshot(self, file_path)

func _normalize_snapshot(value: Variant) -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._normalize_snapshot(self, value)

func _normalize_run(value: Variant) -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._normalize_run(self, value)

func _normalize_round(value: Variant) -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._normalize_round(self, value)

func _is_integer(value: Variant) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._is_integer(self, value)

func _write_snapshot(snapshot: Dictionary, file_path: String) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._write_snapshot(self, snapshot, file_path)

func _replace_file(source: String, destination: String) -> bool:
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._replace_file(self, source, destination)

func _preserve_corrupt_file(file_path: String):
	return load("res://Runtime/Behavior/Utility/LocalHistoryStoreBehavior.gd")._preserve_corrupt_file(self, file_path)

func _fail(message: String) -> bool:
	last_error = message
	return false
