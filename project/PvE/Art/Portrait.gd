extends Node2D
## Single supplied character illustration; legacy combat/skin interfaces remain.
var skins: Dictionary = {}
var clock: float = 0.0
var impact: float = 0.0
var last_health: float = -1.0
var bounce: float = 0.0
var attack_motion: float = 0.0
var defend_motion: float = 0.0
var pose_kind: String = "slash"
var rest_scale: float = 1.0
var full_texture: Texture2D
var shop_texture: Texture2D
var art_key = ""
var appearance = {"tint":Color.WHITE,"scale":1.0}
const CATALOG = preload("res://PvE/Art/SuppliedArt.gd")
@onready var body: Sprite2D = $Body
@onready var character = get_parent().get_parent().get_parent()

func _ready():
	top_level = true
	z_index = 60
	art_key = enemy_art() if character.playerId == Character.ID.OPPONENT else CATALOG.player_key(Game.curClass)
	if character.playerId == Character.ID.OPPONENT:appearance=preload("res://PvE/Art/NewArtCatalog.gd").enemy_variant(Expedition.flow.run.get("current_node",{}))
	var path = CATALOG.actor_path(art_key)
	full_texture = AssetStream.resolve(path)
	shop_texture = AssetStream.resources.get(CATALOG.shop_actor_path(art_key))
	body.texture = full_texture
	set_meta("new_art_path", path)
	var factor = 420.0 / body.texture.get_height()
	rest_scale = factor
	body.scale = Vector2.ONE * factor
	body.position = Vector2(-body.texture.get_width() * factor * 0.5, -420)
	# These supplied enemies are already painted facing the player's side.
	body.flip_h = false
	last_health = character.getCurrentHealth()
	$SpriteAnimationPlayer.animation_finished.connect(_finished)

static func enemy_art() -> String:
	if Expedition.flow == null or Expedition.flow.run.is_empty(): return "skeleton"
	return preload("res://PvE/Art/NewArtCatalog.gd").enemy_key(Expedition.flow.run.get("current_node",{}))

func _finished(_name): bounce = 1.0
func attack(kind: String = ""):
	if not kind.is_empty(): pose_kind = kind
	attack_motion = 1.0
func hurt(): impact = 1.0
func defend(): defend_motion = 1.0
func reset_pose():
	attack_motion = 0.0; impact = 0.0; defend_motion = 0.0; bounce = 0.0
	if is_instance_valid(body):
		body.rotation = 0.0; body.skew = 0.0
		body.scale = Vector2.ONE*rest_scale
		if body.texture != null: body.position = -Vector2(body.texture.get_width()*0.5,body.texture.get_height())*rest_scale
func setSkin(slot: int, skin_id: int): skins[slot] = skin_id
func syncIdleAnis(): pass
func findIdleAnis(_node): pass
func searchNodes(_slot, _root) -> Array: return []

func _process(delta):
	if not is_instance_valid(character): return
	visible = Game.state != Game.State.Title
	clock += delta
	var combat = Game.state == Game.State.Combat
	if combat and Expedition.flow != null:
		delta *= 0.0 if Expedition.flow.combat_paused else float(Expedition.flow.combat_speed)
	elif attack_motion > 0.0 or defend_motion > 0.0 or impact > 0.0: reset_pose()
	body.texture = shop_texture if Game.state == Game.State.Shop and shop_texture != null else full_texture
	var target = Vector2(215, 1065) if character.playerId == Character.ID.PLAYER else Vector2(1695, 1065)
	if Game.state == Game.State.Shop: target = Vector2(1665, 1080)
	elif Game.state == Game.State.Title: target = Vector2(550, 1000)
	global_position = target
	var reduced = Expedition.preferences != null and bool(Expedition.preferences.values.get("reduce_motion", false))
	var health = character.getCurrentHealth()
	if health < last_health: impact = 1.0
	last_health = health
	impact = move_toward(impact, 0.0, delta * 4.0)
	bounce = move_toward(bounce, 0.0, delta * 3.0)
	attack_motion = move_toward(attack_motion, 0.0, delta * 5.0)
	defend_motion = move_toward(defend_motion, 0.0, delta * 3.8)
	var wave = 0.0 if reduced else sin(clock * 2.4) * 2.0
	position += Vector2((sin(clock * 70.0) * 5.0 * impact + sin(attack_motion * PI) * (18.0 if character.playerId == Character.ID.PLAYER else -18.0)) if not reduced else 0.0, wave - (sin(bounce * PI) * 15.0 if not reduced else 0.0))
	var height = 450.0 if combat else (420.0 if art_key == "armorer" else 390.0) if Game.state == Game.State.Shop else 430.0
	if character.playerId == Character.ID.OPPONENT:
		height = float({"bat":195,"goblin":290,"snake":250,"spider":260,"mummy":350,"lava_snail":230,"moss_golem":330,"hermit_crab":270,"sand_lizard":250,"lava_golem":370,"werewolf":340,"antlion":330,"boss":390,"final_boss":430}.get(art_key,355))
		if enemy_art() == "bat": position.y -= 65.0
		height *= float(appearance.scale)
	var factor = height / body.texture.get_height()
	rest_scale = factor
	var facing = 1.0 if character.playerId == Character.ID.PLAYER else -1.0
	var attack_pose = sin(attack_motion*PI) if not reduced and combat else 0.0
	var hurt_pose = sin(impact*PI) if not reduced and combat else 0.0
	var guard_pose = sin(defend_motion*PI) if not reduced and combat else 0.0
	var power = 1.3 if pose_kind == "heavy" else 0.55 if pose_kind == "arrow" else 1.0
	var lean = facing*(attack_pose*0.065*power-hurt_pose*0.075-guard_pose*0.035)
	body.rotation = lean
	body.skew = facing*(-attack_pose*0.10*power+hurt_pose*0.075+guard_pose*0.055)
	body.scale = Vector2(1.0+attack_pose*0.035-hurt_pose*0.045,1.0-attack_pose*0.025+hurt_pose*0.025-guard_pose*0.035)*factor
	# Keep the feet fixed while skewing/rotating the illustration above them.
	var feet = Vector2(body.texture.get_width()*0.5,body.texture.get_height())
	body.position = -body.transform.basis_xform(feet)
	var flash = 0.0 if Expedition.preferences != null and bool(Expedition.preferences.values.get("reduce_flash", false)) else impact
	body.modulate = Color(appearance.tint.r, appearance.tint.g * (1.0-flash*0.3), appearance.tint.b * (1.0-flash*0.3), body.modulate.a)
