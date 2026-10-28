extends Node2D

enum BondType{
	Normal = 0,
	Catalyst = 1,
}

const MIN_STRENGTH: = 0.15
const MIN_STRENGTH_CATALYST: = 0.07
const MIN_LENGTH: = 30.0
const CHANGE_DUR: = 0.3
const WEAK_STRENGTH: = 0.2
const STRONG_STRENGTH: = 0.27

@export var stretchFactor = 3.13
@export var bondType: BondType

var startNode
var endNode
var poolingHandle
var sprite
var tween
var fadeAcc = 0.0
var targetStrength: float

func preset():
	sprite = $Sprite2D
	sprite.modulate.a = MIN_STRENGTH

func create(_startNode, _endNode):
	startNode = _startNode
	endNode = _endNode
	set_process(true)

func _process(delta: float) -> void :
	load("res://Runtime/Behavior/Items/CraftingBondBehavior.gd")._process(self, delta)

func setStrong():
	targetStrength = STRONG_STRENGTH
	tween = Util.refreshTween(tween)
	tween.tween_property(sprite, "modulate:a", targetStrength, CHANGE_DUR)

func setWeak():
	targetStrength = WEAK_STRENGTH
	tween = Util.refreshTween(tween)
	tween.tween_property(sprite, "modulate:a", targetStrength, CHANGE_DUR)

func breakBond():
	return load("res://Runtime/Behavior/Items/CraftingBondBehavior.gd").breakBond(self)

func breakInstant():
	set_process(false)
	var minStrength = MIN_STRENGTH if bondType == BondType.Normal else MIN_STRENGTH_CATALYST
	sprite.modulate.a = minStrength
	returnToObjectPool()

func flash():
	return load("res://Runtime/Behavior/Items/CraftingBondBehavior.gd").flash(self)

func returnToObjectPool():
	ObjectPool.returnInstance(self)
