extends RefCounted
class_name DamageSource

enum Type{
	Melee = 0,
	Ranged = 1,
	Effect = 2,
	SelfDamage = 3,
	Unhealing = 98,
	Spikes = 104,
	Poison = 108,
	Fatigue = 99,
}
const damTypeNames = {
	Type.Melee: "melee",
	Type.Ranged: "ranged",
	Type.Effect: "effect"
}

enum Flags{
	None = 0,
	CanBeBlocked = 1,
	CanTriggerSpikes = 2,
	CanTriggerVampirism = 4,
	CanTriggerItems = 8,
	CanMiss = 16,
	CanCrit = 32,
	All = 63,
}

const chipDamageFlags = Flags.CanBeBlocked
const meleeFlags = Flags.All
const rangedFlags = Flags.All
const effectFlags = Flags.CanBeBlocked + Flags.CanTriggerItems + Flags.CanCrit
const unhealingFlags = Flags.CanBeBlocked + Flags.CanTriggerItems
const selfDamageFlags = Flags.CanBeBlocked + Flags.CanTriggerItems

var minDamage: int
var maxDamage: int
var types: Array
var accuracy: float = 100
var critChancePercent: float = 0
var origin
var flags = Flags.All

func fromDamageSource(otherDamSource):
	return load("res://Runtime/Behavior/Utility/DamageSourceBehavior.gd").fromDamageSource(self, otherDamSource)

func setItem(item, _type = null):
	return load("res://Runtime/Behavior/Utility/DamageSourceBehavior.gd").setItem(self, item, _type)

func init(_origin = null, _type = Type.Effect, _minDamage = 0,
	_maxDamage = null, _accuracy = 100):

	origin = _origin
	if _type is Array:
		types = _type
	else:
		types = [_type]
	setDamage(_minDamage, _maxDamage)
	accuracy = _accuracy
	return self

func hasType(_type: int):
	return _type in types

func setDamage(_minDamage, _maxDamage = null):
	minDamage = _minDamage
	if _maxDamage:
		maxDamage = _maxDamage
	else:
		maxDamage = minDamage

func addDamage(_damage):
	minDamage += _damage
	maxDamage += _damage

func getCritChancePercent():
	return clamp(critChancePercent, 0.0, 100.0)

func updateItem(item):

	accuracy = item.getAccuracy()

func updateEffect(item, damage):
	origin = item
	setDamage(item.getModifiedEffectDamage(damage))
	critChancePercent = item.getCritChancePercent()

func addCritChancePercent(_critChance):
	critChancePercent += _critChance

func setFlag(flag):
	flags |= flag

func unsetFlag(flag):
	flags = flags & ~ flag

func canMiss() -> bool:
	return flags & Flags.CanMiss

func canTriggerSpikes() -> bool:
	return flags & Flags.CanTriggerSpikes

func canTriggerVampirism() -> bool:
	return flags & Flags.CanTriggerVampirism

func canBeBlocked() -> bool:
	return flags & Flags.CanBeBlocked

func canCrit() -> bool:
	return flags & Flags.CanCrit

func isAttack() -> bool:
	return hasType(Type.Melee) or hasType(Type.Ranged)

func isEffectDamage() -> bool:
	return hasType(Type.Effect) or hasType(Type.Unhealing)

func isAttackOrEffect() -> bool:
	return isAttack() or isEffectDamage()

func canApplyLifesteal() -> bool:
	return isAttack() or hasType(Type.Effect)

func makeSpectral():
	unsetFlag(Flags.CanBeBlocked)

func randDamage():
	return load("res://Runtime/Behavior/Utility/DamageSourceBehavior.gd").randDamage(self)

