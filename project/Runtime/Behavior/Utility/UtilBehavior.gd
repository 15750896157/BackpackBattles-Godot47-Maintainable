extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Util.gd")

static func _ready(subject: Receiver):
	subject.get_window().set_title(ProjectSettings.get_setting("application/config/name"))
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	subject.rng.randomize()

	for icon in subject.icons:
		subject.iconTextures[icon] = load(subject.icons[icon])

	if not OS.has_feature("web"):

		subject.chineseFallbackFont = load("res://Assets/Fonts/Localized/ChineseFallbackFont.tres")
		subject.chineseFont1 = load("res://Assets/Fonts/Localized/NotoSansSC-Regular_.otf")
		subject.chineseFont2 = subject.chineseFont1
		subject.japaneseFallbackFont = subject.chineseFallbackFont
		subject.japaneseFont1 = subject.chineseFont1
		subject.japaneseFont2 = subject.chineseFont1
		subject.koreanFont1 = subject.chineseFont1
		subject.koreanFallbackFont = subject.chineseFallbackFont
		subject.traditionalChineseFont1 = subject.chineseFont1
		subject.russianFont1 = subject.chineseFont1
		subject.russianFont2 = subject.chineseFont1
		subject.russianFallbackFont = subject.chineseFallbackFont

	subject.prepareFonts()

	var reversed = subject.invertDictionary(ItemDescriptor.StuffedClasses)
	for classI in ItemDescriptor.StuffedClasses.values():
		if classI > 0 and classI < ItemDescriptor.StuffedClasses.Neutral:
			subject.uniqueTooltipTextures[classI] = load(str("res://Interface/Tooltips/TooltipBase_", reversed[classI], ".png"))
			subject.uniqueTooltipDivider[classI] = load(str("res://Interface/Tooltips/Divider_", reversed[classI], ".png"))
			subject.uniqueTooltipIcon[classI] = load(str("res://Interface/Tooltips/TooltipIcon_", reversed[classI], ".png"))
			if Game.isClassUnlockedStuffed(classI):
				subject.bannerGradients[classI] = load(str("res://CharacterClasses/", reversed[classI], "/BannerGradient.tres"))

	subject.uniqueTooltipTextures[ItemDescriptor.StuffedClasses.Neutral] = load("res://Interface/Tooltips/TooltipBase_Unique.png")
	subject.uniqueTooltipDivider[ItemDescriptor.StuffedClasses.Neutral] = load("res://Interface/Tooltips/Divider2_Unique.png")

static func prepareFonts(subject: Receiver):
	subject.damageNumberFonts.resize(201)

	var sizes = [60, 65, 70, 75, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200]
	for i in sizes.size():
		var size = sizes[i]
		var font = subject.baseDamageNumberFont.duplicate()
		font.size = size
		font.outline_size = size / 25.0 + 2.5
		subject.damageNumberFonts[size] = font
		var label = Label.new()
		label.add_to_group("NotLocalized")
		subject.add_child(label)
		label.set("theme_override_fonts/font", font)
		label.text = "-+1234567890"
		subject.callNextFrame(label, "queue_free")

		if i == sizes.size() - 1:
			break

		var nextSize = sizes[i + 1]
		for sizeI in range(size + 1, nextSize):
			subject.damageNumberFonts[sizeI] = font

static func eprint(subject: Receiver, text, arg1, arg2, arg3):
	if OS.has_feature("editor"):
		if arg3 != null:
			print("-", text, arg1, arg2, arg3)
		elif arg2 != null:
			print("-", text, arg1, arg2)
		elif arg1 != null:
			print("-", text, arg1)
		else:
			print("-", text)

static func addDirectoryContents(subject: Receiver, dir: LegacyDirectory, files: Array, directories: Array):
	var file_name = dir.get_next()

	while (file_name != ""):
		var path = dir.get_current_dir() + "/" + file_name

		if dir.current_is_dir():
			var subDir = LegacyDirectory.new()
			subDir.open(path)
			subDir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
			directories.append(path)
			subject.addDirectoryContents(subDir, files, directories)
		else:
			files.append(path)

		file_name = dir.get_next()

	dir.list_dir_end()

