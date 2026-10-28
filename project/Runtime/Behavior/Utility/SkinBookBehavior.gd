extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/SkinBook.gd")

static func _ready(subject: Receiver):
	for classI in Game.getNumClasses():
		subject.skins.push_back([[], []])

	var table = Table.new().loadFromCsv("res://Sheets/CSV/SkinData.csv")

	var dir = LegacyDirectory.new()
	for line in table.countRows() - 1:
		var exclusive: bool = (table.getStr("demo", line) == "no")
		var className: String = table.getStr("class", line)
		var classI = Game.getClassEnum().get(className, - 1)

		if classI == - 1 or not Game.isClassUnlocked(classI):
			continue

		if exclusive and not Game.showExclusiveContent():
			continue

		var skin: CharacterSkin = CharacterSkin.new()
		skin.skinName = table.getStr("name", line)

		var isChibi: bool = table.isEqual("style", line, "chibi")
		var style: String = "Chibi" if isChibi else "Normal"

		var params = {
			"class": className,
			"style": style,
			"skin": skin.skinName
			}
		var scenePath: String = subject.scenePathFormat.format(params)

		skin.scene_path = scenePath

		var iconPath: String = subject.iconPathFormat.format(params)
		skin.icon_path = iconPath

		var hoveredIconPath: String = subject.hoveredIconPathFormat.format(params)
		skin.hovered_path = hoveredIconPath

		for slot in Game.SkinSlot:
			skin.prices[Game.SkinSlot[slot]] = table.getInt(slot, line)

		skin.id = table.getInt("id", line)
		skin.order = table.getInt("order", line)

		subject.skins[classI][int(isChibi)].push_back(skin)

static func getRandomSkinFor(subject: Receiver, classI, style, slot):
	var possibleSkins = []
	for skin in subject.skins[classI][style]:
		if skin.prices[slot] != - 1:
			possibleSkins.push_back(skin)

	return Util.pickRandomElement(possibleSkins)
