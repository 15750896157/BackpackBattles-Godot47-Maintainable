extends Node2D

const gradients = [
	preload("res://Items/Particles/ChargeGradient1.tres"),
	preload("res://Items/Particles/ChargeGradient2.tres"),
	preload("res://Items/Particles/ChargeGradient3.tres"),
	preload("res://Items/Particles/ChargeGradient4.tres")
]

const modulates = [
	Color(0.984314, 0.92549, 0.721569),
	Color(0.721569, 0.984314, 0.721569),
	Color(1, 0.619608, 0.619608),
	Color(0.498039, 0.803922, 1)
]

var particleScene = load("res://Items/Animations/ChargedTile.tscn")

const FADE_DUR = 0.5
const MAX_INTENSITY = 0.714
const MIN_INTENSITY = 0.0

var duration: float
var cells: Array
var emitterItem
var lastChargedItem = null
var curChargedItem = null
var inventoryCells
var tween: Tween
var poolingHandle

var particles
var particlesSpeedScale
var ball
var ballMaterial
var chargedTileParticles
var chargedTileFrame
var chargedTileAnimation
var chargedTileVisible: bool

func preset():
	return load("res://Runtime/Behavior/Items/ElectricalChargeBehavior.gd").preset(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(chargedTileParticles):
		if chargedTileParticles.get_parent() == null:
			chargedTileParticles.free()

func returnToObjectPool():
	return load("res://Runtime/Behavior/Features/Items/ElectricalChargeBehavior.gd").returnToObjectPool(self)

func seek(_item, _cells: Array, _duration: float, time: float, stop: bool = true):
	return load("res://Runtime/Behavior/Features/Items/ElectricalChargeBehavior.gd").seek(self, _item, _cells, _duration, time, stop)

func stop():
	tween.pause()

func start(_item, _cells: Array, _duration: float, replaying: bool = false):
	return load("res://Runtime/Behavior/Items/ElectricalChargeBehavior.gd").start(self, _item, _cells, _duration, replaying)

func logEvent(event):
	Game.combatLog.logElectricalCharge(event, duration, cells)

func onNewCellEntered(cellIndex: int):
	return load("res://Runtime/Behavior/Items/ElectricalChargeBehavior.gd").onNewCellEntered(self, cellIndex)

func moveParticlesToCell(cellCenter):
	chargedTileParticles.position = cellCenter - Vector2(35, 35)
	chargedTileAnimation.play("MoveTile")

func disappear(delay: float):
	return load("res://Runtime/Behavior/Features/Items/ElectricalChargeBehavior.gd").disappear(self, delay)

func deactivateParticles():
	chargedTileParticles.emitting = false

func onCombatEnded(_roundResult):
	if is_inside_tree():
		tween = Util.refreshTween(tween)
		tween.set_parallel()
		disappear(0)

		returnToObjectPool()
