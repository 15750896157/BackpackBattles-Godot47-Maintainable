extends SceneTree

func _init(): call_deferred("run")

func run():
	var options: Dictionary = {}
	var arguments = OS.get_cmdline_user_args()
	for index in arguments.size():
		if str(arguments[index]).begins_with("--") and index + 1 < arguments.size(): options[str(arguments[index]).trim_prefix("--")] = arguments[index + 1]
	var db = ContentDB.new()
	var tools = PvEDeveloperToolService.new(db)
	var player = tools.loadout_snapshot(str(options.get("loadout", "armorer_blades")))
	if not player.get("ok", false): player = tools.loadout_snapshot(str(db.rows("character_loadouts")[0].id))
	var enemy = tools.opponent_snapshot(str(options.get("enemy-id", "rust_scout_a")), str(options.get("difficulty", "standard")))
	for side in ["player-file", "enemy-file"]:
		if not options.has(side): continue
		var file_path = str(options[side])
		if not FileAccess.file_exists(file_path): _fail("snapshot_file_missing", file_path); return
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		var validation = tools.validate_import(parsed)
		if not validation.ok: _fail(str(validation.error), file_path); return
		if side == "player-file": player = validation.snapshot
		else: enemy = validation.snapshot
	var result = tools.batch(player, enemy, int(options.get("seed", 1)), int(options.get("count", 20)))
	if not result.ok: _fail(str(result.error), ""); return
	if options.has("output"):
		var file = FileAccess.open(str(options.output), FileAccess.WRITE)
		if file == null: _fail("report_write_failed", str(options.output)); return
		file.store_string(JSON.stringify(result, "\t", true, true) + "\n"); file.close()
	print("PVE_BATCH ", JSON.stringify(result))
	quit(0)

func _fail(code: String, detail: String):
	printerr(JSON.stringify({"ok": false, "error": code, "detail": detail})); quit(1)
