extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Bag.gd")

static func previewCanAffect(subject: Receiver):
	var visuals = {}

	var itemDict
	if subject.ownerType == subject.Owner.Opponent:
		itemDict = ItemBook.opponentItems
	else:
		itemDict = ItemBook.ownableItems

	var curAffected = subject.getAffectedItemsInside()

	for descr in itemDict:
		for item in itemDict[descr]:
			if (item != subject and
				not item.isBag() and
				( not item.isGem() or item.socket == null)
				and subject.canApplyEffect(item)
				and not item in curAffected):

				var visual = visuals.get(item, null)
				if visual == null:
					visual = ObjectPool.instantiate(subject.canAffectVisual)
					item.add_child(visual)

					subject.canAffectVisuals.push_back(visual)
					visuals[item] = visual
				visual.setColorActive(visual.AffectsInside)

static func getAffectedItemsInside(subject: Receiver) -> Array:
	if not subject.placed: return []

	if not subject.cachedAffectedInsideItems.is_empty():
		return subject.cachedAffectedInsideItems

	var affected = []
	for item in subject.getItemsInside():
		if subject.canApplyEffect(item):
			affected.push_back(item)

	return affected
