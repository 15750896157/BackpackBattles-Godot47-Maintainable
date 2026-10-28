extends Node2D

const rainbowOutlineMaterial = preload("res://Shader/RainbowShiftOutline.material")
const TRAILER = false
const MAX_ITEMS = 6
const offset = 200
const impulse = 200
const rarityOdds = [0.6, 0.2, 0.11, 0.06, 0.03, 0.03]
const continueBanner_ranked = preload("res://Assets/TitleScreen/ContinueBanner_Ranked.png")
const continueBanner_unranked = preload("res://Assets/TitleScreen/ContinueBanner_Unranked.png")
const continueBanner_custom = preload("res://Assets/TitleScreen/ContinueBanner_CustomUnranked.png")

@onready var itemNode = $ItemNode
@onready var rankedButton = $"%RankedButton"
@onready var unrankedButton = $"%UnrankedButton"
@onready var continueButton = $"%ContinueButton"
@onready var continueNode = $TitleNode/Continue
@onready var customRulesIcon = $TitleNode/Continue/CustomRulesIcon
@onready var concedeAnimation = $TitleNode/Concede/AnimationPlayer
@onready var concedeButton = $"%ConcedeButton"

@onready var quitGlow = $Node2D/Background/Quit/QuitSign/QuitSignGlow
@onready var smokeParticles = $Node2D/Background/SmokeParticles2D
@onready var itemDropTimer = $ItemDropTimer
@onready var itemDropTimer2 = $ItemDropTimer
@onready var classAndLoadoutNode = $AboveBlackLayer/Class
@onready var classButtonsNode = $AboveBlackLayer/Class/ClassButtons
@onready var classNodes = Util.getNodesForAllClasses(self, "AboveBlackLayer/Class/ClassButtons/{class}")
@onready var randomClassButton = $AboveBlackLayer/Class/ClassButtons/Random
@onready var randomClassHint = $AboveBlackLayer/Class/Loadouts/RandomHint
@onready var randomClassNodes = [
	$TitleNode/RankedButton/RandomBorder,
	$TitleNode/UnrankedButton/RandomBorder,
	$TitleNode/Lobbies/OtherGameButton/RandomBorder]

@onready var loadoutButtons = [
	$AboveBlackLayer/Class/Loadouts/VBoxContainer/LoadoutButton,
	$AboveBlackLayer/Class/Loadouts/VBoxContainer/LoadoutButton2,
	$AboveBlackLayer/Class/Loadouts/VBoxContainer/LoadoutButton3
]

@onready var otherModesButton = $TitleNode/Lobbies/OtherGameButton
@onready var loadoutInputBlocker = Game.UINode.get_node("InputBlocker")

var randomClassParticles = null
var selectedClassButton = null
var xPos = 1200.0
var itemsScheduled = 0
var warpPointNodes: Array

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd")._ready(self)

func ready_deferred():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").ready_deferred(self)

func updateClassNodes(curClass, randomCharacter):
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").updateClassNodes(self, curClass, randomCharacter)

func updateLoadoutLocale(classI):
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").updateLoadoutLocale(self, classI)

func showSocialButtons():
	return not Game.TRAILER and not SteamHelper.STEAMDECK

func updateSocialButtons():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").updateSocialButtons(self)

func selectClass(classI, randomCharacter = null,
	visualOnly = false):
	return await load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").selectClass(self, classI, randomCharacter, visualOnly)

func toggleRandomClass(pressed):
	Game.setRandomCharacter(pressed)
	Game.setConfigValue("Options", "RandomClass", pressed)
	onRandomClassToggled(pressed)

func onRandomClassToggled(pressed):
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").onRandomClassToggled(self, pressed)

func onQuitPressed():
	Game.quit()

func startRankedPressed() -> void :
	if not Game.draggedItem and not InputBlocker.isActive():
		Game.startFreshRun(Game.Mode.Ranked)
		clearItems()
	return

func startUnrankedPressed() -> void :
	if not Game.draggedItem and not InputBlocker.isActive():
		Game.startFreshRun(Game.Mode.Unranked)
		clearItems()
	return

var numTrailerItems = 500

func showTitle() -> void :
	load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").showTitle(self)

func spawnItem():
	return load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd").spawnItem(self)

func dropItem(_item = null):
	return await load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").dropItem(self, _item)

func _unhandled_key_input(event):
	if TRAILER and event.is_pressed() and event.keycode == KEY_B and Util.debugOnly():
		showTitle()

