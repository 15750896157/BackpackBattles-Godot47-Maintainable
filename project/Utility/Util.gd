extends Node2D

const DataOps = preload("res://Runtime/Collections/SequenceOps.gd")

var frameCounter = 0
var time = 0.0
var clockTime = 0.0
var rng = RandomNumberGenerator.new()
var file = File.new()
var translationCache = {}
var sharedBitstream = BitStream.new()
var sharedDirectory = LegacyDirectory.new()
var mouseVelocity: Vector2
var lastMousePos: Vector2

const paramColor = Color(1, 0.890196, 0.219608)
var paramColor_html = paramColor.to_html(false)
const modifiedColor = Color(0.544922, 1, 0.562698)
const negativeColor = Color(1, 0.7052, 0.34375)
const inactiveColor = Color.GRAY
const triggerColor = Color(0.935547, 0.783836, 0.579235)
const red = Color(0.988281, 0.55661, 0.449219)

var statColors = [
	paramColor,
	modifiedColor,
	negativeColor
]

const weaponIcons = {
	Item.Stat.MaxDamage: preload("res://Interface/Tooltips/Icon_Damage.png"),
	Item.Stat.Accuracy: preload("res://Interface/Tooltips/Icon_Accuracy.png"),
	Item.Stat.Cooldown: preload("res://Interface/Tooltips/Icon_Cooldown.png"),
	Item.Stat.StaminaCost: preload("res://Interface/Tooltips/Icon_Stamina.png"),
	Item.Stat.CritChance: preload("res://Interface/Tooltips/Icon_CritChance.png")
}

var statIcons: Dictionary

var bannerGradients: Dictionary
var uniqueTooltipTextures: Dictionary
var uniqueTooltipDivider: Dictionary
var uniqueTooltipIcon: Dictionary

var defaultFonts = Dictionary()

@onready var popupMessageScene = load("res://Interface/PopupMessage.tscn")

@onready var zapScene = load("res://Items/Animations/Zap.tscn")

const baskervilleRegular = preload("res://Assets/Fonts/LibreBaskerville-Regular.ttf")
const baskervilleBold = preload("res://Assets/Fonts/LibreBaskerville-Bold.ttf")
const milonga = preload("res://Assets/Fonts/Milonga-Regular.ttf")
const glassAniqua = preload("res://Assets/Fonts/GlassAntiqua-Regular.ttf")

const latinFonts = [baskervilleBold, baskervilleRegular, milonga, glassAniqua]

var chineseFallbackFont
var chineseFont1
var chineseFont2
var japaneseFallbackFont
var japaneseFont1
var japaneseFont2
var koreanFallbackFont
var koreanFont1
var traditionalChineseFont1

var russianFont1
var russianFont2
var russianFallbackFont

func _ready():
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd")._ready(self)

var damageNumberFonts: Array
const baseDamageNumberFont: LegacyFont = preload("res://Interface/DamageNumbers/DamageNumberBaseFont.tres")

func prepareFonts():
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").prepareFonts(self)

func _process(delta):
	clockTime += delta

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd")._physics_process(self, delta)

func getMouseSpeed() -> float:
	return mouseVelocity.length()

func getFrameCounter_process():
	return Engine.get_physics_frames()

func angleDif(angle1, angle2):
	var angle = abs(angle1 - angle2)
	if angle > 180.0:
		return 360.0 - angle
	return angle

func rotDif(rot1, rot2):
	var rot = abs(rot1 - rot2)
	if rot > PI:
		return 2 * PI - rot
	return rot

func randInBox(xRange, yRange) -> Vector2:
	return Vector2(rng.randf_range( - xRange, xRange), rng.randf_range( - yRange, yRange))

func randInCircle(radius: float) -> Vector2:
	return Vector2(rng.randf_range(0, radius), 0).rotated(rng.randf_range(0, 2 * PI))

var debugOnlyCounter = 0

func debugOnly(val = true):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").debugOnly(self, val)

