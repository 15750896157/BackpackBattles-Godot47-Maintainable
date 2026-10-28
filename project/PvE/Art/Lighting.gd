extends Node2D
## Two lights maximum, shared surface shader, one cheap screen pass.
var key_light: PointLight2D
var fill_light: PointLight2D
var grade_layer: CanvasLayer
var grade: ColorRect
var surface: ShaderMaterial
var ambient: CanvasModulate
var signature = ""
var refresh_clock = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = ShaderMaterial.new(); surface.shader = preload("res://PvE/Art/SurfaceLight.gdshader")
	ambient = CanvasModulate.new(); add_child(ambient)
	var ramp = Gradient.new(); ramp.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0)])
	var lamp = GradientTexture2D.new(); lamp.gradient = ramp; lamp.width = 128; lamp.height = 128
	lamp.fill = GradientTexture2D.FILL_RADIAL; lamp.fill_from = Vector2(0.5,0.5); lamp.fill_to = Vector2(1,0.5)
	for index in 2:
		var light = PointLight2D.new(); light.texture = lamp; light.texture_scale = 16.0
		light.energy = 0.24; light.color = Color("ffe4b5"); light.range_item_cull_mask = 1
		light.shadow_enabled = index == 0; light.shadow_color = Color(0.08,0.06,0.05,0.25)
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		add_child(light)
		if index == 0: key_light = light
		else: fill_light = light
	grade_layer = CanvasLayer.new(); grade_layer.layer = 90; add_child(grade_layer)
	grade = ColorRect.new(); grade.size = Vector2(1920,1080); grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = ShaderMaterial.new(); shader.shader = preload("res://PvE/Art/Atmosphere.gdshader"); grade.material = shader
	grade_layer.add_child(grade)

func _process(delta):
	if not Expedition.initialized: return
	var enabled = Game.state in [Game.State.Shop, Game.State.Combat]
	var reduced = bool(Expedition.preferences.values.get("reduce_effects", false))
	grade.visible = enabled and not bool(Expedition.preferences.values.get("high_contrast", false))
	ambient.color = Color(0.92,0.92,0.92) if enabled and not reduced else Color.WHITE
	key_light.enabled = enabled and not reduced; fill_light.enabled = enabled and not reduced and Game.state == Game.State.Combat and int(Expedition.flow.run.get("act",1)) == 3
	var key = str(Game.state)+":"+str(Expedition.flow.run.get("act",1))
	if key != signature:
		signature = key
		var act = int(Expedition.flow.run.get("act",1))
		var position_hint = Vector2(960,100) if act == 1 else Vector2(1050,70) if act == 2 else Vector2(995,200)
		if Game.state == Game.State.Shop: position_hint = Vector2(760,270)
		key_light.position = position_hint; fill_light.position = Vector2(620,560)
		fill_light.color = Color("ff9b43"); fill_light.energy = 0.12
		var tint = Color("ffe5bd") if act != 1 or Game.state == Game.State.Shop else Color("dcebe0")
		key_light.color = tint
		grade.material.set_shader_parameter("source_position", position_hint / Vector2(1920,1080))
		grade.material.set_shader_parameter("warmth", tint)
		grade.material.set_shader_parameter("darkness", 0.10 if Game.state == Game.State.Shop else 0.13)
		grade.material.set_shader_parameter("glow", 0.045 if Game.state == Game.State.Shop else 0.06)
		surface.set_shader_parameter("light_tint", tint)
		surface.set_shader_parameter("source_position",position_hint)
	refresh_clock += delta
	if refresh_clock < 0.2: return
	refresh_clock = 0.0
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if not is_instance_valid(actor): continue
		for body in actor.find_children("Body","Sprite2D",true,false): body.material = null if reduced else surface
		if actor.INVENTORY == null: continue
		for item in actor.INVENTORY.getItems(): apply_to_item(item, not reduced)
	if Game.state == Game.State.Shop:
		for slot in Game.shopSceneNode.slots:
			if is_instance_valid(slot.item): apply_to_item(slot.item, not reduced)
		for item in Game.STORAGEBOX.getItems(): apply_to_item(item, not reduced)

func apply_to_item(item, enabled: bool):
	if not is_instance_valid(item) or not is_instance_valid(item.sprite): return
	if not item.has_meta("polish_material_recorded"):
		item.set_meta("polish_material_recorded",true)
		if item.sprite.material != null: item.set_meta("polish_original_material", item.sprite.material)
	item.sprite.material = surface if enabled else item.get_meta("polish_original_material") if item.has_meta("polish_original_material") else null
	# Bags receive the light; contents cast a low-cost silhouette shadow.
	if item.isBag(): return
	var occluder = item.sprite.get_node_or_null("PolishLightOccluder")
	if not enabled and occluder == null: return
	if occluder == null:
		occluder = LightOccluder2D.new(); occluder.name = "PolishLightOccluder"
		var polygon = OccluderPolygon2D.new()
		polygon.polygon = silhouette(item.sprite)
		occluder.occluder = polygon; item.sprite.add_child(occluder)
	occluder.visible = enabled and not item.dragged

func silhouette(sprite: Sprite2D) -> PackedVector2Array:
	var image = sprite.texture.get_image()
	if image.is_compressed(): image.decompress()
	var original_size = Vector2(image.get_size())
	var scale = 96.0/maxf(original_size.x,original_size.y)
	image.resize(maxi(1,roundi(original_size.x*scale)),maxi(1,roundi(original_size.y*scale)),Image.INTERPOLATE_BILINEAR)
	var rect = sprite.get_rect()
	var points: PackedVector2Array = []
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			if image.get_pixel(x,y).a < 0.4: continue
			points.append(rect.position+Vector2(x,y)/Vector2(image.get_size())*rect.size)
	return Geometry2D.convex_hull(points) if points.size() >= 3 else PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
