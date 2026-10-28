extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/DamageSource.gd")

static func setItem(subject: Receiver, item, _type):
	if _type != null:
		subject.types = [_type]
	else:
		if item.hasType(Item.Type.Ranged):
			subject.types.push_back(subject.Type.Ranged)

		if item.hasType(Item.Type.Melee):
			subject.types.push_back(subject.Type.Melee)

		if item.hasType(Item.Type.Effect):
			subject.types.push_back(subject.Type.Effect)

		if subject.types.is_empty():
			subject.types.push_back(subject.Type.Effect)

	if subject.hasType(subject.Type.Melee):
		subject.flags = subject.meleeFlags
	elif subject.hasType(subject.Type.Ranged):
		subject.flags = subject.rangedFlags
	elif subject.hasType(subject.Type.SelfDamage):
		subject.flags = subject.selfDamageFlags
	else:
		subject.flags = subject.effectFlags

	return subject.init(item, subject.types, item.getMinDamage(), item.getMaxDamage(), item.getAccuracy())

static func fromDamageSource(subject: Receiver, otherDamSource):
	subject.minDamage = otherDamSource.minDamage
	subject.maxDamage = otherDamSource.maxDamage
	subject.types = otherDamSource.types.duplicate()
	subject.accuracy = otherDamSource.accuracy
	subject.critChancePercent = otherDamSource.critChancePercent
	subject.flags = otherDamSource.flags
	subject.origin = otherDamSource.origin
	return subject

static func randDamage(subject: Receiver):
	if subject.origin is Item:
		subject.critChancePercent = subject.origin.getCritChancePercent()
		if subject.isAttack():
			subject.setDamage(subject.origin.getMinDamage(subject), subject.origin.getMaxDamage(subject))
		return subject.origin.damageRangeRng.randIntRange(
			subject.minDamage, subject.maxDamage)
	else:
		return Util.rng.randi_range(subject.minDamage, subject.maxDamage)