func eprint(text, arg1 = null, arg2 = null, arg3 = null):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").eprint(self, text, arg1, arg2, arg3)

func eassert(toTest: bool = false):
	if OS.has_feature("editor"):
		assert (toTest)

func tra(key: String) -> String:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").tra(self, key)

func updateLocale():
	updateAllFonts()
	translationCache.clear()

func updateLocaleInSubtree(node):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").updateLocaleInSubtree(self, node)

const nonBreakingSpace = " "
const zeroWidthSpace = "​"

func tr_nbs(key: String) -> String:
	return tr(key)

func tra_nbs(key: String) -> String:
	return tra(key)

func equals(val1, val2) -> bool:
	return typeof(val1) == typeof(val2) and val1 == val2

func addSign(numberVal) -> String:
	if numberVal > 0:
		return "+" + str(numberVal)
	else:
		return str(numberVal)

func addPlus(numberVal) -> String:
	if numberVal >= 0:
		return "+" + str(numberVal)
	else:
		return str(numberVal)

func toBinary(intValue: int) -> String:
	var bin_str: String = ""
	while intValue > 0:
		bin_str = str(intValue & 1) + bin_str
		intValue = intValue >> 1
	return bin_str

func countOnes(num, maxBits = 64) -> int:
	var numOnes = 0
	for i in maxBits:
		if num & (1 << i) > 0:
			numOnes += 1
	return numOnes

func bitIncludes(doesBin1, includeBin2):
	return ( ~ doesBin1 & includeBin2) == 0

func addDirectoryContents(dir: LegacyDirectory, files: Array, directories: Array):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").addDirectoryContents(self, dir, files, directories)

func writeVarToFile(filePath, content):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").writeVarToFile(self, filePath, content)

func writeVarToFile_simple(filePath, content):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").writeVarToFile_simple(self, filePath, content)

func hasDLL(dllName) -> bool:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").hasDLL(self, dllName)

func generateRandomString(length) -> String:
	var string = ""
	for i in length:
		string += char(rng.randi_range(35, 126))

	return string

const colorFormat = "[color=#{col}]{text}[/color]"

const smartColorFormat = "[sc len={length} color=#{col}]{text}[/sc]"

func highlight(text) -> String:
	return wrapInColor(str(text), paramColor)

var wrapDict = {"col": "", "text": ""}
func wrapInColor(text: String, color: Color) -> String:
	return colorFormat.format({
		"col": color.to_html(false),
		"text": text
	})

func wrapInColor_html(text, color: String) -> String:
	wrapDict["col"] = color
	wrapDict["text"] = text
	return colorFormat.format(wrapDict)

func wrapInColor_fixed(text: String, color: Color) -> String:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").wrapInColor_fixed(self, text, color)

func removeDollarCommands(text: String) -> String:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").removeDollarCommands(self, text)

func longTo2Ints(long: int) -> PackedInt32Array:
	return DataOps.split_i64(long)

func twoIntsToLong(arr: PackedInt32Array) -> int:
	return DataOps.join_i64(arr)

func absv(vec: Vector2):
	return Vector2(abs(vec.x), abs(vec.y))

func pickRandomElement(array: Array):
	return array[rng.randi_range(0, array.size() - 1)]

func getArrayElement(array: Array, index: int, default = null):
	return DataOps.lookup(array, index, default)

func nDimArrayGet(array: Array, indices: Array, default = null):
	return DataOps.nested_value(array, indices, default)

func findAll(array: Array, value) -> Array:
	return DataOps.positions(array, value)

func log2(number):
	return log(number) / log(2)

func loadSheetAsArray(filepath) -> Array:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").loadSheetAsArray(self, filepath)

func filterDuplicates(arr: Array) -> Array:
	return DataOps.distinct(arr)

func hasDuplicates(arr: Array) -> bool:
	return DataOps.has_duplicates(arr)

