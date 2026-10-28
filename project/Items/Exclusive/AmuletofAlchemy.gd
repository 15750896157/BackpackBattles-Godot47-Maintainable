extends Item

const amuletColor = Color(0.266667, 0.309804, 0.960784)
var triggerAnimation = load("res://Items/Exclusive/Animations/AmuletOfAlchemyAni.tscn")

@onready var potionTriggerTimer = $PotionTriggerTimer
@onready var delay = getP("delay")

var potionsToTrigger = []

func _ready():
	super._ready()
	specificDragParticles[0].self_modulate = amuletColor

func canAffect(item):
	return item.hasType(Type.Potion)

func onPrepare():
	for item in getAffectedItems():
		connectForCombat(item, "potion_emptied", "onPotionEmptied")

func onCombatStart():
	giveRandomBuffs(getP("buffs"))
	activate()

func onPotionEmptied(potion):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAmuletofAlchemy.onPotionEmptied(self, potion)

func triggerNextPotion():
	var potion = potionsToTrigger.pop_front()
	potion.triggerPotion()
	potion.miniActivate()
	activate()

func onCombatEnd():
	potionTriggerTimer.stop()
	potionsToTrigger.clear()
