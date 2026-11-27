extends Node
## 选路页与图鉴互转的回归场景：点击图鉴/从图鉴返回时，被替换的全屏画布
## 会暂存为遮罩下的过渡背景，主菜单载体不得在弹窗空窗期露出来。

var checks: int = 0
var failures: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_tests")

func frames(count: int = 3):
	for index in range(count): await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func check(value: bool, text: String):
	checks += 1
	if not value:
		failures.append(text)
		print("FAIL: ", text)
	else:
		print("PASS: ", text)

func dump_state(tag: String):
	var shell = Expedition.menus.shell
	var canvas = shell.canvas
	var canvas_children := "invalid"
	if is_instance_valid(canvas):
		var names := []
		for child in canvas.get_children(): names.append(child.name)
		canvas_children = str(names)
	var stats: Dictionary = AssetStream.stats()
	print("%s: panel.visible=%s current_page=%s epoch=%d route_pending_mount=%s canvas=%s under=%s failures=%s scopes=%s" % [
		tag, Expedition.panel.visible, Expedition.current_page, Expedition.popup_epoch,
		Expedition.route_mount_pending, canvas_children,
		str(shell.canvas_under) if is_instance_valid(shell.canvas_under) else "none",
		stats.failures, stats.scopes])

func wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()

func route_screen_in_tree() -> bool:
	var shell = Expedition.menus.shell
	if not is_instance_valid(shell.canvas): return false
	return shell.canvas.find_children("*", "Control", true, false).any(func(c): return c.get_script() == load("res://PvE/UI/RouteScreen.gd"))

func canvas_content_ms() -> int:
	# Duration (ms) where the panel is visible but the canvas is still empty,
	# i.e. the main-menu carrier shows through the popup.
	var shell = Expedition.menus.shell
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 15000:
		if is_instance_valid(shell.canvas) and shell.canvas.get_child_count() > 0:
			return Time.get_ticks_msec() - start
		await get_tree().process_frame
	return -1

func click_codex_button():
	var shell = Expedition.menus.shell
	var screen = shell.canvas.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == load("res://PvE/UI/RouteScreen.gd"))[0]
	screen.get_node("JourneyCodex").pressed.emit()

func run_tests():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: check(false, "init timeout"); finish(); return
		await get_tree().process_frame
	await get_tree().create_timer(1.0, true, false, true).timeout
	Settings.setVal(Settings.Setting.language, "zh_Hans_CN")
	Game.sceneAnimation.play("StartOnTitle")
	Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	await frames()
	Expedition.begin_setup(Game.Mode.Unranked)
	await frames()
	Expedition.perform(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true))
	await frames()
	check(Expedition.flow.screen_state == "ROUTE_SELECT", "route state reached")
	check(await wait_for(route_screen_in_tree, 10.0), "route screen mounted over title")
	dump_state("A-route-mounted")

	# 1) real click on the route screen codex button
	click_codex_button()
	var shell = Expedition.menus.shell
	check(is_instance_valid(shell.canvas_under) and shell.canvas_under.visible,
		"stashed route canvas shows beneath codex while it streams in")
	var open_gap := await canvas_content_ms()
	print("OPEN_EMPTY_MS=", open_gap)
	check(open_gap >= 0 and open_gap < 400, "codex canvas draws content quickly (empty gap %d ms)" % open_gap)
	check(Expedition.current_page in ["CODEX", "CRAFTING"], "codex page open")
	check(is_instance_valid(shell.canvas_under), "route canvas kept for the return transition")
	dump_state("B-codex-from-route")

	# 2) return from codex
	Expedition.view_return()
	await frames()
	var route_ready := await wait_for(func(): return Expedition.panel.visible and route_screen_in_tree(), 10.0)
	check(route_ready, "route screen remounts after codex closes")
	check(await wait_for(func(): return Expedition.menus.shell.canvas_under == null, 5.0),
		"stashed route canvas is retired once the fresh route page draws")
	dump_state("C-route-remounted")

	# 3) open codex again, then close via close button path again
	Expedition.show_codex()
	await frames()
	check(await wait_for(func(): return Expedition.current_page in ["CODEX", "CRAFTING"] and is_instance_valid(Expedition.menus.shell.canvas) and Expedition.menus.shell.canvas.get_child_count() > 0, 5.0),
		"second codex open draws content")
	dump_state("C2-second-codex")
	Expedition.view_return()
	await frames()
	check(await wait_for(func(): return Expedition.panel.visible and route_screen_in_tree(), 10.0),
		"route screen remounts again")
	# 4) picking a route must clean the stashed canvas up
	Expedition.perform(Expedition.flow.choose_route(0))
	await get_tree().create_timer(5.5, true, false, true).timeout
	await frames()
	check(Game.state == Game.State.Shop, "shop entered after choosing a route")
	check(Expedition.menus.shell.canvas_under == null or not is_instance_valid(Expedition.menus.shell.canvas_under),
		"stashed route canvas freed after leaving route select")
	dump_state("D-final")
	finish()

func finish():
	print("CODEX_ROUTE_QA checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: print("FAILURE: ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
