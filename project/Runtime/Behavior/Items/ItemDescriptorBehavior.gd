extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/ItemDescriptor.gd")

static func addNamedParam(subject: Receiver, paramName: String, paramVal):
	subject.namedParams[paramName] = paramVal
	var sortedPos = 0
	for i in subject.sortedParamNames.size():
		if subject.sortedParamNames[i].begins_with(paramName):
			sortedPos = i + 1
	subject.sortedParamNames.insert(sortedPos, paramName)
	subject.paramBases[paramName] = paramName.get_slice(subject.PARAM_DELIMITER, 0)
	subject.paramBases_inverted[subject.paramBases[paramName]] = paramName

static func calcClassAvailability(subject: Receiver):
	if subject.gateItem != null:
		if subject.gateItem.classes == subject.StuffedClasses.Undefined:
			Util.eprint(subject.getName(), " classes are undefined. ")

		if subject.classes == subject.StuffedClasses.None:
			subject.classes = subject.gateItem.classes

	if not subject.originatingRecipes.is_empty():
		if subject.classes == subject.StuffedClasses.Undefined:
			subject.classes = subject.StuffedClasses.None
		for recipe in subject.originatingRecipes:
			var recipeClasses = subject.StuffedClasses.Neutral
			for ingredient in recipe.getAllIngredients():
				if Util.isItemDescriptor(ingredient):
					if ingredient.classes == subject.StuffedClasses.Undefined:
						Util.eprint(subject.getName(), "classes are undefined due to ingredient ", ingredient.getName())

					recipeClasses &= ingredient.classes
			subject.classes |= recipeClasses

	if subject.classes == subject.StuffedClasses.Undefined:
		subject.classes = subject.StuffedClasses.None

static func getThresholdWeight(subject: Receiver, itemCounter: Dictionary) -> float:
	var thresholdFactor = 1.0
	var numOwned = itemCounter.get(subject, 0)
	if numOwned >= subject.getThreshold() + 3:
		thresholdFactor = 0.02
	elif numOwned >= subject.getThreshold() + 2:
		thresholdFactor = 0.1
	elif numOwned >= subject.getThreshold() + 1:
		thresholdFactor = 0.2
	elif numOwned >= subject.getThreshold():
		thresholdFactor = 0.4
	else:
		thresholdFactor = 1.0
	return thresholdFactor

static func getFlavorText(subject: Receiver) -> String:
	var texts = []
	for suffix in ["", "2", "3"]:
		var flavor = Util.tra_nbs(str(subject.descriptionKey, "_FLAVOR", suffix))
		if flavor != "" and flavor != ".":
			texts.push_back(flavor)

	if texts.is_empty():
		return ""
	else:
		return Util.pickRandomElement(texts)
