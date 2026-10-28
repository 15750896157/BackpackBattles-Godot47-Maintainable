extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/ItemDescriptor.gd")

static func getTranslatedName(subject: Receiver) -> String:
	var translated = Util.tra(subject.getName() + "_NAME")
	if translated.ends_with("NAME"):
		return subject.getName()
	else:
		return translated

static func calcAppropriation(subject: Receiver):
	if subject.classes == subject.StuffedClasses.Neutral: return

	for recipe in subject.originatingRecipes:
		for ingredient in recipe.getAllIngredients():
			if not recipe.isTypeIngredient(ingredient):
				for item in ingredient.appropriatingItems:
					if not item in subject.appropriatingItems:
						subject.appropriatingItems.push_back(item)

	if subject.gateItem != null:
		subject.appropriatingItems.push_back(subject.gateItem)

static func getCraftingDepth(subject: Receiver) -> int:
	if subject.originatingRecipes.is_empty(): return 0

	var depth: int
	for recipe in subject.originatingRecipes:
		for ingredient in recipe.getAllIngredients():
			if not recipe.isTypeIngredient(ingredient):
				depth = max(depth, ingredient.getCraftingDepth())

	return depth + 1

static func canCraft(subject: Receiver, classId) -> bool:
	for recipe in subject.originatingRecipes:
		var craftable = true
		for ingredient in recipe.getAllIngredients():
			if (Util.isItemDescriptor(ingredient) and
				not ingredient.isAvailableFor(classId) and
				not ItemBook.isItemInInventory(ingredient)):
					craftable = false
		if craftable:
			return true
	return false

static func isReleased(subject: Receiver) -> bool:
	if subject.releaseState == subject.ReleaseState.Demo:
		return true
	elif subject.releaseState == subject.ReleaseState.Full:
		return Game.loadExclusiveContent()
	else:
		return Game.loadUnreleasedContent()

static func getClassesAsArray(subject: Receiver) -> Array:
	var classArr = []
	var counter = 1
	for i in Game.getNumClasses():
		if subject.classes & counter:
			classArr.push_back(counter)
		counter = counter << 1
	return classArr
