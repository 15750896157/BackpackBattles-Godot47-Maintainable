extends Item

@onready var poison = int(getP("poison"))
@onready var selfPoison = int(getP("poison2"))
@onready var cdAdvance = getP("cdadvance")
@onready var luckNeeded = int(getP("luckt"))
@onready var light = $Icon/Light3D
@onready var lightAni = $Icon/AnimationPlayer

var poisonCritActive: bool
var tween: Tween

func onPrepare():
	lightAni.stop()
	setState(false)

	connectForCombat(character(), "character_lucky_changed", "onLuckChanged")

func doCooldownEffect():
	inflictPoison(poison)
	selfInflictPoison(selfPoison)
	onAfterEffectFinished()

func onChargeReceived(_charge):
	advanceCooldownSeconds(cdAdvance)
	miniActivate()

func onLuckChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPoisonGrenade.onLuckChanged(self, amount, event)

func onShopEntered():

	onStateChanged(false)
	Util.callDelayed(lightAni, "play", 0.2, ["Idle"])

func onStateChanged(_poisonCritActive):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPoisonGrenade.onStateChanged(self, _poisonCritActive)

