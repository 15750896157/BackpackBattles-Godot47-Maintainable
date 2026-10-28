extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Inventory/CraftingProgressLabel.gd")

static func showProgress(subject: Receiver, itemName: String, num: int, outOf: int, ingredientCounter: Array) -> void :
	subject.updateLabel(itemName, num, outOf, ingredientCounter)

	if num == 1:
		subject.animation.play("ShowFast")
	else:
		var speed = 1.0 if ingredientCounter.is_empty() else 0.8
		subject.animation.play("Show", - 1, speed)

static func updateLabel(subject: Receiver, itemName: String, num: int, outOf: int, ingredientCounter: Array):

	var color
	if num == outOf:
		color = subject.green.to_html()
	else:
		color = Color.WHITE.to_html()

	var bondedStr = ""
	var missingStr = ""

	for arr in ingredientCounter:
		missingStr += subject.bondedFormat.format({
			"name": arr[0].getTranslatedName(),
			"col": subject.yellow.to_html(),
			"num": arr[1],
			"outOf": arr[2],
			"icon": Util.imageToBbcode(subject.missingMark.get_path(), 30)
		})

	subject.label.text = subject.labelFormat.format({
		"col": color,
		"name": itemName,
		"num": num,
		"outOf": outOf,
		"bonded": bondedStr,
		"missing": missingStr})

	subject.animation.stop()
	subject.label.size.y = 0

static func fade(subject: Receiver):
	if (subject.animation.current_animation == "" or
		Util.getRemainingAnimationTime(subject.animation) > 0.3):
		subject.animation.stop()
		subject.animation.play("Fade")
