extends Node2D
## Single supplied character illustration; legacy combat/skin interfaces remain.
var skins: Dictionary = {}
var clock: float = 0.0
var impact: float = 0.0
var last_health: float = -1.0
var bounce: float = 0.0
var attack_motion: float = 0.0
@onready var body: Sprite2D = $Body
@onready var character = get_parent().get_parent().get_parent()

func _ready():
	top_level = true
	z_index = 60
	var key = "hero"
	if character.playerId == Character.ID.OPPONENT: key = enemy_art()
	var path = "res://Art/20261022/" + key + ".png"
	if key != "hero": body.texture = AssetStream.resolve(path)
	set_meta("new_art_path", path)
	var factor = 420.0 / body.texture.get_height()
	body.scale = Vector2.ONE * factor
	body.position = Vector2(-body.texture.get_width() * factor * 0.5, -420)
	body.flip_h = character.playerId == Character.ID.OPPONENT
	last_health = character.getCurrentHealth()
	$SpriteAnimationPlayer.animation_finished.connect(_finished)

static func enemy_art() -> String:
	if Expedition.flow == null or Expedition.flow.run.is_empty(): return "skeleton"
	var node: Dictionary = Expedition.flow.run.get("current_node", {})
	if node.get("type", "") == "boss": return "skeleton"
	var enemy = Expedition.db.get_row("enemy_builds", str(node.get("enemy_id", "")))
	var archetype = str(enemy.get("archetype_id", ""))
	if archetype in ["venom_brewer", "field_mender", "toxic_guard"]: return "goblin"
	if archetype in ["ember_runner", "quick_striker", "gear_conductor"]: return "bat"
	return "skeleton"

func _finished(_name): bounce = 1.0
func attack(): attack_motion = 1.0
func setSkin(slot: int, skin_id: int): skins[slot] = skin_id
func syncIdleAnis(): pass
func findIdleAnis(_node): pass
func searchNodes(_slot, _root) -> Array: return []

func _process(delta):
	if not is_instance_valid(character): return
	clock += delta
	var combat = Game.state == Game.State.Combat
	var target = Vector2(330, 1000) if character.playerId == Character.ID.PLAYER else Vector2(1590, 1000)
	if Game.state == Game.State.Shop: target = Vector2(1720, 1060)
	elif Game.state == Game.State.Title: target = Vector2(550, 1000)
	global_position = target
	var reduced = Expedition.preferences != null and bool(Expedition.preferences.values.get("reduce_motion", false))
	var health = character.getCurrentHealth()
	if health < last_health: impact = 1.0
	last_health = health
	impact = move_toward(impact, 0.0, delta * 4.0)
	bounce = move_toward(bounce, 0.0, delta * 3.0)
	attack_motion = move_toward(attack_motion, 0.0, delta * 5.0)
	var wave = 0.0 if reduced else sin(clock * 2.4) * 2.0
	position += Vector2((sin(clock * 70.0) * 5.0 * impact + sin(attack_motion * PI) * (18.0 if character.playerId == Character.ID.PLAYER else -18.0)) if not reduced else 0.0, wave - (sin(bounce * PI) * 15.0 if not reduced else 0.0))
	var height = 260.0 if combat else 345.0 if Game.state == Game.State.Shop else 430.0
	if character.playerId == Character.ID.OPPONENT:
		height = 150.0 if enemy_art() == "bat" else 215.0 if enemy_art() == "goblin" else 255.0
		if enemy_art() == "bat": position.y -= 65.0
	var factor = height / body.texture.get_height()
	body.scale = Vector2.ONE * factor
	body.position = Vector2(-body.texture.get_width() * factor * 0.5, -height)
	var flash = 0.0 if Expedition.preferences != null and bool(Expedition.preferences.values.get("reduce_flash", false)) else impact
	body.modulate = Color(1.0, 1.0 - flash * 0.3, 1.0 - flash * 0.3, body.modulate.a)
