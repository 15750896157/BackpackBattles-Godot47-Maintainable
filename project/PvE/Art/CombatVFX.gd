extends Node2D
## One transient canvas, bounded ribbons/particles, no extra dynamic lights.
const PALETTE = preload("res://PvE/Art/CombatPalette.gd")
const MAX_BURSTS = 16
const MAX_PARTICLES = 112
var bursts: Array[Dictionary] = []
var particle_count: int = 0
var emitted: Dictionary = {}
var suppressed: int = 0
var peak_particles: int = 0
var serial: int = 0
var light_material: ShaderMaterial
var layer: CanvasLayer

func _ready() -> void:
	light_material = ShaderMaterial.new()
	light_material.shader = preload("res://PvE/Art/CombatGlow.gdshader")
	material = light_material
	set_process(false)

func attach(host: Node) -> void:
	layer = CanvasLayer.new(); layer.name = "CombatEffectsLayer"; layer.layer = 45
	host.add_child(layer); layer.add_child(self)

func clear() -> void:
	bursts.clear(); particle_count = 0; queue_redraw(); set_process(false)
	for actor in [Game.PLAYER,Game.OPPONENT]:
		if is_instance_valid(actor) and is_instance_valid(actor.sprite) and actor.sprite.has_method("reset_pose"): actor.sprite.reset_pose()

func consume(event: Dictionary) -> void:
	if Game.state != Game.State.Combat: return
	var type = str(event.get("type",""))
	if type not in ["ITEM_ACTIVATED","PHYSICAL_DAMAGE","TRUE_DAMAGE","STATUS_DAMAGE","ARMOR_GAINED","HEAL"]: return
	var side = int(event.get("source_side",0))
	var target_side = int(event.get("target_side",1-side))
	var profile = PALETTE.event_profile(event,Expedition.db,Expedition.flow.combat_result)
	var actor = Game.PLAYER if side == 0 else Game.OPPONENT
	var target = Game.PLAYER if target_side == 0 else Game.OPPONENT
	if type == "ITEM_ACTIVATED" and (bool(profile.weapon) or str(profile.kind) in ["arcane","guard","heal"]):
		if is_instance_valid(actor.sprite) and actor.sprite.has_method("attack"): actor.sprite.attack(str(profile.kind))
		emit(str(profile.kind), side, profile)
	elif type in ["PHYSICAL_DAMAGE","TRUE_DAMAGE","STATUS_DAMAGE"]:
		if float(event.get("value",0)) > 0:
			if is_instance_valid(target.sprite) and target.sprite.has_method("hurt"): target.sprite.hurt()
			emit("impact" if type != "STATUS_DAMAGE" else "status", target_side, profile, bool(event.get("critical",false)))
		if float(event.get("armor_absorbed",0)) > 0: defend(target_side,profile)
	elif type == "ARMOR_GAINED" and float(event.get("value",0)) > 0: defend(target_side,profile)
	elif type == "HEAL" and float(event.get("value",0)) > 0: emit("heal",target_side,profile)

func defend(side: int, profile: Dictionary) -> void:
	var actor = Game.PLAYER if side == 0 else Game.OPPONENT
	if is_instance_valid(actor.sprite) and actor.sprite.has_method("defend"): actor.sprite.defend()
	emit("guard",side,profile)

func anchor(side: int) -> Vector2:
	var actor = Game.PLAYER if side == 0 else Game.OPPONENT
	if is_instance_valid(actor) and is_instance_valid(actor.sprite):
		var body = actor.sprite.get_node_or_null("Body")
		if body is Sprite2D and body.texture != null:
			var rect = body.get_rect()
			return body.to_global(rect.position+rect.size*Vector2(0.5,0.53))
	return Vector2(230 if side == 0 else 1690,870)

func emit(kind: String, side: int, profile: Dictionary, critical: bool = false) -> void:
	var settings: Dictionary = Expedition.preferences.values
	if bool(settings.reduce_effects): suppressed += 1; return
	# Repeated damage/armor triggers coalesce per side, retaining the first cue.
	for burst in bursts:
		if burst.kind == kind and int(burst.side) == side and float(burst.age) < 0.065:
			if critical: burst.critical = true; burst.rim = profile.rarity_color
			suppressed += 1; return
	if bursts.size() >= MAX_BURSTS: suppressed += 1; return
	var amount = mini(6 if bool(settings.reduce_motion) else 9 if critical else 7,MAX_PARTICLES-particle_count)
	if amount <= 0: suppressed += 1; return
	serial += 1
	var origin = anchor(side)
	var color: Color = profile.color
	if kind == "guard": color = PALETTE.ELEMENTS.guard
	elif kind == "heal": color = PALETTE.ELEMENTS.heal
	var duration = 0.52 if kind in ["arrow","arcane","guard","heal"] else 0.36
	bursts.append({"kind":kind,"side":side,"origin":origin,"target":anchor(1-side),"age":0.0,"duration":duration,"color":color,"rim":profile.rarity_color,"critical":critical,"particles":amount,"seed":serial,"reduced":bool(settings.reduce_motion)})
	particle_count += amount; peak_particles = maxi(peak_particles,particle_count)
	emitted[kind] = int(emitted.get(kind,0))+1
	light_material.set_shader_parameter("scene_energy",1.05 if int(Expedition.flow.run.get("act",1)) == 3 else 0.9)
	light_material.set_shader_parameter("flash_limit",0.55 if bool(settings.reduce_flash) else 1.0)
	set_process(true); queue_redraw()

