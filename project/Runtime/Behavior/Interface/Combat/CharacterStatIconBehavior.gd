extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Combat/CharacterStatIcon.gd")

static func setStat(subject: Receiver, _stat: int):
	subject.stat = _stat
	var statName = Character.Stat.keys()[subject.stat]
	subject.positiveKeyword = "STAT_" + statName
	subject.negativeKeyword = subject.positiveKeyword + "_NEGATIVE"
	var fileName = "res://Interface/Combat/StatIcons/" + statName
	subject.positiveTexture = load(fileName + ".png")
	Util.statIcons[subject.stat] = subject.positiveTexture
	if Util.sharedDirectory.file_exists(fileName + "_negative.png.import"):
		subject.negativeTexture = load(fileName + "_negative.png")
		Util.statIcons[ - subject.stat] = subject.negativeTexture
	subject.icon.texture = subject.positiveTexture
	subject.suffix = subject.suffixes.get(subject.stat, "")
	subject.hide()

static func updateLabel(subject: Receiver, value):
	if value > 0:
		subject.icon.keyword = subject.positiveKeyword
		subject.icon.texture = subject.positiveTexture
	else:
		subject.icon.keyword = subject.negativeKeyword
		subject.icon.texture = subject.negativeTexture

		if subject.stat in subject.removeMinus:
			value = abs(value)

	subject.label.text = str(snapped(value, 0.1)) + subject.suffix
	subject.icon.nameParams = {"val": Util.highlight(subject.label.text)}
