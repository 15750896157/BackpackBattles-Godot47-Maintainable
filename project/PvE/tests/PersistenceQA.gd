extends Node

var checks = 0
var failures: Array = []
var stage = "write"
var case_name = "result"
var output = ""
var details = {}

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--persistence-stage="): stage = arg.trim_prefix("--persistence-stage=")
		if arg.begins_with("--persistence-case="): case_name = arg.trim_prefix("--persistence-case=")
	call_deferred("run_tests")

func frames(count = 4):
	for index in count: await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func check(value, label):
	checks += 1
	if not value: failures.append(label); print("PERSISTENCE_FAILURE ", label)
	return value

func stable(data):
	var copy = JSON.parse_string(JSON.stringify(data))
	copy.erase("play_seconds")
	return copy

func title_entry_checks():
	check(not Game.titleScreen.continueNode.is_visible_in_tree(),"standalone continue banner removed")
	Game.titleScreen.rankedButton.pressed.emit()
	await frames()
	var resume=Expedition.panel.find_child("ResumeSavedRun",true,false)
	check(resume!=null and not resume.disabled,"standard entrance offers enabled continue")
	check(Expedition.panel.find_child("NewGameChoice",true,false)!=null,"standard entrance offers explicit new game")
	if resume!=null:check(Expedition.popup_scroll.get_global_rect().encloses(resume.get_global_rect()),"continue card fits on first page")
	return resume

func shot(name):
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func run_tests():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: check(false, "initialization"); finish(); return
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	Game.sceneAnimation.play("StartOnTitle")
	Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	await frames()
	var flow = Expedition.flow
	details.save_directory = ProjectSettings.globalize_path(flow.saves.base_path)
	if stage == "write":
		if not check(flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true).ok, "new adventure saved"): finish(); return
		Expedition.perform({"ok": true})
		await frames()
		if case_name != "route":
			if not check(flow.choose_route(0).ok, "route choice saved"): finish(); return
			Expedition.perform({"ok": true})
			await get_tree().create_timer(5.8).timeout
			await frames()
			flow.skip_tutorial()
			for i in flow.run.shop.slots.size():
				var slot = flow.run.shop.slots[i]
				if not slot.sold and int(slot.price) <= int(flow.run.gold):
					check(flow.buy(i).ok, "purchase saved")
					break
			while not flow.run.pending_rewards.is_empty():
				var resolved = flow.handle_pending(0, "place")
				if not resolved.ok: resolved = flow.handle_pending(0, "sell")
				if not check(resolved.ok, "purchase pending item resolved"): finish(); return
			Expedition.perform({"ok": true})
			await frames()
		if case_name in ["combat", "result", "reward"]:
			flow.run.health = 1000.0
			flow.run.max_health = 1000.0
			check(Expedition.start_battle(), "combat snapshot saved")
			Expedition.set_playback(1.0, true)
			Game.switchToCombat()
			await get_tree().create_timer(5.8).timeout
			await frames()
			if case_name != "combat":
				flow.combat_paused = false
				flow.advance_combat(10000)
				check(flow.screen_state == "COMBAT_RESULT", "battle completed and saved")
				check(int(flow.combat_result.winner_side) == 0, "fixture wins real deterministic combat")
				Expedition.render_state()
				if case_name == "reward": Expedition.advance_result()
				await frames()
		details.before_menu_state = flow.screen_state
		Expedition.show_settings()
		await frames()
		var buttons = Expedition.panel.find_children("*", "Button", true, false)
		var pressed = false
		for button in buttons:
			if button.name in ["SaveAndExit","SaveAndExitBody"]:
				button.pressed.emit()
				pressed = true
				break
		check(pressed, "actual Save and Return button activated")
		await frames(12)
		check(flow.screen_state == "MAIN_MENU", "save button returns to title")
		var saved = flow.saves.load_save("run")
		check(saved.ok, "primary run envelope readable")
		check(flow.saves.validate_run(saved.get("data", {}), Expedition.db).ok, "written run accepted by validator")
		details.saved_state = saved.get("data", {}).get("state", "")
		details.title_continue_visible = Game.titleScreen.continueNode.is_visible_in_tree()
		details.title_continue_disabled = Game.titleScreen.continueButton.disabled
		check(not Game.titleScreen.concedeAnimation.is_playing(), "legacy conceal animation cannot hide Continue later")
		await title_entry_checks()
		await shot("title-after-save")
		var file = FileAccess.open(output.path_join("expected.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"run": stable(saved.data), "profile": stable(flow.profile_service.profile), "combat_digest": flow.combat_result.get("replay_digest", ""), "case": case_name}, "\t"))
		file.close()
	else:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected.json")))
		var saved = flow.saves.load_save("run")
		check(saved.ok, "run remains on disk after process exit")
		check(stable(saved.data) == expected.run, "entire persisted run unchanged across engine restart")
		check(stable(flow.profile_service.profile) == expected.profile, "profile survives engine restart")
		details.title_continue_visible = Game.titleScreen.continueNode.is_visible_in_tree()
		details.title_continue_disabled = Game.titleScreen.continueButton.disabled
		details.load_validation = flow.saves.validate_run(saved.data, Expedition.db)
		var resume=await title_entry_checks()
		await shot("title-after-relaunch")
		if resume==null:finish();return
		resume.pressed.emit()
		await frames(10)
		check(not flow.run.is_empty(), "actual title Continue button restores run")
		if flow.run.is_empty(): finish(); return
		details.restored_state = flow.screen_state
		details.last_error = flow.last_error
		check(flow.screen_state == expected.run.state, "exact adventure phase restored")
		if case_name == "combat":
			Expedition.set_playback(1.0, true)
			check(flow.combat_result.get("replay_digest", "") == expected.combat_digest, "combat replays identical checkpoint and seed")
		var actual = stable(flow.run)
		check(actual == expected.run, "health gold layout inventory RNG rewards and history restored exactly")
		if flow.screen_state in ["COMBAT_RUNNING", "COMBAT_RESULT", "SHOP_PREPARE"]:
			await get_tree().create_timer(5.8).timeout
			await frames()
		check(is_instance_valid(Game.PLAYER), "restored native character present")
		if case_name == "result":
			check(Expedition.current_page == "COMBAT_RESULT", "battle result UI restored after relaunch")
		if case_name == "reward": check(Expedition.current_page == "REWARD_SELECT", "pending reward UI restored after relaunch")
		await shot("restored-adventure")
	finish()

func finish():
	DirAccess.make_dir_recursive_absolute(output)
	var file = FileAccess.open(output.path_join("persistence-" + stage + "-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty(), "case": case_name, "stage": stage, "details": details}, "\t"))
	file.close()
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
