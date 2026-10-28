extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Recipe.gd")

static func fromString(subject: Receiver, baseItem_, string):
	var formula = string.split(">")
	var ingredientNames = formula[0].split("+")

	var catalyst_ = []
	for i in ingredientNames.size():
		var name = ingredientNames[i]
		if name.ends_with("*"):
			catalyst_.push_back(true)
			ingredientNames[i] = name.trim_suffix("*")
		else:
			catalyst_.push_back(false)

	return subject.init(baseItem_, ingredientNames, catalyst_, formula[1])

static func init(subject: Receiver, baseItem_, ingredients_: Array, catalyst_: Array, fusedItem_):
	if baseItem_ is ItemDescriptor:
		subject.baseItem = baseItem_
	else:
		subject.baseItem = ItemBook.getDescriptor(baseItem_)

	for ingredient in ingredients_:
		if ingredient in Item.Type:
			subject.ingredients.push_back(Item.Type[ingredient])
		elif ingredient is ItemDescriptor:
			subject.ingredients.push_back(ingredient)
			if not ingredient.isReleased():
				return
		else:
			var descriptor = ItemBook.getDescriptor(ingredient)
			subject.ingredients.push_back(descriptor)
			if not descriptor.isReleased():
				return

	subject.catalyst = catalyst_
	if fusedItem_ is ItemDescriptor:
		subject.fusedItem = fusedItem_
	else:
		subject.fusedItem = ItemBook.getDescriptor(fusedItem_)

	if not subject.fusedItem.isReleased():
		return

	subject.allIngredients.push_back(subject.baseItem)
	subject.allIngredients.append_array(subject.ingredients)

	subject.baseItem.recipes.push_back(subject)
	subject.fusedItem.originatingRecipes.push_back(subject)
	for ingredient in subject.ingredients:
		if not subject.isTypeIngredient(ingredient):
			ingredient.recipesAsIngredient.push_back(subject)

	return subject

static func getCurIngredientsCounter(subject: Receiver, curBonds) -> Array:
	var current = {}
	var maxCounter = subject.getIngredientCounter(false)
	for bond in curBonds:
		Util.dictAdd(current, bond.descriptor)

	var currentCounter = []
	for descriptor in maxCounter:

		var cur = current.get(descriptor, 0)
		if cur < maxCounter[descriptor]:
			currentCounter.push_back([descriptor,
				cur, maxCounter[descriptor]])

	return currentCounter

static func checkNeighbor(subject: Receiver, curBonds, neighbor) -> bool:
	if not neighbor.canStartNewRecipe(): return false

	if not neighbor.isPlaced(): return false

	var curBondDescriptors = []
	for item in curBonds:
		curBondDescriptors.push_back(item.descriptor)

	var missingIngredients = Util.subtractArr(subject.ingredients, curBondDescriptors)

	for ingredient in missingIngredients:
		if subject.fitsIngredient(neighbor, ingredient):
			return true

	return false

static func fuse(subject: Receiver, bItem, curBonds):

	for item in curBonds:
		if subject.isNeighborCatalyst(item):
			item.catalystFusingFinished()
			if item.isGem() and item.getItem() == bItem:
				item.pushToStorage(Game.STORAGEBOX.center)
		else:
			if item.isGem() and item.socket:
				var socket = item.socket
				socket.onPickupGem()
				socket.hideSocket()
				item.ownerType = Item.Owner.PlayerStorageBox
			elif item.placed:
				item.inventory.removeItem(item)

			item.discard(false)

	if subject.fusedItem.isBag():
		bItem.pushGemsToStorage()
		bItem.inventory.removeItem(bItem)
		bItem.discard(false)
		var newItem = ItemBook.instantiateItem(subject.fusedItem)
		newItem.wasJustCrafted = true
		Game.playerNode.add_child(newItem)
		newItem.global_position = bItem.global_position
		newItem.pushToStorage(Game.STORAGEBOX.center + Util.randInBox(100, 100))
		Game.onItemCrafted(subject.fusedItem)
		newItem.onCraftedFrom(bItem, curBonds)

	elif bItem.isGem() and bItem.socket:

		var newItem = ItemBook.instantiateItem(subject.fusedItem)
		newItem.wasJustCrafted = true
		var socket = bItem.socket
		socket.onPickupGem()
		socket.add_child(newItem)
		newItem.global_position = bItem.global_position
		newItem.addToSocket(socket)
		CraftingManager.itemRemoved(bItem)
		bItem.ownerType = Item.Owner.PlayerStorageBox
		bItem.discard(false)
		Game.onItemCrafted(subject.fusedItem)
		newItem.onCraftedFrom(bItem, curBonds)

	else:
		if bItem.allowGeneratingFusionItem():

			var newItem = ItemBook.instantiateItem(subject.fusedItem)
			newItem.wasJustCrafted = true

			var craftingCenter = bItem.global_position
			var wasAddedToInventory = bItem.inventory.replaceItem(bItem, newItem)
			if wasAddedToInventory:
				newItem.playCraftedAnimation(craftingCenter)

			var numSockets = newItem.getNumSockets()
			var socketI = 0
			var gems = bItem.getGemsNoNull()
			for item in curBonds:
				if not subject.isNeighborCatalyst(item):
					gems.append_array(item.getGemsNoNull())

			if numSockets > 0 and gems.size() > 0:
				while true:
					if socketI < gems.size() and socketI < numSockets:
						var gem = gems[socketI]
						if not gem.fusing:
							gem.unsocket()
							gem.get_parent().remove_child(gem)
							newItem.setGem(socketI, gem)
						socketI += 1
					else:
						break

			for i in range(socketI, gems.size()):
				var gem = gems[i]
				if not gem.fusing:
					gem.pushToStorage(Game.STORAGEBOX.center)

			Game.onItemCrafted(subject.fusedItem)
			newItem.onCraftedFrom(bItem, curBonds)

		else:

			for item in curBonds:
				if not subject.isNeighborCatalyst(item):
					item.pushGemsToStorage()
			bItem.inventory.removeItem(bItem)
			bItem.pushGemsToStorage()
			bItem.discard(false)
