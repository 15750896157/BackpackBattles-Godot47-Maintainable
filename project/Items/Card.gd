extends Item
class_name Card

@export var back: Texture2D
@export var activeFront: Texture2D

@onready var cardAnimation = $CardAnimation
@onready var front = sprite.texture
@onready var connector = $Connector
@onready var notInChainMark = $NotInChainMark

var curActivationDelay: float
var faceUp = true
var activating = false
var chainPosition = - 1
var deck = null

func setFaceUp():
	if not faceUp:
		faceUp = true
		cardAnimation.play("ShowBack")

func setFaceDown():
	if faceUp:
		faceUp = false
		cardAnimation.play("ShowBack")

func updateTexture():
	if faceUp:
		if deck and activeFront and cardSecondaryEffectActive():
			setTexture(activeFront)
		else:
			setTexture(front)
	else:
		setTexture(back)

func cardSecondaryEffectActive():
	return false

func canAffect(item):
	return load("res://Runtime/Behavior/Features/Items/CardBehavior.gd").canAffect(self, item)

func prepare():
	super.prepare()
	setState(false)

func preCombatStart():
	super.preCombatStart()
	deactivateCooldown()

func getNextCard():
	return load("res://Runtime/Behavior/Features/Items/CardBehavior.gd").getNextCard(self)

func startActivation():
	return load("res://Runtime/Behavior/Features/Items/CardBehavior.gd").startActivation(self)

func playActivationAnimation(aniType = descriptor.activationAni,
	consume: bool = false):

	animation.play("Activate")

func onStateChanged(_faceUp: bool):
	return load("res://Runtime/Behavior/Features/Items/CardBehavior.gd").onStateChanged(self, _faceUp)

func doRevealEffect():
	pass

func trigger():
	return load("res://Runtime/Behavior/Features/Items/CardBehavior.gd").trigger(self)

func combatEnd():
	super.combatEnd()
	activating = false

func shopEntered(craft: bool):
	super.shopEntered(craft)
	setFaceUp()

func addToInventory(_inventory, _occupiedCells: Array, _placedByPlayer: bool):
	super.addToInventory(_inventory, _occupiedCells, _placedByPlayer)
	notInChainMark.appear()

func onRemoveFromInventory():
	notInChainMark.disappear()
	deck = null
	updateTexture()

func notifyChainPosition(_deck, _chainPos, chainLength):
	return load("res://Runtime/Behavior/Items/CardBehavior.gd").notifyChainPosition(self, _deck, _chainPos, chainLength)

func getDescription(wrapInColor = true) -> String:
	var descr = super.getDescription(wrapInColor)
	return getCardDescription(descr)

func getCardDescription(descr) -> String:
	return load("res://Runtime/Behavior/Items/CardBehavior.gd").getCardDescription(self, descr)