static func hasDLL(subject: Receiver, dllName) -> bool:
	if Game.EDITOR: return true
	var exePath = OS.get_executable_path()
	var exeDir = exePath.get_base_dir()
	var dir = LegacyDirectory.new()
	if dir.open(exeDir) == OK:
		if OS.has_feature("Windows"):
			return dir.file_exists(dllName + ".dll")
		elif OS.has_feature("X11"):
			return dir.file_exists(dllName + ".so")
	return false

static func removeDollarCommands(subject: Receiver, text: String) -> String:
	var iterations = 0
	var dollarPos = - 1
	while true:
		if iterations == 100:
			print("Endless loop, probably } missing ", text)
			subject.eassert()
			break
		iterations += 1

		dollarPos = text.find("$", 0)
		if dollarPos == - 1:
			break

		var refEndPos = subject.findFirstNonLatinLetterOrNumber(text, dollarPos + 1)
		var reference = text.substr(dollarPos + 1, refEndPos - dollarPos - 1)
		var replacement = ""

		if reference == "rage":
			pass

		if text[refEndPos] == "[":
			var closingBracketPos = ItemToolTip.findClosingBracket(text, refEndPos + 1)

			replacement += subject.substr(text, refEndPos + 1, closingBracketPos - 1)

			refEndPos = closingBracketPos + 1

		if reference in subject.icons and not reference in subject.iconsWithoutTranslation:
			var translated = subject.tra(reference + "_NAME")
			if translated == "":
				translated = subject.tra(str("TYPE_", reference.capitalize(), "_NAME"))
			if translated == "":
				translated = subject.tra(reference.capitalize() + "_NAME")

			replacement = str(translated, replacement)

		text = str(text.substr(0, dollarPos), replacement, text.substr(refEndPos))

	text = text.replace("\\~", "")
	text = text.replace("\n", "")
	text = text.replace("  ", " ")

	return text

static func loadSheetAsArray(subject: Receiver, filepath) -> Array:
	subject.file.open(filepath, subject.file.READ)
	var header = subject.file.get_csv_line()
	var arr = Array()
	while not subject.file.eof_reached():
		var line = subject.file.get_csv_line()
		if line.size() > 1:
			arr.append(line)
	subject.file.close()

	return [header, arr]

static func findFirstNonLatinLetterOrNumber(subject: Receiver, string: String, startIndex: int):
	for i in range(startIndex, string.length()):
		var ascii = ord(string[i])

		if string[i] == "[":
			return i
		if ( not (ascii >= 65 and ascii <= 122) and
			not (ascii >= 48 and ascii <= 57) and
			not (string[i] == "%")):

			return i
	return - 1

static func findHighlightEnd(subject: Receiver, string: String, startIndex: int):
	var length: int = string.length()
	for i in range(startIndex, length):
		var character = string[i]
		var ascii: int = ord(character)

		if character == "[":
			return i

		if character == subject.nonBreakingSpace or character == " ":
			if length > i:
				if string[i + 1] == "%":
					return i + 2

				var translatedSecond = subject.tra("FORMAT_Second")
				var secondLength: int = translatedSecond.length()
				if length < i + secondLength:
					return i
				for j in secondLength:

					if string[i + j + 1] != translatedSecond[j]:
						return i

				var candidateEnd = i + secondLength + 1
				if length > candidateEnd:
					if not string[candidateEnd] in [".", ",", ":", ";", "(", ")", " ", "?", "!", subject.nonBreakingSpace]:
						return i
				return candidateEnd

			return i

		if ( not (ascii >= 65 and ascii <= 122) and
			not (ascii >= 48 and ascii <= 57) and
			not (character == "%")):

			return i
	return length

static func laterOrEqual(subject: Receiver, saveStateVersion, breakingVersion) -> bool:
	var split1 = saveStateVersion.split(".")
	var split2 = breakingVersion.split(".")
	for i in split1.size():
		var number1 = int(split1[i])
		var number2 = int(split2[i])
		if number1 > number2:
			return true
		elif number1 < number2:
			return false

	return true

