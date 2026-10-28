extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/BuildIntoRecipesTooltip.gd")

static func setItem(subject: Receiver, item, asSubTooltip: bool):
	var descriptor = item.descriptor
	var ninePatchMaxWidth = subject.maxWidth + subject.ninePatchMargin

	subject.vboxcontainer = subject.get_node("VBoxContainer")
	var recipeI = 0

	var allRecipes = descriptor.recipes + descriptor.recipesAsIngredient
	allRecipes = Util.filterDuplicates(allRecipes)

	if allRecipes.size() > 0:
		var classRecipes = []
		var otherClassRecipes = []

		for recipe in allRecipes:
			if recipe.isAvailableForClass(Game.curClass):
				classRecipes.push_back(recipe)
			else:
				otherClassRecipes.push_back(recipe)

		var numRecipes = allRecipes.size()
		var headerParams = {}
		headerParams["total"] = numRecipes

		if numRecipes > 8:
			if classRecipes.is_empty():
				allRecipes = otherClassRecipes
			else:
				allRecipes = classRecipes

			numRecipes = allRecipes.size()
			subject.recipesHeader.translationKey = "TOOLTIP_Recipe_Subset"
			headerParams["shown"] = numRecipes
		else:
			allRecipes = classRecipes + otherClassRecipes
			if numRecipes == 1:
				subject.recipesHeader.translationKey = "TOOLTIP_Recipe_Single"
			else:
				subject.recipesHeader.translationKey = "TOOLTIP_Recipe_Full"

		subject.recipesHeader.formatParams = headerParams
		subject.recipesHeader.updateLocale()

		var heightPerRecipe = clamp(880 / numRecipes, 50, 170)
		var ownedCounter = ItemBook.getOwnedCounter()
		var shopCounter = {}
		for shop_item in Game.shopSceneNode.getItemsNoNull():
			Util.dictAdd(shopCounter, shop_item.descriptor)

		for recipe in allRecipes:
			if recipeI != 0:
				subject.vboxcontainer.add_child(subject.dividerScene.instantiate())
			recipeI += 1

			var entry = subject.recipeScene.instantiate()
			entry.maxWidth = subject.maxWidth
			entry.custom_minimum_size.y = heightPerRecipe
			entry.ownedCounter = ownedCounter.duplicate()
			entry.shopCounter = shopCounter.duplicate()
			subject.vboxcontainer.add_child(entry)
			entry.setRecipe(recipe, subject)
			subject.entries.push_back(entry)
	else:
		subject.recipesHeader.hide()

	var relatedItems = item.getRelatedItems()
	if not relatedItems.is_empty():
		var grid = subject.relatedItemsScene.instantiate()
		subject.entries.push_back(grid)
		subject.vboxcontainer.add_child(grid)
		grid.setItem(item, subject)

	var largestSize = 0
	for entry in subject.vboxcontainer.get_children():
		if entry.custom_minimum_size.x > largestSize:
			largestSize = entry.custom_minimum_size.x

	subject.vboxcontainer.custom_minimum_size.x = largestSize
	subject.vboxcontainer.size.x = largestSize
	subject.size.x = largestSize + subject.ninePatchMargin
	subject.size.y = 0

	var sizeDif = subject.size.x - ninePatchMaxWidth
	if not subject.growToRight:
		subject.position.x -= sizeDif

	subject.size.y = subject.vboxcontainer.size.y + subject.Y_BORDER

	if asSubTooltip:
		subject.lockHint.hide()

	subject.show()

static func onTooltipLocked(subject: Receiver):
	for entry in subject.entries:
		entry.enableFocus()

	subject.lockIcon.pivot_offset.x = subject.vboxcontainer.size.x * 0.5
	subject.animation.play("Lock")
	Sound.playSound(subject.lockSound, 0, Util.rng.randf_range(0.95, 1.05))
