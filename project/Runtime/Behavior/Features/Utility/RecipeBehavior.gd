extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Recipe.gd")

static func findBonds(subject: Receiver, neighbors) -> Array:
	var bonds = []
	for ingredient in subject.ingredients:
		for neighbor in neighbors:
			if (subject.fitsIngredient(neighbor, ingredient) and
				not neighbor.isBoundAsIngredient() and
				not neighbor.isLocked()):
				bonds.push_back(neighbor)
				neighbors.erase(neighbor)
				break

	return bonds

static func getMissingIngredients(subject: Receiver, curBonds) -> Array:
	var missing = []
	var counter = subject.getIngredientCounter(false)
	for bond in curBonds:
		Util.dictSub(counter, bond.descriptor)

	for descriptor in counter:
		for num in counter[descriptor]:
			missing.push_back(descriptor)
	return missing

static func isNeighborCatalyst(subject: Receiver, neighbor) -> bool:
	for i in subject.ingredients.size():
		if subject.fitsIngredient(neighbor, subject.ingredients[i]):
			return subject.catalyst[i]

	Util.eassert(false)
	return false

static func isDescriptorCatalyst(subject: Receiver, descriptor: ItemDescriptor) -> bool:
	for i in subject.ingredients.size():
		if not subject.isTypeIngredient(subject.ingredients[i]):
			if descriptor == subject.ingredients[i]:
				return subject.catalyst[i]
	return false

static func isAvailableForClass(subject: Receiver, classI):
	if not subject.baseItem.isAvailableFor(classI):
		return false

	for ingredient in subject.ingredients:
		if not subject.isTypeIngredient(ingredient):
			if not ingredient.isAvailableFor(classI):
				return false

	return true
