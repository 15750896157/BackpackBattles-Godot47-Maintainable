extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/Tooltip.gd")

static func align(subject: Receiver, toolPos: Vector2, toolSize: Vector2, alignment):
	if not subject.is_inside_tree(): return

	subject.global_position = toolPos + Vector2(toolSize.x + subject.MARGIN, subject.Y_OFFSET)

	var viewportRect = subject.get_viewport_rect()
	var cameraTopLeft = viewportRect.position
	var cameraBottomRight = viewportRect.end
	var rightMargin = subject.SCREEN_MARGIN.x
	if Game.itemLibrary.isOpen:
		rightMargin = 450

	if (subject.global_position.x + subject.size.x >= cameraBottomRight.x - rightMargin):
		subject.global_position.x = toolPos.x - subject.size.x - subject.MARGIN
		subject.global_position.x = max(subject.global_position.x, - 7)

	if alignment == subject.Alignment.Center:
		subject.global_position.y -= (subject.size.y - toolSize.y) / 2

	var highestRectY = cameraTopLeft.y + subject.SCREEN_MARGIN.y
	var lowestRectY = cameraBottomRight.y - subject.SCREEN_MARGIN.y - subject.size.y

	if (subject.global_position.y <= highestRectY):
		subject.global_position.y = highestRectY

	elif (subject.global_position.y >= lowestRectY):
		subject.global_position.y = lowestRectY

static func replaceReferences(subject: Receiver, text, iconSize):

	var iterations = 0
	var dollarPos = - 1
	while true:
		if iterations == 100:
			print("Endless loop, probably } missing")
			Util.eassert()
			break
		iterations += 1

		dollarPos = text.find("$", dollarPos + 1)
		if dollarPos == - 1:
			break

		var refEndPos = Util.findFirstNonLatinLetterOrNumber(text, dollarPos + 1)
		if refEndPos == - 1:
			refEndPos = text.length()
		var reference = text.substr(dollarPos + 1, refEndPos - dollarPos - 1)

		var img = ""
		if reference in Util.icons:
			img = Util.getIcon(reference, iconSize)
			text = subject.referenceImageFormat.format({
				"prefix": text.substr(0, dollarPos),
				"suffix": text.substr(refEndPos),
				"img": img
			})
			continue

		var replace = false
		var color = Util.paramColor_html
		var linebreaks = 0

		if reference in subject.keywords:
			replace = true

		elif reference in Util.getTypeEnum():
			replace = true

		elif reference == "h":
			replace = true

		elif reference == "t":
			replace = true
			color = subject.triggerColor_html
			if dollarPos != 0:
				linebreaks = 2

		elif reference == "m":
			replace = true
			color = subject.triggerColor_html

		elif reference == "t1":
			replace = true
			color = subject.triggerColor_html
			if dollarPos != 0:
				linebreaks = 1

		elif reference == "red":
			replace = true
			color = Util.red.to_html(false)

		elif reference.capitalize() in Util.getRarityEnum():
			var rarity = Util.getRarityEnum()[reference.capitalize()]
			replace = true
			color = Game.rarityColors[rarity].lightened(0.3).to_html(false)

		if replace:
			var replacement = ""
			for i in linebreaks:
				replacement += "\n"
			if linebreaks > 0:

				if text[refEndPos] == " ":
					refEndPos += 1

			if refEndPos < text.length() and text[refEndPos] == "[":

				var closingBracketPos = subject.findClosingBracket(text, refEndPos + 1)
				if not reference in Util.icons:
					replacement += Util.substr(text, refEndPos + 1, closingBracketPos - 1)

				refEndPos = closingBracketPos + 1

			text = subject.referenceTextFormat.format({
				"prefix": text.substr(0, dollarPos),
				"suffix": text.substr(refEndPos),
				"color": color,
				"length": replacement.length(),
				"replacement": replacement
			})

	return text

static func updateSize(subject: Receiver):

	var ySize = subject.vboxcontainer.size.y + subject.Y_BORDER
	subject.set_end(subject.position + Vector2(subject.size.x, 0))
	subject.set_end(subject.position + Vector2(subject.size.x, ySize))

static func findClosingBracket(inText: String, fromPos: int) -> int:
	var bracketCounter = 1
	for i in range(fromPos, inText.length()):
		if inText[i] == "[":
			bracketCounter += 1
		elif inText[i] == "]":
			bracketCounter -= 1
		if bracketCounter == 0:
			return i
	return - 1

static func highlight(text: String, wave, bold) -> String:
	var iterations = 0
	var dollarPos = - 1
	while true:
		if iterations == 100:
			print("Endless loop, probably } missing ", text)
			Util.eassert()
			break
		iterations += 1

		dollarPos = text.find("$h[", dollarPos + 1)
		if dollarPos == - 1:
			break

		var refStartPos = dollarPos + 3
		var closingBracketPos = Receiver.findClosingBracket(text, refStartPos)
		var reference = text.substr(refStartPos, closingBracketPos - refStartPos)

		var replacement = Util.wrapInColor(reference, Util.paramColor)
		if wave:
			replacement = str("[wave]", replacement, "[/wave]")
		if bold:
			replacement = str("[b]", replacement, "[/b]")

		text = Util.replaceSubstr(text, dollarPos, closingBracketPos, replacement)

	return text
