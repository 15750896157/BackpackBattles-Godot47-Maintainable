extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/BuildIntoRecipe.gd")

static func setRecipe(subject: Receiver, recipe, tooltip):

	var labelToTypeIngredient = {}

	subject.custom_minimum_size.x = subject.maxWidth

	var widthPerIngredient = subject.maxWidth - subject.equals.size.x - subject.MARGIN * 0.5
	widthPerIngredient /= recipe.getNumIngredients() + 2
	var maxSize = Vector2(widthPerIngredient, subject.custom_minimum_size.y - subject.MARGIN * 0.5)

	var actualWidth = 0

	var fusedItem = subject.addItem(recipe.fusedItem, maxSize, tooltip)
	subject.addedItems.push_back(fusedItem)
	actualWidth += fusedItem.getTextureSize().x
	actualWidth += subject.equals.size.x
	subject.addedItems.push_back(subject.equals)

	for ingredientDescriptor in recipe.getAllIngredients():

		if recipe.isTypeIngredient(ingredientDescriptor):

			var label = subject.ingredientLabelScene.instantiate()
			subject.add_child(label)
			var type = fusedItem.Type.keys()[ingredientDescriptor]
			label.translationKey = "INGREDIENT_" + type
			label.prefix = "   " + Util.getIcon(type.to_lower()) + " "
			label.updateLocale()

			actualWidth += label.size.x
			subject.addedItems.push_back(label)
			labelToTypeIngredient[label] = ingredientDescriptor
		else:
			var ingredient = subject.addItem(ingredientDescriptor, maxSize, tooltip)

			subject.addedItems.push_back(ingredient)
			var texSize = ingredient.getTextureSize()
			actualWidth += texSize.x

			if recipe.isDescriptorCatalyst(ingredientDescriptor):
				var hatching = ObjectPool.instantiate(subject.catalystHatchingScene)

				hatching.size = texSize / ingredient.scale + Vector2(10, 10)
				ingredient.add_child(hatching)
				subject.pooled.push_back(hatching)
				hatching.position = - hatching.size * 0.5
				hatching.position -= ingredient.getSpriteOffset() * 2

	var SHRINK_THRESHOLD = 100.0

	var spaceLeft = subject.maxWidth - (actualWidth + subject.MARGIN)
	var extraSpace = 0
	if spaceLeft > SHRINK_THRESHOLD:
		var shrinkFactor = (spaceLeft - SHRINK_THRESHOLD) / SHRINK_THRESHOLD
		extraSpace = min(shrinkFactor * 20, (spaceLeft - 50) / (subject.addedItems.size() - 1))

	var totalWidth = actualWidth + subject.MARGIN + extraSpace * (subject.addedItems.size() - 1)
	subject.custom_minimum_size.x = max(300, totalWidth)

	var numOwnedIngredients = 0

	var leftBorder = 0
	for ingredient in subject.addedItems:
		if ingredient is RichTextLabel:

			ingredient.position.y = subject.size.y * 0.4
			ingredient.position.x = leftBorder
			leftBorder += ingredient.size.x

			var hasCheckmark = false
			var type = labelToTypeIngredient[ingredient]
			for descriptor in subject.ownedCounter:
				if descriptor.hasType(type):
					var icon = ObjectPool.instantiate(subject.ownedIconScene)
					subject.pooled.push_back(icon)
					subject.add_child(icon)
					icon.position = Vector2(leftBorder, ingredient.position.y + 40)
					icon.scale = subject.ownedIconScale
					numOwnedIngredients += 1
					hasCheckmark = true
					break
			if not hasCheckmark:
				for descriptor in subject.shopCounter:
					if descriptor.hasType(type):
						var icon = ObjectPool.instantiate(subject.shopIconScene)
						subject.pooled.push_back(icon)
						subject.add_child(icon)
						icon.position = Vector2(leftBorder, ingredient.position.y + 40)
						icon.scale = subject.shopIconScale

		elif ingredient == subject.equals:

			ingredient.position.x = leftBorder
			leftBorder += ingredient.size.x

		elif ingredient is Control:
			ingredient.position.y = 0
			ingredient.position.x = leftBorder
			leftBorder += ingredient.size.x

		else:
			ingredient.position.y = subject.size.y * 0.5
			ingredient.position.x = leftBorder
			ingredient.position.x += ingredient.getTextureSize().x * 0.5
			ingredient.position += ingredient.getSpriteOffset() * 2.0
			leftBorder += ingredient.getTextureSize().x

			if ingredient.descriptor in subject.ownedCounter:
				var icon = ObjectPool.instantiate(subject.ownedIconScene)
				subject.pooled.push_back(icon)
				ingredient.add_child(icon)
				icon.position = (ingredient.getTextureSize() * 0.5) / ingredient.scale - Vector2(10, 10)
				icon.global_scale = subject.ownedIconScale
				Util.dictSub(subject.ownedCounter, ingredient.descriptor)
				if ingredient.descriptor != recipe.fusedItem:
					numOwnedIngredients += 1
			elif ingredient.descriptor in subject.shopCounter:
				var icon = ObjectPool.instantiate(subject.shopIconScene)
				subject.pooled.push_back(icon)
				ingredient.add_child(icon)
				icon.position = (ingredient.getTextureSize() * 0.5) / ingredient.scale - Vector2(10, 10)
				icon.scale = subject.shopIconScale
				Util.dictSub(subject.shopCounter, ingredient.descriptor)

		leftBorder += extraSpace

	subject.call_deferred("center", totalWidth)

	if numOwnedIngredients == recipe.getNumIngredients() + 1:
		subject.animation.play("CanCraft")

static func center(subject: Receiver, totalWidth):
	var offset = ((subject.size.x) - totalWidth) * 0.5
	for ingredient in subject.addedItems:
		if ingredient is Control:
			ingredient.position.x += offset
		else:
			ingredient.position.x += offset
