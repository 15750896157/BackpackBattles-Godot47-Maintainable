class_name TelemetryService
extends RefCounted

var db
var path: String
var enabled: bool = true
var development: bool = false

func _init(content = null, directory: String = "user://", allow_development: bool = false):
	db = content
	path = directory.trim_suffix("/") + "/telemetry.jsonl"
	development = allow_development

func record(metric: String, payload: Dictionary):
	if not enabled: return
	var definition = db.get_row("telemetry_metrics", metric)
	if definition.is_empty() or (not bool(definition.enabled_in_release) and not development): return
	# Local files only: no identifiers, account information or network endpoint.
	var line = JSON.stringify({"metric": metric, "time": Time.get_unix_time_from_system(), "data": payload}, "", true) + "\n"
	var handle = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if handle == null: return
	if handle.get_length() > 8388608:
		handle.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path.trim_suffix(".jsonl") + "_previous.jsonl"))
		handle = FileAccess.open(path, FileAccess.WRITE_READ)
		if handle == null: return
	handle.seek_end()
	handle.store_string(line)
	handle.close()
