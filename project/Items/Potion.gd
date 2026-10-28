extends Item
class_name Potion

@export var potionColor: Color

var connectorScene = load("res://Items/Animations/PotionConnector.tscn")
const drinkSound = preload("res://Assets/Sound/PotionDrink.wav")
const triggerSound = preload("res://Assets/Sound/PotionOpen.wav")

@onready var fluid = $Icon/BottleOfBooze
@onready var fluidGradientTex = fluid.material.get_shader_parameter("gradient")
@onready var fluidGradient = fluidGradientTex.gradient.duplicate()
@onready var baseFoaminess = fluid.baseFoaminess
@onready var baseScroll = fluid.baseScroll
@onready var baseLevel = fluid.levelModification

var fluidTween
var isFull: bool = true
var connector = null

func _ready() -> void :
	super._ready()
	if connector == null:
		connector = connectorScene.instantiate()
		add_child(connector)

		$Icon/Flask1Overlay.use_parent_material = true

func prepare():
	super.prepare()
	setState(true)

func canAffect(item):
	return item.hasType(Type.Potion)

func isEmpty():
	return not isFull

func fill():
	return load("res://Runtime/Behavior/Features/Items/PotionBehavior.gd").fill(self)

func is_empty():
	return load("res://Runtime/Behavior/Features/Items/PotionBehavior.gd").is_empty(self)

func drink():
	setState(false, true)

func consumePotion(event = null, withActivate: bool = true):
	return load("res://Runtime/Behavior/Features/Items/PotionBehavior.gd").consumePotion(self, event, withActivate)

func onTriggerPotion(triggerEvent = null):
	pass

func triggerPotion(triggerEvent = null):
	onTriggerPotion(triggerEvent)
	playActivationAnimation()
	EventBus.emitSignal(self, "potion_triggered", [self])

func onStateChanged(_isFull):
	if _isFull:
		fill()
	else:
		is_empty()

	isFull = _isFull

func activate(damageRes = null, playCombatAni = true, consume = false,
	animationOverride = null, emitSignal: bool = true):

	super.activate(damageRes, playCombatAni, consume, null)

	if emitSignal:
		EventBus.emitSignal(self, "potion_emptied", [self])

func shopEntered(craft: bool):
	super.shopEntered(craft)
	if not isFull:
		fill()

func getAffectedCellsAfterRotate_primary(rotatedCells) -> Array:
	return load("res://Runtime/Behavior/Features/Items/PotionBehavior.gd").getAffectedCellsAfterRotate_primary(self, rotatedCells)

func addToInventory(_inventory, _occupiedCells: Array, _placedByPlayer: bool):
	super.addToInventory(_inventory, _occupiedCells, _placedByPlayer)
	updateConnector()

func onRemoveFromInventory():
	connector.disappear()
	connector.call_deferred("checkState")
	resetGradient()

func onFusingAsIngredient():
	connector.disappear()
	connector.call_deferred("checkState")
	resetGradient()

func onAffectedItemAdded(item, color: int):
	if color == Affected.Primary:
		updateConnector()

func onAffectedItemRemoved(item, color: int):
	if color == Affected.Primary:
		updateConnector()

func updateConnector():
	return load("res://Runtime/Behavior/Items/PotionBehavior.gd").updateConnector(self)

func resetGradient():
	fluidGradientTex.gradient = fluidGradient
	fluid.self_modulate = Color.WHITE
	fluid.baseFoaminess = baseFoaminess
	fluid.baseScroll = baseScroll

func discard(discardGems = true):
	if pooled:
		resetGradient()
		connector.reset()
	super.discard(discardGems)

func getStarPosition() -> Vector2:
	return load("res://Runtime/Behavior/Items/PotionBehavior.gd").getStarPosition(self)