func positionItem(item):
	item.global_position = item.findFreeSpace(item.global_position)

func applyImpulse(item):
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").applyImpulse(self, item)

func onItemReachedBottom(item) -> void :
	if item.ownerType == Item.Owner.Title:
		item.discard()

func _pve_refresh_title():
	return await load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd")._pve_refresh_title(self)

func _pve_refresh_continue():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd")._pve_refresh_continue(self)

func checkSavedRunState() -> void :
	if Expedition.enabled and Expedition.initialized:
		selectClass(Game.curClass, false, true)
	_pve_refresh_continue()
	return

func onRunstateSuspended():
	updateClassNodes(Game.curClass, Game.randomCharacter)

func onLoadoutButtonToggled(pressed, index):
	return load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd").onLoadoutButtonToggled(self, pressed, index)

func updateLoadoutButtons(disabled: bool, loadout: int = -1):
	return load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd").updateLoadoutButtons(self, disabled, loadout)

func onItemPickedUp():
	if Game.state == Game.State.Title:
		loadoutInputBlocker.show()

func onItemDropped(item, dropResult):
	if Game.state == Game.State.Title:
		if dropResult != Item.DropResult.Hotswap:
			loadoutInputBlocker.hide()

func updateLocale():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").updateLocale(self)

func clearItems():
	return load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd").clearItems(self)

func discardAllItems():
	for item in itemNode.get_children():
		item.discard()

func onContinuePressed():
	if not Game.draggedItem and not Game.runStarted:
		Expedition.continue_run()
		clearItems()
	return

func onConcedePressed():
	Expedition.begin_setup(Game.Mode.Unranked)
	return

const hoverColor = Color(1.3, 1.3, 1.3)

func onRankedHover() -> void :
	if not rankedButton.disabled:
		$"%RankedBannerHovered".show()
		rankedButton.modulate = hoverColor

func onRankedHoverEnd() -> void :
	$"%RankedBannerHovered".hide()
	rankedButton.modulate = Color.WHITE

func onUnrankedHover() -> void :
	if not unrankedButton.disabled:
		$"%UnrankedBannerHovered".show()
		unrankedButton.modulate = hoverColor

func onUnrankedHoverEnd() -> void :
	$"%UnrankedBannerHovered".hide()
	unrankedButton.modulate = Color.WHITE

func onContinueHover() -> void :
	if not continueButton.disabled:
		$"%ContinueBannerHovered".show()
		continueButton.modulate = hoverColor

func onContinueHoverEnd() -> void :
	$"%ContinueBannerHovered".hide()
	continueButton.modulate = Color.WHITE

func onQuitHover():
	quitGlow.show()

func onQuitHoverEnd():
	quitGlow.hide()

func onConcedeHover():
	if not concedeButton.disabled:
		$"%ConcedeBannerHovered".show()
		concedeButton.modulate = hoverColor

func onConcedeHoverEnd():
	$"%ConcedeBannerHovered".hide()
	concedeButton.modulate = Color.WHITE

func _on_SteamButton_pressed() -> void :
	load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd")._on_SteamButton_pressed(self)

func _on_TwitterButton_pressed() -> void :
	Util.openLocalLink("https://twitter.com/TweetFurcifer")

func _on_YoutubeButton_pressed() -> void :
	Util.openLocalLink("https://www.youtube.com/@PlayWithFurcifer/videos")

func _on_DiscordButton_pressed() -> void :
	Util.openLocalLink("https://discord.gg/sbEkqeUKNr")

func _on_QQButton_pressed():
	return load("res://Runtime/Behavior/Features/Interface/TitleScreenBehavior.gd")._on_QQButton_pressed(self)

func _on_WikiButton_pressed():
	Expedition.show_codex()
	return

func _on_ChineseWikiButton_pressed():
	Expedition.show_codex()
	return

func _on_ChineseItemSearch_pressed():
	Expedition.show_codex()
	return

func otherModesUIPressed():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").otherModesUIPressed(self)

func onOtherModeClosed():
	checkSavedRunState()

func disableButtons(disabled: bool):

	rankedButton.disabled = disabled
	unrankedButton.disabled = disabled
	concedeButton.disabled = disabled
	continueButton.disabled = disabled
	otherModesButton.disabled = disabled
	customRulesIcon.disabled = disabled

func onCursorWarp():
	return load("res://Runtime/Behavior/Interface/TitleScreenBehavior.gd").onCursorWarp(self)

