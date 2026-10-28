extends RefCounted
class_name Recipe

var baseItem: ItemDescriptor
var ingredients = []
var catalyst = []
var fusedItem: ItemDescriptor
var allIngredients = []

func fromString(baseItem_, string):
	return load("res://Runtime/Behavior/Utility/RecipeBehavior.gd").fromString(self, baseItem_, string)

func init(baseItem_, ingredients_: Array, catalyst_: Array, fusedItem_):
	return load("res://Runtime/Behavior/Utility/RecipeBehavior.gd").init(self, baseItem_, ingredients_, catalyst_, fusedItem_)

func isAvailable(item):
	return fusedItem.canCraft(item.character().characterClass)

func isBaseItem(item) -> bool:
	return item.descriptor == baseItem

func fitsIngredient(item, ingredient):
	if isTypeIngredient(ingredient):
		return item.hasType(ingredient)
	else:
		return item.getRecipeDescriptor() == ingredient

func hasBagIngredient() -> bool:
	for ingredient in ingredients:
		if not isTypeIngredient(ingredient):
			if ingredient.isBag():
				return true
	return false

func findBonds(neighbors) -> Array:
	return load("res://Runtime/Behavior/Features/Utility/RecipeBehavior.gd").findBonds(self, neighbors)

func getNumIngredients():
	return ingredients.size()

func getProgress(curBonds):
	return curBonds.size() / float(ingredients.size())

func getMissingIngredients(curBonds) -> Array:
	return load("res://Runtime/Behavior/Features/Utility/RecipeBehavior.gd").getMissingIngredients(self, curBonds)

func getCurIngredientsCounter(curBonds) -> Array:
	return load("res://Runtime/Behavior/Utility/RecipeBehavior.gd").getCurIngredientsCounter(self, curBonds)

func checkNeighbor(curBonds, neighbor) -> bool:
	return load("res://Runtime/Behavior/Utility/RecipeBehavior.gd").checkNeighbor(self, curBonds, neighbor)

func isCatalystRecipe() -> bool:
	return catalyst[0]

func isTypeIngredient(ingredient) -> bool:
	return typeof(ingredient) == TYPE_INT

func isNeighborCatalyst(neighbor) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/RecipeBehavior.gd").isNeighborCatalyst(self, neighbor)

func isDescriptorCatalyst(descriptor: ItemDescriptor) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/RecipeBehavior.gd").isDescriptorCatalyst(self, descriptor)

func fuse(bItem, curBonds):
	return load("res://Runtime/Behavior/Utility/RecipeBehavior.gd").fuse(self, bItem, curBonds)

func getCatalystBonds(curBonds):
	var nonCatalystBonds = []
	for neighbor in curBonds:
		if isNeighborCatalyst(neighbor):
			nonCatalystBonds.push_back(neighbor)
	return nonCatalystBonds

func getNonCatalystBonds(curBonds):
	return Util.subtractArr(curBonds, getCatalystBonds(curBonds))

func getAllIngredients():
	return allIngredients

func isAvailableForClass(classI):
	return load("res://Runtime/Behavior/Features/Utility/RecipeBehavior.gd").isAvailableForClass(self, classI)

func getIngredientCounter(withTypes = true) -> Dictionary:
	var counter = {}
	for descriptor in ingredients:
		if withTypes or not isTypeIngredient(descriptor):
			Util.dictAdd(counter, descriptor)
	return counter
