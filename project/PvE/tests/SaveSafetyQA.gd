extends Node

var checks = 0
var failures: Array = []
var output = ""

class ArchiveBlocked extends SaveService:
	func archive_current_run() -> bool:
		last_error = "archive_write_failed"
		return false

func check(value, label):
	checks += 1
	if not value: failures.append(label); print("SAVE_SAFETY_FAILURE ", label)
	return value

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func stable(data):
	return JSON.parse_string(JSON.stringify(data))

func run_tests():
	while not Expedition.initialized: await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	Game.sceneAnimation.play("StartOnTitle")
	Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	var flow = Expedition.flow
	check(flow.new_run("armorer", "armorer_blades", "tutorial", 54321, true).ok, "initial run saved")
	var initial = flow.saves.load_save("run")
	var original = stable(initial.data)
	var path = flow.saves._path("run")
	var disk_hash = FileAccess.get_sha256(path)
	var live_before = stable(flow.run)
	var guarded = flow.new_run("alchemist", "alchemist_poison", "tutorial", 9, false)
	check(not guarded.ok and guarded.error == "confirm_overwrite_run", "new run requires explicit confirmation")
	check(FileAccess.get_sha256(path) == disk_hash and stable(flow.run) == live_before, "declined replacement preserves disk and live run")
	Expedition.begin_setup(Game.Mode.Ranked)
	var buttons = Expedition.popup_content.find_children("*", "Button", true, false)
	check(Expedition.panel.find_child("ResumeSavedRun",true,false)!=null, "standard battle setup offers saved expedition")
	check(FileAccess.get_sha256(path) == disk_hash, "opening standard battle setup never replaces progress")
	Expedition.create_run("armorer", "armorer_blades", "tutorial", 24680, false)
	buttons = Expedition.popup_content.find_children("*", "Button", true, false)
	check(Expedition.panel.find_child("ResumeSavedRun",true,false)!=null and Expedition.panel.find_child("ArchiveConsent",true,false)==null, "saved choice retains continue without extra archive checkbox")
	check(FileAccess.get_sha256(path) == disk_hash, "confirmation prompt keeps original save")
	var protected = GameFlow.new(Expedition.db, ArchiveBlocked.new(flow.saves.base_path))
	var refused = protected.new_run("armorer", "armorer_blades", "tutorial", 24680, true)
	check(not refused.ok and refused.error == "save_write_failed", "archive failure rejects replacement")
	check(FileAccess.get_sha256(path) == disk_hash, "failed archival cannot overwrite previous adventure")
	Expedition.panel.find_child("NewGameChoice",true,false).pressed.emit()
	check(FileAccess.get_sha256(path)==disk_hash,"new run draft preserves current save")
	buttons=Expedition.popup_content.find_children("*","Button",true,false)
	var confirmed = false
	for button in buttons:
		if button.name == "BeginExpedition":
			button.pressed.emit()
			confirmed = true
			break
	check(confirmed, "explicit Begin new run button operates")
	for index in 8: await get_tree().process_frame
	check(int(flow.run.run_seed) == 24680 and str(flow.run.run_id) != str(original.run_id), "confirmed replacement creates selected new adventure")
	check(not flow.saves.last_run_archive.is_empty(), "previous adventure has a separate archive")
	var archived = flow.saves._read(flow.saves.last_run_archive.path_join("run.save"))
	check(archived.ok and stable(archived.data) == original, "archive retains complete previous run")
	var recovery = SaveService.new(flow.saves.base_path.path_join("recovery_fixture"))
	check(recovery.save("run", original), "recovery fixture first atomic save")
	check(recovery.save("run", original), "recovery fixture good rolling backup")
	var broken = FileAccess.open(recovery._path("run"), FileAccess.WRITE)
	broken.store_string("interrupted-write")
	broken.close()
	var recovered = recovery.load_save("run")
	check(recovered.ok and recovered.recovered and stable(recovered.data) == original, "damaged primary recovers verified backup")
	check(not recovery.notices.is_empty(), "backup recovery produces player notice")
	finish()

func finish():
	DirAccess.make_dir_recursive_absolute(output)
	var file = FileAccess.open(output.path_join("save-safety-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}, "\t"))
	file.close()
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
