extends Node

var output = ""
var checks = 0
var failures: Array = []
var evidence: Dictionary = {}
var feedback = {"hit": 0, "activation": 0}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func frames(count = 4):
	for index in range(count): await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func wait_for(predicate: Callable, seconds = 10.0):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return predicate.call()

func check(condition, message):
	checks += 1
	if not condition: failures.append(message)

func snapshot(name: String):
	await frames(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func reset_actors():
	for actor in [Game.PLAYER, Game.OPPONENT]:
		Util.killTween(actor.attackTween)
		actor.attackMovingForward = false
		actor.spriteNode.position = actor.combatDefaultPos
		actor.damageAnimation.play("RESET")
		actor.damageAnimation.advance(0)
		actor.damageAnimation.stop()

func damage_number_count() -> int:
	return Game.UINode.get_children().filter(func(node): return node is NumberLabel).size()

func play_batch(index: int):
	Expedition.last_event = index
	Expedition.flow.playback_time = float(Expedition.flow.combat_result.full_events[index].time)
	Expedition._play_events()

func start_combat(reduced: bool) -> bool:
	Expedition.set_process(true)
	await Expedition.return_to_title()
	await frames(5)
	Game.titleScreen.selectClass(Game.Classes_Full.Reaper)
	for key in ["reduce_flash", "reduce_motion", "reduce_effects"]: Expedition.preferences.values[key] = reduced
	check(Expedition.flow.new_run("alchemist", "alchemist_toxin", "tutorial", 71015, true).ok, "same-seed actual run starts, reduced=" + str(reduced))
	await frames()
	check(Expedition.flow.choose_route(0).ok, "same-seed actual route starts, reduced=" + str(reduced))
	check(await wait_for(func(): return Game.state == Game.State.Shop and not Game.sceneAnimation.is_playing()), "native shop entry finishes")
	Expedition.flow.skip_tutorial()
	await frames()
	Game.startCombatButton.activateButton()
	var ready = await wait_for(func(): return Game.state == Game.State.Combat and Expedition.native_battle_ready and not Game.sceneAnimation.is_playing())
	check(ready, "original start button enters native combat, reduced=" + str(reduced))
	Expedition.set_process(false)
	return ready

func test_feedback():
	var result = Expedition.flow.combat_result
	var original_serialized = JSON.stringify(result, "", true)
	var original_rng = JSON.stringify(Expedition.flow.run.rng, "", true)
	var events: Array = result.full_events
	var damage_index = -1
	var activation_index = -1
	var weapon
	for index in events.size():
		var event = events[index]
		if damage_index < 0 and event.type in ["PHYSICAL_DAMAGE", "TRUE_DAMAGE", "STATUS_DAMAGE"]: damage_index = index
		if activation_index < 0 and event.type == "ITEM_ACTIVATED":
			var actor = Game.PLAYER if int(event.source_side) == 0 else Game.OPPONENT
			for candidate in actor.INVENTORY.getItems():
				if candidate.isWeapon() and str(candidate.get_meta("pve_uid", "")) == str(event.get("source_uid", event.get("source", ""))):
					activation_index = index
					weapon = candidate
	check(damage_index >= 0 and activation_index >= 0, "real deterministic combat contains damage and rendered weapon activation events")
	if damage_index < 0 or activation_index < 0: return
	for actor in [Game.PLAYER, Game.OPPONENT]:
		actor.damageAnimation.animation_started.connect(func(name):
			if name == &"Hit": feedback.hit += 1)
	var damage_target = Game.PLAYER if int(events[damage_index].target_side) == 0 else Game.OPPONENT
	check(damage_target.damageAnimation.has_animation("Hit") and not damage_target.damageAnimation.has_animation("Damaged"), "original damage animation is named Hit")
	reset_actors()
	Expedition.preferences.values.reduce_flash = false
	Expedition.preferences.values.reduce_effects = false
	var hit_before = feedback.hit
	var number_before = damage_number_count()
	play_batch(damage_index)
	check(feedback.hit > hit_before and damage_target.damageAnimation.current_animation == "Hit", "default real damage event starts original Hit animation")
	check(damage_number_count() > number_before, "default real damage event creates original floating damage text")
	await snapshot("01-default-original-hit")
	reset_actors()
	Expedition.preferences.values.reduce_flash = true
	hit_before = feedback.hit
	play_batch(damage_index)
	check(feedback.hit == hit_before and damage_target.damageAnimation.current_animation != "Hit", "reduce-flash suppresses original Hit animation")
	Expedition.preferences.values.reduce_effects = true
	number_before = damage_number_count()
	play_batch(damage_index)
	check(damage_number_count() == number_before, "reduce-effects suppresses floating damage text")
	reset_actors()
	weapon.animation.stop()
	Expedition.preferences.values.reduce_effects = false
	Expedition.preferences.values.reduce_motion = false
	var activation_actor = Game.PLAYER if int(events[activation_index].source_side) == 0 else Game.OPPONENT
	var activation_before = weapon.shadowTween
	play_batch(activation_index)
	check(activation_actor.attackMovingForward, "default weapon activation starts native actor attack movement")
	check(weapon.shadowTween!=activation_before and weapon.shadowTween!=null and weapon.shadowTween.is_valid(), "default weapon activation starts footprint-relative item motion")
	reset_actors()
	weapon.animation.stop()
	Expedition.preferences.values.reduce_effects = true
	Expedition.preferences.values.reduce_motion = true
	activation_before = weapon.shadowTween
	play_batch(activation_index)
	check(not activation_actor.attackMovingForward, "reduce-motion suppresses native actor attack movement")
	check(weapon.shadowTween==activation_before, "reduce-effects suppresses footprint-relative item activation")
	check(JSON.stringify(result, "", true) == original_serialized, "feedback toggles do not mutate complete precomputed battle result")
	check(JSON.stringify(Expedition.flow.run.rng, "", true) == original_rng, "feedback toggles do not consume authoritative run RNG")
	evidence.hit_animation_started = feedback.hit
	evidence.original_activation_started = feedback.activation
	evidence.damage_event = events[damage_index]
	evidence.weapon_event = events[activation_index]
	await snapshot("02-reduced-original-feedback")

func test_status_timing():
	var samples: Array = []
	for frame in Expedition.flow.combat_result.timeline:
		for side in range(2):
			var state = frame.sides[side].statuses.get("poison", {})
			if int(state.get("stacks", 0)) > 0 and float(state.get("next_tick", 0)) > 0:
				samples.append({"frame": frame, "side": side, "status": state})
	check(not samples.is_empty(), "real timeline contains a ticking poison status")
	if samples.is_empty(): return
	var first = samples[0]
	var next = {}
	for candidate in samples:
		if int(candidate.side) == int(first.side) and float(candidate.frame.time) > float(first.frame.time) and not is_equal_approx(float(candidate.status.next_tick), float(first.status.next_tick)):
			next = candidate
			break
	Expedition.flow.playback_time = float(first.frame.time)
	Expedition._apply_timeline()
	await frames(3)
	var actor = Game.PLAYER if int(first.side) == 0 else Game.OPPONENT
	var hud = actor.buffs[Game.EventType.Poison].counter
	check(hud.pve_timeline_status == first.status, "native status HUD receives exact original timeline fields")
	TranslationServer.set_locale("zh_Hans_CN")
	hud.onHover()
	check(("距下次跳动：%.2f 秒" % float(first.status.next_tick)) in hud.tooltip.descrLabel.text, "Chinese hover shows authoritative next-tick seconds")
	check(("当前层数：%d / %d" % [int(first.status.stacks), int(first.status.cap)]) in hud.tooltip.descrLabel.text, "Chinese hover shows current authoritative stacks and cap")
	await snapshot("03-chinese-real-status-next-tick")
	TranslationServer.set_locale("en")
	hud.onHover()
	check(("Next tick in: %.2f seconds" % float(first.status.next_tick)) in hud.tooltip.descrLabel.text, "English hover shows authoritative next-tick seconds")
	var paused_text = hud.tooltip.descrLabel.text
	await frames(5)
	check(hud.tooltip.descrLabel.text == paused_text, "display timing does not invent a second clock while playback is stationary")
	if not next.is_empty():
		Expedition.flow.playback_time = float(next.frame.time)
		Expedition._apply_timeline()
		check(("Next tick in: %.2f seconds" % float(next.status.next_tick)) in hud.tooltip.descrLabel.text, "already-open tooltip updates to next authoritative timeline frame")
	evidence.status_first = first
	evidence.status_next = next
	await snapshot("04-english-updated-real-status-next-tick")
	hud.onHoverEnd()
	TranslationServer.set_locale("zh_Hans_CN")

func settle(reduced: bool) -> Dictionary:
	for key in ["reduce_flash", "reduce_motion", "reduce_effects"]: Expedition.preferences.values[key] = reduced
	Expedition.flow.advance_combat(10000)
	await frames(5)
	check(Expedition.flow.screen_state == "COMBAT_RESULT", "real settlement reaches result, reduced=" + str(reduced))
	var result = Expedition.flow.combat_result
	return {"digest": result.replay_digest, "winner": int(result.winner_side), "elapsed": float(result.elapsed_time), "persistent_health": float(Expedition.flow.run.health), "gold": int(Expedition.flow.run.gold), "item_stats": result.item_stats_by_instance_id.duplicate(true), "logs": Expedition.flow.run.logs.size(), "rng": Expedition.flow.run.rng.duplicate(true)}

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	check(await wait_for(func(): return Expedition.initialized, 90), "real original Main initializes")
	var defaults = Expedition.preferences.values.duplicate(true)
	if await start_combat(false):
		await test_feedback()
		await test_status_timing()
		var default_result = await settle(false)
		var old_hud = Game.PLAYER.buffs[Game.EventType.Poison].counter
		Expedition.return_to_title()
		await frames()
		check(old_hud.pve_timeline_status.is_empty(), "leaving native combat clears previous timeline tooltip state")
		if await start_combat(true):
			var reduced_result = await settle(true)
			check(default_result == reduced_result, "same-seed settlement summary is identical with all three feedback reductions")
			evidence.default_settlement = default_result
			evidence.reduced_settlement = reduced_result
			await snapshot("05-identical-reduced-settlement")
	Expedition.return_to_title()
	Expedition.preferences.values = defaults
	Expedition.preferences.apply()
	Expedition.preferences.save()
	var file = FileAccess.open(output.path_join("feedback-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "entry": "res://Core/Main.tscn", "engine": Engine.get_version_info().string, "evidence": evidence}, "  ")); file.close()
	print("NATIVE_FEEDBACK_QA " + JSON.stringify({"checks": checks, "failures": failures}))
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
