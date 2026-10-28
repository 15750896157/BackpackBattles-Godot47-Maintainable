extends RefCounted
class_name CombatEvent

enum Target{
	Player = 0,
	Opponent = 1,
}

var id: int
var timestamp
var parentEvent
var origin
var type
var snapshot
var target = null
var params = {}
var formatParams = {}

func _init(_id, _timestamp = 0.0, _parentEvent = null,
	_origin = null, _type = null):

	id = _id
	timestamp = _timestamp
	parentEvent = _parentEvent
	origin = _origin
	type = _type

func getType() -> int:
	return type

func setTarget(_target):
	return load("res://Runtime/Behavior/Core/CombatEventBehavior.gd").setTarget(self, _target)

func setParam(paramName, paramVal):
	params[paramName] = paramVal
	formatParams[paramName] = paramVal

func getParam(paramName, default):
	return params.get(paramName, default)

func getAmount():
	return params["amount"]

func getAmountWithDefault(default):
	return params.get("amount", default)

func hasParam(param) -> bool:
	return param in params

func getMainActor() -> int:
	if origin is Item:
		return origin.character().playerId
	elif target:
		return target
	else:
		return Character.ID.PLAYER

func getOrigin():
	return origin

func fromCharacter(character) -> bool:
	return origin is Item and origin.character() == character

func getDepth() -> int:
	if parentEvent:
		return parentEvent.getDepth() + 1
	else:
		return 0

const damageColorPlayer = Color(0.755859, 0.008859, 0)
const damageColorOpponent = Color(1, 0.59079, 0.585938)
var damageColorPlayer_html = damageColorPlayer.to_html(false)
var damageColorOpponent_html = damageColorOpponent.to_html(false)
const damageFormat = "[b]{damage}[/b]"
var damageFormatDict = {"damage": 0}

func asText() -> String:
	return load("res://Runtime/Behavior/Core/CombatEventBehavior.gd").asText(self)