static func moveParable(subject: Receiver, tween: Tween, node, xMovement, yOffset, dur, phase1Factor):

	var phase1Dur = dur * phase1Factor
	var phase2Dur = dur - phase1Dur
	tween.set_parallel()

	tween.tween_property(node, "global_position:x",
		node.global_position.x + xMovement, dur)

	tween.tween_property(node, "global_position:y",
		node.global_position.y + yOffset, phase1Dur
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(node, "global_position:y",
		node.global_position.y, phase2Dur
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN
		).from(node.global_position.y + yOffset).set_delay(phase1Dur)

static func hashDictionary(subject: Receiver, dict: Dictionary) -> int:
	var keys: Array = dict.keys()
	keys.sort()
	var hashingContext = HashingContext.new()
	hashingContext.start(HashingContext.HASH_MD5)

	for key in keys:
		hashingContext.update(var_to_bytes(dict[key]))

	var hash_long = hashingContext.finish()

	var streamPeer = StreamPeerBuffer.new()
	streamPeer.put_data(hash_long)

	streamPeer.seek(0)

	return streamPeer.get_64()

static func spawnLabelOnItem(subject: Receiver, type: int, item, amount):
	if not is_instance_valid(item):
		print("spawnLabelOnItem null ", Util.enumToString(Game.EventType, type))
		return

	var buffLabel = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	var pos = item.getNextFreeLabelPosition()
	buffLabel.position = pos
	Game.UINode.add_child(buffLabel)
	buffLabel.linear_velocity = Vector2(0, - 75)
	buffLabel.spawnLabelOnItem(type, amount)

static func spawnStatLabelOnItem(subject: Receiver, stat: int, item, amount, onOpponent):
	if amount == 0: return

	if not is_instance_valid(item):
		print("spawnStatLabelOnItem null ", Util.enumToString(Character.Stat, stat))
		return

	var buffLabel = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	var pos = item.getNextFreeLabelPosition()
	buffLabel.position = pos
	Game.UINode.add_child(buffLabel)
	buffLabel.linear_velocity = Vector2(0, - 75)
	buffLabel.spawnStatLabelOnItem(stat, amount, onOpponent)

static func spawnBuffLabel_item(subject: Receiver, type: int, item, amount, appliedToOpponent: bool):
	if not Settings.getVal(Settings.Setting.buff_labels): return

	var buffLabel = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	var pos = item.getNextFreeLabelPosition()
	buffLabel.position = pos
	Game.UINode.add_child(buffLabel)
	buffLabel.linear_velocity = Vector2(0, - 75)
	buffLabel.spawnLabel(type, amount, buffLabel.ChangeType.Gain, appliedToOpponent)

static func localizeFonts(subject: Receiver, node):
	if not is_instance_valid(node):
		return

	# Modern Controls carry FontFile/FontVariation resources and theme font sizes.
	# Only recovered DynamicFont adapters have the mutable size/font_data API.
	if node.get_class() in subject.localizedTypes and subject.getNormalFont(node) is LegacyFont:

		if node.is_in_group("NotLocalized"):
			return

		if not node in subject.defaultFonts:

			var fontData = FontData.new()
			subject.defaultFonts[node] = fontData

			fontData.setFont(subject.getNormalFont(node))
			fontData.setBoldFont(subject.getBoldFont(node))

		var locale = TranslationServer.get_locale()
		var defaultFontData: FontData = subject.defaultFonts[node]
		if defaultFontData.curLocale != locale:
			defaultFontData.curLocale = locale

			subject.setCorrespondingFont(node, defaultFontData)

	for child in node.get_children():
		subject.localizeFonts(child)

static func setCorrespondingFont(subject: Receiver, node, defaultFontData: FontData):
	var locale = TranslationServer.get_locale()

	var replaceNormal = false
	var replaceBold = false
	var normalFont = subject.getNormalFont(node)
	var boldFont = subject.getBoldFont(node)

	if locale == "zh_Hans_CN":
		if normalFont:
			replaceNormal = not subject.isSimplifiedChinese(normalFont)
		if boldFont:
			replaceBold = not subject.isSimplifiedChinese(boldFont)
	elif locale == "zh_Hant_TW":
		if normalFont:
			replaceNormal = not subject.isTraditionalChinese(normalFont)
		if boldFont:
			replaceBold = not subject.isTraditionalChinese(boldFont)
	elif locale == "ja":
		if normalFont:
			replaceNormal = not subject.isJapanese(normalFont)
		if boldFont:
			replaceBold = not subject.isJapanese(boldFont)
	elif locale == "ko":
		if normalFont:
			replaceNormal = not subject.isKorean(normalFont)
		if boldFont:
			replaceBold = not subject.isKorean(boldFont)
	elif locale == "ru":
		if normalFont:
			replaceNormal = not subject.isRussian(normalFont)
		if boldFont:
			replaceBold = not subject.isRussian(boldFont)
	else:
		if normalFont:
			replaceNormal = not subject.isDefaultFont(normalFont) or normalFont.size != defaultFontData.size
		if boldFont:
			replaceBold = not subject.isDefaultFont(boldFont) or boldFont.size != defaultFontData.bold_size

	if not replaceNormal and not replaceBold: return

	if replaceNormal:
		normalFont = normalFont.duplicate()
		defaultFontData.applyToFont(normalFont)
		subject.setNormalFont(node, normalFont)

	if replaceBold:
		boldFont = boldFont.duplicate()
		defaultFontData.applyToBoldFont(boldFont)
		subject.setBoldFont(node, boldFont)

	if locale == "zh_Hans_CN":
		if replaceNormal:
			subject.makeSimplifiedChinese(normalFont)
		if replaceBold:
			subject.makeSimplifiedChinese(boldFont)
	elif locale == "zh_Hant_TW":
		if replaceNormal:
			subject.makeTraditionalChinese(normalFont)
		if replaceBold:
			subject.makeTraditionalChinese(boldFont)
	elif locale == "ja":
		if replaceNormal:
			subject.makeJapanese(normalFont)
		if replaceBold:
			subject.makeJapanese(boldFont)
	elif locale == "ko":
		if replaceNormal:
			subject.makeKorean(normalFont)
		if replaceBold:
			subject.makeKorean(boldFont)
	elif locale == "ru":
		if replaceNormal:
			subject.makeRussian(normalFont)
		if replaceBold:
			subject.makeRussian(boldFont)

	if replaceNormal:
		normalFont.update_changes()
	if replaceBold:
		boldFont.update_changes()

static func logSteamDeck(subject: Receiver, arg1, arg2, arg3, arg4):
	if not SteamHelper.STEAMDECK or not Game.PLAYTEST: return
	var text = str(arg1)
	if arg2 != null:
		text += str(arg2)
	if arg3 != null:
		text += str(arg3)
	if arg4 != null:
		text += str(arg4)

	print(text)

static func getTextForEvent(subject: Receiver, event, translate: bool) -> String:
	if event is InputEventKey:

		var text = event.as_text()
		if text.length() > 1:
			var keycode
			if event.physical_keycode != 0:
				keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
			else:
				keycode = event.keycode

			var translationKey = "KEY_" + OS.get_keycode_string(keycode)
			var t = subject.tra(translationKey)
			if t == "":
				t = OS.get_keycode_string(keycode)
				if event.ctrl_pressed:
					t = str(subject.tra("KEY_Control"), "+", t)
				return t
			else:
				if translate:
					if event.ctrl_pressed:
						t = str(subject.tra("KEY_Control"), "+", t)
					return t
				else:
					return translationKey
		else:
			if text == " ":
				if translate:
					return subject.tra("KEY_Space")
				else:
					return "KEY_Space"
			elif text.length() == 1:
				return text.capitalize()

	elif event is InputEventMouseButton:
		if event.button_index in Util.mouseButtons:
			return Util.mouseButtons[event.button_index]

	return ""

static func openLocalLink(subject: Receiver, url: String) -> Error:
	if ("wiki" in url or "backpackBattles?" in url) and is_instance_valid(Game.itemLibrary):
		Game.itemLibrary.open()
	else:
		var chinese = TranslationServer.get_locale().begins_with("zh")
		var message = "本地模式：账户、成就、排行榜、对手、房间与创意工坊内容均保存在本机。物品与配方请查看游戏内物品图鉴。" if chinese else "Local mode: profile, achievements, leaderboards, opponents, rooms and workshop are saved on this computer. Use the in-game item library for items and recipes."
		var local_translation = Translation.new()
		local_translation.locale = TranslationServer.get_locale()
		local_translation.add_message("LOCAL_MODE_INFO", message)
		TranslationServer.add_translation(local_translation)
		subject.translationCache.erase("LOCAL_MODE_INFO")
		subject.showPopupMessage("LOCAL_MODE_INFO", null, 6.0)
	return OK
