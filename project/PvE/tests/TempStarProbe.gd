extends Node

var output = "user://temp-star-probe.json"
var report: Dictionary = {"picked": "", "sprites": []}

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run")

func frames(count: int = 4):
	for index in count: await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func run():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: _dump(); return
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	Game.sceneAnimation.play("StartOnTitle"); Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true)
	Expedition.flow.skip_tutorial()
	await frames()
	var route := -1
	for index in Expedition.flow.run.route_candidates.size():
		if str(Expedition.flow.run.route_candidates[index].type).ends_with("combat"): route = index; break
	if route < 0: route = 0
	Expedition.flow.choose_route(route)
	await get_tree().create_timer(3.0).timeout
	await frames()
	var target = null
	for node in get_tree().root.find_children("*", "*", true, false):
		var script = node.get_script()
		if script != null and str(script.resource_path).ends_with("/Gem.gd"):
			target = node; break
	if target == null:
		for item in Game.PLAYER.INVENTORY.items:
			if not item.isBag(): target = item; break
	if target != null:
		report.picked = str(target.name)
		target.pickup()
	await frames(3)
	_scan(get_tree().root, "")
	_dump()

func _scan(node, path: String):
	var tex: Texture2D = null
	if node is Sprite2D: tex = node.texture
	elif node is TextureRect: tex = node.texture
	elif node is NinePatchRect: tex = node.texture
	elif node is TextureButton: tex = node.texture_normal
	if tex != null and node.is_visible_in_tree():
		var tex_path := str(tex.resource_path)
		if not tex_path.is_empty():
			report.sprites.append({
				"path": path + "/" + str(node.name), "tex": tex_path,
				"size": [tex.get_width(), tex.get_height()],
			})
	for child in node.get_children(): _scan(child, path + "/" + str(node.name))

func _dump():
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("TEMPSTAR picked=", report.picked, " sprites=", report.sprites.size(), " out=", output)
	get_tree().quit()
