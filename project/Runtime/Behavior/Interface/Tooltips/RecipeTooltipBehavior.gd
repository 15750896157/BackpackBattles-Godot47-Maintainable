extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/RecipeTooltip.gd")

static func setItem(subject: Receiver, item):
	subject.nameLabel.text = item.getTranslatedName()
	subject.modulate = Color.TRANSPARENT
	var recipeI = - 1

	for i in item.descriptor.originatingRecipes.size():
		recipeI += 1

		var recipe = item.descriptor.originatingRecipes[i]

		if not recipe.isAvailableForClass(Game.recipeBook.selectedClass):
			recipeI -= 1
			continue

		if recipeI == 1:
			subject.divider.show()
		elif recipeI == 2:
			subject.divider2.show()

		var ingredients = recipe.getAllIngredients()
		var ingredientNum = ingredients.size()
		var ingredientI = 0

		for ingredient in ingredients:
			var ingredientControl = subject.ingredientScene.instantiate()

			if ingredientI < subject.ingredientsPerRow and recipeI == 0:
				subject.hboxContainer.add_child(ingredientControl)
			elif recipeI == 2:
				subject.hboxContainer3.add_child(ingredientControl)
			else:
				subject.hboxContainer2.add_child(ingredientControl)

			subject.ingredientControls.push_back(ingredientControl)

			if ingredientI < ingredientNum - 1:
				var plus = subject.recipePlus.instantiate()
				if ingredientI < subject.ingredientsPerRow - 1 and recipeI == 0:
					subject.hboxContainer.add_child(plus)
				elif ingredientI == subject.ingredientsPerRow - 1 and recipeI == 0:
					subject.hboxContainer2.add_child(plus)
					subject.hboxContainer2.move_child(plus, 0)
				elif recipeI == 2:
					subject.hboxContainer3.add_child(plus)
				else:
					subject.hboxContainer2.add_child(plus)

			if recipe.isTypeIngredient(ingredient):
				var typeName = item.Type.keys()[ingredient]
				ingredientControl.setType(typeName)
			else:
				ingredientControl.setItem(ingredient, recipe.isDescriptorCatalyst(ingredient))
				ingredientControl.call_deferred("positionItem")

			ingredientI += 1

	Util.localizeFonts(subject.nameLabel)
	Util.callNextFrame(subject, "createItemTooltip", [item])

static func createItemTooltip(subject: Receiver, item):

	if subject.isDiscarded(): return

	subject.itemTooltip = ObjectPool.instantiate(item.tooltipScenes[item.getRarity()])

	Game.tooltipsNode.add_child(subject.itemTooltip)
	subject.itemTooltip.setItem(item)
	var itemIsLeft = item.global_position.x < subject.global_position.x

	var marginToSubTooltip = Vector2( - 50, 0)
	var topLeft: Vector2
	if itemIsLeft:
		topLeft.x = subject.itemTopLeft.x
		topLeft.y = subject.position.y
	else:
		topLeft = subject.position
		topLeft.x += 50

	var combined_size: Vector2 = subject.itemSize + subject.size + marginToSubTooltip

	subject.itemTooltip.forceUpdatePosition(topLeft, combined_size, subject.Alignment.Top)

static func updateSize(subject: Receiver):

	var xSize = subject.vboxcontainer.size.x + subject.X_BORDER
	var ySize = subject.vboxcontainer.size.y + subject.Y_BORDER

	subject.set_end(subject.position)
	subject.set_end(subject.position + Vector2(xSize, ySize))