func countDuplicates(arr: Array) -> int:
	return DataOps.duplicate_count(arr)

func filterNull(arr: Array) -> Array:
	return DataOps.non_null(arr)

func subtractArr(a: Array, b: Array) -> Array:
	return DataOps.multiset_difference(a, b)

func subtractDictFromArray(a: Array, b: Dictionary) -> Array:
	return DataOps.reject_keys(a, b)

func findFirstOf(string: String, stringsToFind: Array, startIndex: int = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").findFirstOf(self, string, stringsToFind, startIndex)

func isLatinLetterOrNumber(character: String):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isLatinLetterOrNumber(self, character)

func isNonLatinLetterOrNumber(string: String):
	if string == "[":
		return true

	if (string == "%"):
		return false

	return not isLatinLetterOrNumber(string)

func findFirstNonLatinLetterOrNumber(string: String, startIndex: int = 0):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").findFirstNonLatinLetterOrNumber(self, string, startIndex)

func findHighlightEnd(string: String, startIndex: int = 0):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").findHighlightEnd(self, string, startIndex)

func findWholeWord(text, searchTerm):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").findWholeWord(self, text, searchTerm)

func substr(string: String, from: int, to: int):
	return string.substr(from, to - from + 1)

func replaceSubstr(string: String, from: int, to: int, replacement: String):
	var newString = string.substr(0, from)
	newString += replacement
	newString += string.substr(to + 1)
	return newString

func later(version, thanVersion) -> bool:
	if version == thanVersion:
		return false
	return laterOrEqual(version, thanVersion)

func laterOrEqual(saveStateVersion, breakingVersion) -> bool:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").laterOrEqual(self, saveStateVersion, breakingVersion)

func randRange(from: float, to: float) -> float:
	return rng.randf_range(from, to)

func randPitch(variation = 0.05) -> float:
	return rng.randf_range(1 - variation, 1 + variation)

const mouseButtons = {
	MOUSE_BUTTON_LEFT: "MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: "MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "MOUSE_MIDDLE",
	MOUSE_BUTTON_WHEEL_UP: "MOUSE_WHEEL",

	MOUSE_BUTTON_XBUTTON1: "MOUSE4",
	MOUSE_BUTTON_XBUTTON2: "MOUSE5",

}

@onready var mouseButtonsInverted = invertDictionary(mouseButtons)

func connectIfExists(emitter, signalName, listener, methodname, binds = [], flags = 0):
	if listener.has_method(methodname):
		emitter.connect(signalName, Callable(listener, methodname).bindv(binds), flags)

func tryConnect(emitter, signalName, listener, methodname, binds = [], flags = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").tryConnect(self, emitter, signalName, listener, methodname, binds, flags)

func tryDisconnect(emitter, signalName, listener, methodname):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").tryDisconnect(self, emitter, signalName, listener, methodname)

func setConnected(connected: bool, emitter, signalName, listener, methodname):
	if connected:
		tryConnect(emitter, signalName, listener, methodname)
	else:
		tryDisconnect(emitter, signalName, listener, methodname)

func setDelayed(target, propertyName, value, delay):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").setDelayed(self, target, propertyName, value, delay)

func setDelayed_process(target, propertyName, delay, value):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").setDelayed_process(self, target, propertyName, delay, value)

func callDelayed(target, methodName, delay, binds = []):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").callDelayed(self, target, methodName, delay, binds)

func callDelayed_process(target, methodName, delay, binds = []):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").callDelayed_process(self, target, methodName, delay, binds)

func callNextFrame(target, methodName, arguments = []):
	get_tree().connect("process_frame", Callable(target, methodName).bindv(arguments), CONNECT_ONE_SHOT)

func finishTimer(timer: Timer):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").finishTimer(self, timer)

func isTweenRunning(tween: Tween):
	return is_instance_valid(tween) and tween.is_valid()

func killTween(tween: Tween):
	if is_instance_valid(tween):
		tween.kill()

func finishTween(tween: Tween):
	if isTweenRunning(tween):
		tween.custom_step(10000)

func refreshTween(tween: Tween) -> Tween:
	killTween(tween)
	return create_tween()

func ensureTween(tween: Tween) -> Tween:
	if not isTweenRunning(tween):
		return refreshTween(tween)
	return tween

func tweenMethodCurve(tween: Tween, node: Node, methodName: String,
	fromVal, toVal, duration: float, curve: Curve):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").tweenMethodCurve(self, tween, node, methodName, fromVal, toVal, duration, curve)

func isChristmas() -> bool:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isChristmas(self)

func lerpPosCurve(interpolationPoint: float, node, methodName, fromVal, toVal, curve: Curve):
	var eased = curve.sample_baked(interpolationPoint)
	var val = lerp(fromVal, toVal, eased)
	node.call(methodName, val)

func moveParable(tween: Tween, node, xMovement, yOffset,
	dur, phase1Factor = 0.5):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").moveParable(self, tween, node, xMovement, yOffset, dur, phase1Factor)

func grabFocus(control):
	if Game.usingController:
		control.grab_focus()

func releaseFocus(control):
	if Game.usingController:
		control.release_focus()

func invertDictionary(dict: Dictionary) -> Dictionary:
	return DataOps.inverted(dict)

func arrayAsIndexDict(array: Array) -> Dictionary:
	var invertedDict = Dictionary()
	for i in array.size():
		invertedDict[array[i]] = i
	return invertedDict

func hashDictionary(dict: Dictionary) -> int:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").hashDictionary(self, dict)

func reparentNode(node, newParent):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").reparentNode(self, node, newParent)

func getGlobalZ(target: Node2D) -> int:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").getGlobalZ(self, target)

@onready var NUMBERLABEL_SCENE = load("res://Interface/DamageNumbers/DamageNumber.tscn")
@onready var BUFFLABEL_SCENE = load("res://Interface/DamageNumbers/BuffLabel.tscn")

func randBuffLabelDir() -> Vector2:
	return Vector2(0, rng.randf_range( - 75, - 120))

func spawnNumberLabel(type: int, globalPosition: Vector2,
	direction: Vector2, amount: int = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnNumberLabel(self, type, globalPosition, direction, amount)

func spawnLabelOnItem(type: int, item, amount):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").spawnLabelOnItem(self, type, item, amount)

func spawnStatLabelOnItem(stat: int, item, amount, onOpponent = false):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").spawnStatLabelOnItem(self, stat, item, amount, onOpponent)

func spawnBuffLabel(type: int, globalPosition: Vector2, amount = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnBuffLabel(self, type, globalPosition, amount)

func spawnBuffLabel_item(type: int, item, amount, appliedToOpponent: bool):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").spawnBuffLabel_item(self, type, item, amount, appliedToOpponent)

func spawnMissLabel(globalPosition: Vector2, direction: Vector2):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnMissLabel(self, globalPosition, direction)

func spawnResistedLabel(type: int, globalPosition: Vector2, amount = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnResistedLabel(self, type, globalPosition, amount)

func spawnProtectedLabel(type: int, globalPosition: Vector2, amount = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnProtectedLabel(self, type, globalPosition, amount)

func spawnReflectLabel(type: int, globalPosition: Vector2, amount = 0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").spawnReflectLabel(self, type, globalPosition, amount)

func dictAdd(dict: Dictionary, key, val = 1, base = 0) -> int:
	return DataOps.accumulate(dict, key, val, base)

func dictSub(dict: Dictionary, key, val = 1) -> int:
	return DataOps.subtract(dict, key, val)

func dictAddDict(dict1: Dictionary, dict2: Dictionary) -> void :
	DataOps.merge_counts(dict1, dict2)

func dictAppend(dict: Dictionary, key, value) -> void :
	DataOps.bucket_append(dict, key, value)

func dictErase(dict: Dictionary, key, valueToErase) -> void :
	DataOps.bucket_erase(dict, key, valueToErase)

func dictPop(dict: Dictionary, key):
	return DataOps.bucket_pop(dict, key)

func flatten(arr: Array) -> Array:
	return DataOps.flatten_once(arr)

func roll(maximum = 100.0) -> float:
	return rng.randf_range(0, maximum)

func flip(chance = 0.5) -> bool:
	return rng.randf() <= chance

func flipPercent(chance) -> bool:
	return roll() <= chance

func flipRound(chance) -> int:
	return int(floor(chance) + int(flip(fmod(chance, 1.0))))

func flipWeighted(weights: Array) -> int:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").flipWeighted(self, weights)

func isBetween(number, leftBorder, rightBorder) -> bool:
	return number > leftBorder and number < rightBorder

func floorStepify(value: float, step: float) -> float:
	return snapped(value - 0.5 * step + 1e-05, step)

func unset(binaryVar, flag):
	return binaryVar & ~ flag

func disconnectAll(object):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").disconnectAll(self, object)

func disconnectSignal(object, signalName: String):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").disconnectSignal(self, object, signalName)

func getRemainingAnimationTime(animation: AnimationPlayer) -> float:
	var remainingTime = 0.0
	if animation.is_playing():
		remainingTime = animation.current_animation_length - animation.current_animation_position
	return remainingTime

func stretchSpriteToWidth(sprite, widthInPixels: float):
	var currentSize = sprite.texture.get_size().x
	sprite.scale.x = widthInPixels / currentSize

func clampToRect(pos: Vector2, rect: Rect2) -> Vector2:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").clampToRect(self, pos, rect)

func getMousePosInWindow() -> Vector2:
	return clampToScreen(get_global_mouse_position())

func clampToScreen(pos: Vector2) -> Vector2:
	var rect = get_viewport_rect()
	return clampToRect(pos, rect)

func enumToString(enu: Dictionary, value: int) -> String:
	var inverted = invertDictionary(enu)
	return inverted[value]

const iconSizes = {
	"spikes": 25,
	"vampirism": 23,
	"poison": 28,
	"regen": 28,
	"bl": 28,
	"lucky": 28,
	"blind": 25,
	"mana": 28,
	"gold": 30,
	"heat": 28,
	"cold": 28,
	"empower": 28,
	"affected3": 30,
	"affected2": 30,
	"affected": 30,
	"empty": 30
}

const icons = {
	"gold": "res://Assets/GoldCoin2.png",
	"affected3": "res://Assets/Tertiary_icon.png",
	"affected2": "res://Assets/SecondaryStar_icon.png",
	"affected": "res://Assets/Star.png",
	"empty": "res://Assets/EmptyStar.png",
	"spikes": "res://Interface/Tooltips/Icon_Spikes.png",
	"vampirism": "res://Interface/Tooltips/Icon_Vampirism.png",
	"poison": "res://Interface/Tooltips/Icon_Poison.png",
	"regen": "res://Interface/Tooltips/Icon_Regeneration.png",
	"bl": "res://Interface/Tooltips/Icon_Block.png",
	"lucky": "res://Interface/Tooltips/Icon_Lucky.png",
	"blind": "res://Interface/Tooltips/Icon_Blind.png",
	"mana": "res://Interface/Tooltips/Icon_Mana.png",
	"heat": "res://Interface/Tooltips/Icon_Heat.png",
	"cold": "res://Interface/Tooltips/Icon_Cold.png",
	"empower": "res://Interface/Tooltips/Icon_Empower.png",
	"melee": "res://Interface/Tooltips/Icon_Melee.png",
	"ranged": "res://Interface/Tooltips/Icon_Ranged.png",
	"effect": "res://Interface/Tooltips/Icon_Effect.png",
	"dark": "res://Interface/Tooltips/Icon_Dark.png",
	"holy": "res://Interface/Tooltips/Icon_Holy.png",
	"nature": "res://Interface/Tooltips/Icon_Nature.png",
	"vampiric": "res://Interface/Tooltips/Icon_Vampiric.png",
	"fire": "res://Interface/Tooltips/Icon_Fire.png",
	"ice": "res://Interface/Tooltips/Icon_Ice.png",
	"magic": "res://Interface/Tooltips/Icon_Magic.png",
	"treasure": "res://Interface/Tooltips/Icon_Treasure.png",
	"musical": "res://Interface/Tooltips/Icon_Musical.png",
	"lightning": "res://Assets/Icon_Lightning.png",

	"engineer": "res://Assets/TitleScreen/EngineerIcon.png"
}

const iconsWithoutTranslation = {
	"affected": true, "affected2": true, "affected3": true
}

var iconTextures: Dictionary

const imgFormat = "[i][img=0x{0}]{1}[/img][/i]"

func getIcon(keyword, size = null):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").getIcon(self, keyword, size)

func imageToBbcode(pathToImage: String, size: int) -> String:
	return imgFormat.format([size, pathToImage])

func getControllerIconBbcode(action, size: int = 40):
	var icon = ControllerIcons.getIconFromAction(action)
	return imageToBbcode(icon, size)

func getIconTexture(keyword):
	if not icons.has(keyword): return null
	return load(icons[keyword])

func getAllChildren(node) -> Array:
	var arr = []
	walkChildren(node, arr)
	return arr

func walkChildren(node, arr):
	for child in node.get_children():
		arr.push_back(child)
		walkChildren(child, arr)

func removeLocalizedNode(node):
	defaultFonts.erase(node)
	for child in node.get_children():
		removeLocalizedNode(child)

func updateAllFonts():
	localizeFonts(get_tree().get_root())

const localizedTypes = {
	"Label": true,
	"Button": true,
	"CheckBox": true,
	"RichTextLabel": true,
	"LineEdit": true,
	"ItemList": true
}

func localizeFonts(node):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").localizeFonts(self, node)

func setCorrespondingFont(node, defaultFontData: FontData):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").setCorrespondingFont(self, node, defaultFontData)

func isDefaultFont(font: LegacyFont):
	return font.font_data in latinFonts

func makeSimplifiedChinese(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").makeSimplifiedChinese(self, font)

func isSimplifiedChinese(font: LegacyFont):
	return font.font_data == chineseFont1 or font.font_data == chineseFont2

func makeTraditionalChinese(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").makeTraditionalChinese(self, font)

func isTraditionalChinese(font: LegacyFont):
	return font.font_data == traditionalChineseFont1 or font.font_data == chineseFont2

func makeJapanese(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").makeJapanese(self, font)

func isJapanese(font: LegacyFont):
	return font.font_data == japaneseFont1 or font.font_data == japaneseFont2

func makeKorean(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").makeKorean(self, font)

func isKorean(font: LegacyFont):
	return font.font_data == koreanFont1

func isRussian(font: LegacyFont):
	return font.font_data == russianFont1 or font.font_data == russianFont2

func makeRussian(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").makeRussian(self, font)

func getSizedFont(font: LegacyFont, sizeChange: int) -> LegacyFont:
	var newFont = font.duplicate()
	newFont.size += sizeChange
	return newFont

func isControlWithSingleFont(node):
	return node is Label or node is Button or node is LineEdit or node is ItemList

func getNormalFont(node):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").getNormalFont(self, node)

func getBoldFont(node):
	return node.get("theme_override_fonts/bold_font")

func setNormalFont(node, font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").setNormalFont(self, node, font)

func setBoldFont(node, font: LegacyFont):
	node.set("theme_override_fonts/bold_font", font)

func addFallbackFonts(font: LegacyFont):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").addFallbackFonts(self, font)

func hasSpaceBeforePercent() -> bool:
	return TranslationServer.get_locale() in ["fr", "es"]

func hasSpaceBeforeSeconds() -> bool:
	return TranslationServer.get_locale() in ["fr", "pt_BR", "es"]

func createPulse(pulseScene, item, pos):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").createPulse(self, pulseScene, item, pos)

func isItem(object) -> bool:
	return object is Item

func isItemDescriptor(object) -> bool:
	return object is ItemDescriptor

func isBag(object) -> bool:
	return object is Bag

func getRarityEnum():
	return Item.Rarity

func getTypeEnum():
	return Item.Type

func getNodesForAllClasses(parent, pathFormat):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").getNodesForAllClasses(self, parent, pathFormat)

var console = null

func logSteamDeck(arg1, arg2 = null, arg3 = null, arg4 = null):
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").logSteamDeck(self, arg1, arg2, arg3, arg4)

func showScreenKeyboard(lineEdit: LineEdit):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").showScreenKeyboard(self, lineEdit)

func isActionPressed(actionName: String, checkController: bool = true) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isActionPressed(self, actionName, checkController)

func isActionJustPressed(actionName: String, checkController: bool = true) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isActionJustPressed(self, actionName, checkController)

func isAction_event(event: InputEvent, actionName: String) -> bool:
	return (event.is_action(actionName) or
			event.is_action(actionName + "_controller"))

func isActionPressed_event(event: InputEvent, actionName: String) -> bool:
	return (event.is_action_pressed(actionName) or
			event.is_action_pressed(actionName + "_controller"))

func isActionReleased_event(event: InputEvent, actionName: String) -> bool:
	return (event.is_action_released(actionName) or
			event.is_action_released(actionName + "_controller"))

func isClickEvent(event: InputEvent) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isClickEvent(self, event)

func isClickReleaseEvent(event: InputEvent) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").isClickReleaseEvent(self, event)

func isRightClickReleaseEvent(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_RIGHT and
		not event.is_pressed())

func isRightClick(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and
	event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT)

func isKeyOrJoyButton(event: InputEvent) -> bool:
	return (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion)

func sendAction(action: String, pressed: bool):
	var a = InputEventAction.new()
	a.action = action
	a.pressed = pressed
	Input.parse_input_event(a)

func getTextForEvent(event, translate: bool) -> String:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").getTextForEvent(self, event, translate)

func changeTimer(timer: Timer, t: float):
	var timeLeft = timer.get_time_left()
	timer.start(t + timeLeft)

func showPopupMessage(translationKey, formatParams = null, duration = 3.0):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").showPopupMessage(self, translationKey, formatParams, duration)

func sortDict(dict: Dictionary, shuffleBeforeSort = false) -> Array:
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").sortDict(self, dict, shuffleBeforeSort)

func sortArrayByDict(array: Array, dict: Dictionary) -> Array:

	var dictSorter = DictSorter.new(dict)
	array.sort_custom(Callable(dictSorter, "sort"))
	return array

func sortArrayByDict_reverse(array: Array, dict: Dictionary) -> Array:

	var dictSorter = DictSorter.new(dict)
	array.sort_custom(Callable(dictSorter, "sort_reverse"))
	return array

func getInteractableNodes(root: Node) -> Array:
	var nodes = []
	walkInteractableNodes(root, nodes)
	return nodes

func walkInteractableNodes(node: Node, nodes: Array):
	return load("res://Runtime/Behavior/Features/Utility/UtilBehavior.gd").walkInteractableNodes(self, node, nodes)

func isControlEnabled(node: Control) -> bool:
	if node is BaseButton:
		return not node.disabled
	elif node is LineEdit:
		return node.editable
	return true

class DictSorter:
	var dict: Dictionary

	func _init(_dict):
		dict = _dict

	func sort(key1, key2):
		return dict[key1] > dict[key2]

	func sort_reverse(key1, key2):
		return dict[key1] < dict[key2]

func openLocalLink(url: String) -> Error:
	return load("res://Runtime/Behavior/Utility/UtilBehavior.gd").openLocalLink(self, url)