func _process(delta: float) -> void:
	if Game.state != Game.State.Combat or Expedition.flow.screen_state != "COMBAT_RUNNING" or bool(Expedition.preferences.values.reduce_effects): clear(); return
	if bool(Expedition.flow.combat_paused): return
	var step = delta * float(Expedition.flow.combat_speed)
	for index in range(bursts.size()-1,-1,-1):
		bursts[index].age += step
		if float(bursts[index].age) >= float(bursts[index].duration):
			particle_count -= int(bursts[index].particles); bursts.remove_at(index)
	queue_redraw()
	if bursts.is_empty(): set_process(false)

func _draw() -> void:
	for burst in bursts:
		var p = clampf(float(burst.age)/float(burst.duration),0.0,1.0)
		var fade = sin(PI * p) * (1.0-p*0.35)
		if fade < 0.002: continue
		var origin: Vector2 = burst.origin
		var direction = 1.0 if int(burst.side) == 0 else -1.0
		var color: Color = burst.color
		var reduced = bool(burst.reduced)
		if burst.kind in ["slash","heavy"]:
			var points = PackedVector2Array()
			var radius = (118.0 if burst.kind == "heavy" else 94.0) * (0.75+p*0.35)
			for index in 15:
				var a = -1.6+p*1.2 + float(index)/14.0*1.9
				points.append(origin+Vector2(cos(a)*radius*direction,sin(a)*radius*0.85))
			# A tapered crescent carries the blade sweep, with a soft outer ribbon.
			var crescent = PackedVector2Array(points)
			for index in range(14,-1,-1):
				var a = -1.6+p*1.2+float(index)/14.0*1.9
				var inner = radius-(22.0 if burst.kind == "heavy" else 14.0)*sin(float(index+1)/16.0*PI)
				crescent.append(origin+Vector2(cos(a)*inner*direction,sin(a)*inner*0.85))
			draw_colored_polygon(crescent,Color(color,fade*0.35))
			stroke(points,color,fade,19 if burst.kind == "heavy" else 12)
		elif burst.kind in ["arrow","arcane"]:
			var finish: Vector2 = burst.target
			# Lift the flight path above the fixed lower HUD, then land on the actor.
			var flight = clampf(p*1.2,0.0,1.0)
			var arc_height = 160.0 if burst.kind == "arrow" else 205.0
			var travel = origin.lerp(finish,flight)-Vector2(0,sin(flight*PI)*arc_height) if not reduced else origin+Vector2(direction*70,0)
			var previous = maxf(0.0,flight-0.13)
			var tail = origin.lerp(finish,previous)-Vector2(0,sin(previous*PI)*arc_height) if not reduced else travel-Vector2(direction*55,0)
			var axis=(travel-tail).normalized()
			var normal=axis.orthogonal()
			stroke(PackedVector2Array([tail,travel]),color,fade,7 if burst.kind == "arrow" else 15)
			if burst.kind == "arrow":
				draw_polyline(PackedVector2Array([travel-axis*18-normal*10,travel,travel-axis*18+normal*10]),Color(1,0.98,0.86,fade),3,true)
				for index in 3:
					var glint=travel-axis*(28+index*34)+normal*sin(p*12.0+index)*8.0
					stroke(PackedVector2Array([glint-Vector2(0,4),glint+Vector2(0,4)]),color,fade*0.5,2)
			else: ring(travel,16+p*8,color,fade,0.0,TAU)
		elif burst.kind == "guard":
			var shield = origin+Vector2(direction*55,0)
			ring(shield,65+p*32,color,fade,-1.45 if direction>0 else 1.7,1.45 if direction>0 else 4.6)
			var outline=PackedVector2Array([shield+Vector2(-32,-57),shield+Vector2(32,-57),shield+Vector2(29,22),shield+Vector2(0,58),shield+Vector2(-29,22)])
			draw_colored_polygon(outline,Color(color,fade*0.19));outline.append(outline[0]);stroke(outline,color,fade,3)
		elif burst.kind == "heal": ring(origin,58+p*32,color,fade,-PI,0.0)
		elif burst.kind == "impact":
			stroke(PackedVector2Array([origin+Vector2(-30,-34),origin+Vector2(30,34)]),color,fade,5)
			stroke(PackedVector2Array([origin+Vector2(23,-28),origin+Vector2(-23,28)]),color,fade,4)
			if bool(burst.critical): ring(origin,32+p*55,burst.rim,fade,-PI,PI)
		for index in int(burst.particles):
			# Analytic particles have no nodes or RNG state; a sequence rotates spread.
			var angle = float(index)*2.39996 + float(burst.seed)*0.71
			var velocity = Vector2(cos(angle),sin(angle))*(32+(index%3)*21)
			if burst.kind == "heal": velocity.y = -absf(velocity.y)-32
			var point = origin + velocity * p * (0.4 if reduced else 1.0)
			if burst.kind not in ["guard","heal"]: point.y += 36*p*p
			# Subpixel polygons lose area precision at screen-edge coordinates.
			var radius = maxf(0.75,(2.2+(index%3))*fade)
			var vertices = PackedVector2Array([point+Vector2(0,-radius*1.8),point+Vector2(radius,0),point+Vector2(0,radius*1.8),point-Vector2(radius,0)])
			draw_colored_polygon(vertices,Color(color,fade*0.8))

func stroke(points: PackedVector2Array, color: Color, alpha: float, width: float) -> void:
	draw_polyline(points,Color(color,alpha*0.13),width*2.5,true)
	draw_polyline(points,Color(color,alpha*0.65),width,true)
	draw_polyline(points,Color(1,0.98,0.86,alpha*0.9),maxf(1,width*0.18),true)

func ring(center: Vector2, radius: float, color: Color, alpha: float, start: float, end: float) -> void:
	var points = PackedVector2Array()
	for index in 25: points.append(center+Vector2.from_angle(lerpf(start,end,float(index)/24.0))*radius)
	stroke(points,color,alpha,4)
