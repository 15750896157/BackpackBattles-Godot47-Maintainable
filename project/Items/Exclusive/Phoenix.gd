extends Weapon

var resurrectionPulse = load("res://Items/Animations/ResurectionPulse.tscn")
@export var ashSprite: Texture2D

@onready var normalSprite = sprite.texture
@onready var selfDam: int = getP("selfdam")
@onready var reincarnateHealth: int = getP("reincarnate_health")
var deathPrevented = false

func onPrepare():
	setState(false)
	connectForCombat(character(), "character_damaged", "onDamaged")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPhoenix.onDamaged(self, _damage, event)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPhoenix.doCooldownEffect(self)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(_deathPrevented):
	if _deathPrevented:
		setTexture(ashSprite)
	else:
		setTexture(normalSprite)
	deathPrevented = _deathPrevented
