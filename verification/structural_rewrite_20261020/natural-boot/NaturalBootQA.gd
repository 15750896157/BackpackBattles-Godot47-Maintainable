extends Node

var output = ""
var checks = 0
var failures = []
var observations = {}

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func check(condition, label):
	checks += 1
	if not condition: failures.append(label)

func visible_parts(actor):
	var count = 0
	var bounds = Rect2()
	if not is_instance_valid(actor): return {"on_screen": false}
	for node in actor.sprite.find_children("*", "Sprite2D", true, false):
		if not node.is_visible_in_tree() or node.texture == null: continue
		var alpha = node.self_modulate.a
		var ancestor = node
		while ancestor is CanvasItem:
			alpha *= ancestor.modulate.a
			ancestor = ancestor.get_parent()
		if alpha < 0.01: continue
		var rectangle = node.get_global_transform_with_canvas() * node.get_rect()
		if rectangle.size.x < 0.5 or rectangle.size.y < 0.5: continue
		bounds = rectangle if count == 0 else bounds.merge(rectangle)
		count += 1
	return {"count": count, "bounds": str(bounds), "on_screen": count > 0 and bounds.intersects(Rect2(0, 0, 1920, 1080))}

func run_tests():
	var deadline = Time.get_ticks_msec() + 90000
	while not Expedition.initialized and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(Expedition.initialized, "content initialized")
	while not Game.sceneAnimation.is_connected("animation_finished", Callable(Game, "onSceneAnimationFinished")) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(Game.sceneAnimation.is_connected("animation_finished", Callable(Game, "onSceneAnimationFinished")), "native coordinator ready without forcing animation")
	await get_tree().create_timer(1.0).timeout
	while (Game.sceneAnimation.is_playing() or Game.playerNodeAnimation.is_playing()) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	check(Game.state == Game.State.Title, "ordinary startup reaches title")
	check(not Game.sceneAnimation.is_playing() and not Game.playerNodeAnimation.is_playing(), "both startup animations complete naturally")
	observations.title_player = visible_parts(Game.PLAYER)
	check(observations.title_player.on_screen, "native character visible after natural startup")
	var title = Game.titleScreen
	check(title.continueNode.is_visible_in_tree() and not title.continueButton.disabled, "continue available after natural startup")
	check(not title.continueButton.get_global_rect().intersects(title.rankedButton.get_global_rect()), "continue separate from standard battle")
	check(not title.continueButton.get_global_rect().intersects(title.unrankedButton.get_global_rect()), "continue separate from tutorial battle")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("natural-title.png"))
	var expected = Expedition.flow.saves.load_save("run")
	check(expected.ok, "existing QA adventure remains readable")
	title.continueButton.pressed.emit()
	await get_tree().create_timer(6.5).timeout
	check(Expedition.flow.screen_state == expected.data.state, "continue restores existing adventure phase")
	observations.restored_player = visible_parts(Game.PLAYER)
	check(observations.restored_player.on_screen, "native character visible after continue")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("natural-continue.png"))
	var file = FileAccess.open(output.path_join("natural-boot-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "observations": observations}, "\t"))
	file.close()
	Game._begin_shutdown()
	get_tree().quit(0 if failures.is_empty() else 1)
