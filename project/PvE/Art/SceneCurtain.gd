extends CanvasLayer
## One presentation barrier for title/shop/combat. Saves and RNG never wait here.
var busy = false
var covered = false
var revealing = false
var generation = 0
var overlay: TextureRect
var veil: ColorRect
var animation: Tween
var faded: Array = []
var history: Array = []

func _ready():
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	veil = ColorRect.new(); veil.color = Color(0.09, 0.065, 0.045, 0); veil.size = Vector2(1920,1080)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(veil); veil.hide()
	overlay = TextureRect.new(); overlay.texture = load("res://Art/Polish20261022/cloud.png")
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.size = Vector2(1920,1080); overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader = ShaderMaterial.new(); shader.shader = preload("res://PvE/Art/CloudWipe.gdshader"); overlay.material = shader
	add_child(overlay); overlay.hide()

func reduce_motion() -> bool:
	return Expedition.preferences != null and bool(Expedition.preferences.values.get("reduce_motion", false))

func _fade_targets() -> Array:
	var result: Array = []
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if not is_instance_valid(actor): continue
		for portrait in actor.find_children("Body", "Sprite2D", true, false): result.append(portrait)
		if actor.INVENTORY != null:
			for item in actor.INVENTORY.getItems():
				if is_instance_valid(item): result.append(item)
	if Game.state == Game.State.Shop:
		for slot in Game.shopSceneNode.slots:
			if is_instance_valid(slot.item): result.append(slot.item)
	return result

func cover(reason: String = "scene") -> int:
	if busy:
		while busy and not covered and not AssetStream.stopping: await get_tree().process_frame
		if covered: return generation
		return await cover(reason)
	generation += 1; busy = true; covered = false
	if is_instance_valid(Expedition.transitions.closing_ghost):
		Expedition.transitions.closing_ghost.queue_free()
		Expedition.transitions.closing_ghost = null
	InputBlocker.activate(InputBlocker.Source.Cinematic,false)
	overlay.show(); veil.show(); overlay.material.set_shader_parameter("uncover", false)
	overlay.material.set_shader_parameter("reduced_motion", reduce_motion())
	overlay.material.set_shader_parameter("reduced_flash", bool(Expedition.preferences.values.get("reduce_flash",false)))
	overlay.material.set_shader_parameter("coverage", 0.0)
	var duration = 0.13 if reduce_motion() else 0.40
	faded.clear()
	for node in _fade_targets():
		faded.append([weakref(node), node.modulate])
	await _advance(duration, false)
	covered = true; history.append({"phase":"covered","reason":reason,"time_ms":Time.get_ticks_msec()})
	return generation

func reveal(ticket: int):
	if ticket != generation or not busy or revealing: return
	revealing = true
	covered = false
	# Restore departing nodes too: a player object can survive into the next scene.
	for record in faded:
		var node = record[0].get_ref()
		if is_instance_valid(node): node.modulate = record[1]
	faded.clear()
	var duration = 0.16 if reduce_motion() else 0.52
	faded.clear()
	for node in _fade_targets():
		faded.append([weakref(node),Color.WHITE])
		node.modulate.a = 0.0
	overlay.material.set_shader_parameter("uncover", true)
	overlay.material.set_shader_parameter("coverage", 0.0)
	await _advance(duration, true)
	if ticket != generation: return
	overlay.hide(); veil.hide(); busy = false; covered = false; revealing = false
	InputBlocker.deactivate(InputBlocker.Source.Cinematic,false)
	history.append({"phase":"revealed","time_ms":Time.get_ticks_msec()})
	faded.clear()

func _advance(duration: float, entering: bool):
	var elapsed = 0.0
	var previous = Time.get_ticks_usec()
	while elapsed < duration and not AssetStream.stopping:
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		# A slow loading frame must not skip the visible transition itself.
		elapsed += clampf(float(now-previous)/1000000.0,0.001,1.0/40.0)
		previous = now
		var value = clampf(elapsed/duration,0.0,1.0)
		overlay.material.set_shader_parameter("coverage",value)
		veil.color.a = (1.0-value)*0.25 if entering else value*0.25
		for record in faded:
			var node = record[0].get_ref()
			if is_instance_valid(node): node.modulate.a = value if entering else 1.0-value

func _exit_tree():
	if is_instance_valid(InputBlocker): InputBlocker.deactivate(InputBlocker.Source.Cinematic,false)
	if animation != null and animation.is_valid(): animation.kill()
