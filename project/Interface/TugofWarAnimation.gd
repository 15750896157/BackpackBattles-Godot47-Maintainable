extends Sprite2D

var oppoSword
var startRot: float
var oppoStartRot: float
var displayAdvantage: float

const STEP = 0.05
const MAX_ANGLE = 74.0
const DISADVANTAGE_FACTOR = 2.0

func _ready():
	set_physics_process(false)
	Game.connect("combat_scene_left", Callable(self, "leavingCombat"))

func activate():
	if not is_instance_valid(Game.OPPONENT):
		set_physics_process(false)
		return
	oppoSword = Game.OPPONENT.get_node("CombatUI/Sheet/Sword")
	set_physics_process(true)
	startRot = rotation_degrees
	oppoStartRot = oppoSword.rotation_degrees
	displayAdvantage = 0.5

func _physics_process(delta):
	load("res://Runtime/Callbacks/Interface/CallbacksT.gd").ForTugofWarAnimation._physics_process(self, delta)

func leavingCombat():
	set_physics_process(false)
	oppoSword = null
