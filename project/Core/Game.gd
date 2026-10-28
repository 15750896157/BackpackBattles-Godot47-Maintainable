extends Node2D

# Exported builds omit developer-only scenes and unreleased content.
var EDITOR = OS.has_feature("editor") and not ProjectSettings.get_setting("application/config/recovered_project")
var isWeb = OS.has_feature("web")
var PLAYTEST = OS.has_feature("playtest")
var FULLVERSION = OS.has_feature("full_version") or ProjectSettings.get_setting("application/config/recovered_project") or Util.debugOnly(true)
var DEMO = not FULLVERSION and not PLAYTEST
var EXPO = false
var ENGINEER_TEST = OS.has_feature("engineertest")
var VERSION = "1.1.8"

const SUBVERSION = ""
const BETA = false
const PREVIEW = false
const leaderboardBreakingVersion = "1.1.5"
const runStateBreakingVersion = "1.1.0"

const ITEM_STATISTICS_ENABLED = true
const LOADOUTS_ENABLED = true
const SKILLS_ENABLED = true
const USE_ICONS = true
const BUILD_HISTORY_ENABLED = true
const RECIPE_TOOLTIPS_ENABLED = true
const LOBBIES_ENABLED = true
const STAT_DISPLAY_ENABLED = true
const ACHIEVEMENTS_ENABLED = true

signal gold_changed
signal trophies_changed
signal item_picked_up
signal item_dropped
signal inventory_changed
signal item_bought
signal special_item_bought
signal item_sold
signal item_crafted
signal crafting_finished
signal item_gained_focus

signal crafting_ready
signal continue_loaded
signal runstate_suspended
signal runstate_loaded
signal character_changed
signal random_character_changed
signal style_changed
signal chibi_setting_changed
signal input_changed
signal device_changed
signal records_updated
signal combat_start_pressed
signal switching_to_combat
signal combat_scene_entered
signal combat_scene_left
signal combat_start
signal combat_end

signal switch_to_shop
signal title_to_shop
signal shop_opened
signal pre_shop_opened_from_title
signal pre_shop_opened_from_combat
signal shop_closed
signal return_to_title
signal returned_to_title
signal return_to_history
signal round_result
signal round_start_gold_gained
signal round_start_health_gained
signal run_started
signal fresh_run_started
signal run_over
signal game_paused
signal game_unpaused
signal menu_open
signal menu_opened
signal menu_close
signal tutorial_done
signal loadout_changed
signal interactable_hovered
signal edit_mode_changed
signal item_list_closed
signal warp_cursor_shop
signal warp_cursor_combat
signal warp_cursor_title
signal warp_cursor_menu
signal get_rects_shop
signal get_rects_combat
signal get_rects_title
signal get_rects_menu

enum State{
	Title = 0,
	Shop = 1,
	Combat = 2,
}

enum PauseSource{
	Unpaused = 0,
	Options = 1,
	FocusLost = 2,
	Ad = 4,
	RecipeBook = 8,
	PatchNotes = 16,
	All = 31,
}

enum ContinueState{
	NotContinued = 0,
	FromShop = 1,
	FromCombat = 2,
}

enum RoundResult{
	Win = 0,
	Loss = 1,
	Draw = 2,
	RunOver = 3,
}

enum Classes{
	Ranger = 0,
	Reaper = 1,
	Berserker = 2,
	Pyromancer = 3,
}

enum Classes_Full{
	Ranger = 0,
	Reaper = 1,
	Berserker = 2,
	Pyromancer = 3,
	Mage = 4,
	Adventurer = 5,
	Engineer = 6,
}

enum Mode{
	Ranked = 0,
	Unranked = 1,
	Lobbies = 2,
	Unselected = 3,
	History = 4,
}

enum Loadout{
	Loadout1 = 0,
	Loadout2 = 1,
	RandomLoadout = 2,
	RandomCharacter = 3,
}

enum Leagues{
	Bronze = 0,
	Silver = 1,
	Gold = 2,
	Platinum = 3,
	Diamond = 4,
	Master = 5,
	Grandmaster = 6,
	Grandma = 7,
	ImpossibleWoodRank = - 1,
}

enum SkinSlot{
	Head = 0,
	Weapon = 1,
	Body = 2,
	Special = 3,
	Shoes = 4,
}

const backup_format = "user://{ID}{build}backup"
const savefile_format = "user://{ID}{build}backpack.save"
const runstate_format = "user://{ID}{build}continue.save"
const lobby_runstate_format = "user://{ID}{build}lobby.save"
const config_format = "user://{ID}{build}backpack.cfg"
const baseDir_format = "user://{ID}{build}"
const offlinesave_format = "user://{ID}{build}backpack.ba"

var playerScene = load("res://Core/Player.tscn")
var opponentScene = load("res://Core/Opponent.tscn")
const playerMoveInSound = preload("res://Assets/Sound/Swoosh1.wav")

const MAX_WINS = 10
const MAX_ROUNDS = 18
const MAX_TRIES = 5
const MAX_HEALTH = 999
const MAX_STAMINA = 999
const MAX_NAME_LEN = 16
const COMBAT_DELAY = 2.5
const playerCombatPos = 350
const goldGain = [
	0, 13, 10, 10, 11, 11,
	12, 12, 13, 13, 14,
	14, 15, 15, 16,
	16, 16, 16, 16, 16]
const BAG_PITY_TIMER = 9
const SUBCLASS_ROUND = 8
const SKILL_ROUND1 = 3
const SKILL_ROUND2 = 10
const MAX_WINS_TROPHIES = 10
const PERFECT_RUN_TROPHIES = 20
const SURVIVED_TROPHIES = 10
const PERFECT_SURVIVAL_TROPHIES = 20
const MAX_WINS_RATING = 5
const PERFECT_RUN_RATING = 7.5
const SURVIVED_RATING = 7
const PERFECT_SURVIVAL_RATING = 12
const RANK_UP_BONUS_RANKING = 10
const MAX_TRIES_LOBBIES = MAX_TRIES
const MAX_ROUNDS_LOBBIES = MAX_ROUNDS
const LOBBY_TIMEOUT_MINUTES = 20

const BROWN = Color(0.24, 0.15, 0.11)
const SOFTWHITE = Color(1, 0.92549, 0.831373)
const rarityColors = [
	Color(0.738144, 0.827926, 0.839844),
	Color(0.230469, 0.549103, 1),
	Color(0.769243, 0.028076, 0.898438),
	Color(0.988281, 0.595056, 0.038605),
	Color(1, 0.970215, 0.523438),
	Color(0.530212, 0.929688, 0.630081)
]
const leagueColors = [
	Color(0.988281, 0.585254, 0.366745),
	Color(0.796875, 0.756506, 0.734619),
	Color(0.974609, 0.869506, 0.485401),
	Color(0.848335, 0.9495, 0.980469),
	Color(0.761719, 0.983246, 1),
	Color(0.4, 0.7, 2),
	Color(1.5, 0.8, 0.2),
	Color(0.789063, 0.095551, 0.371872)
]

@onready var root = get_parent()
@onready var mainNode = root.get_node("Main")
@onready var splashScreenAnimation = mainNode.get_node("SplashscreenAnimation")
@onready var sceneAnimation = mainNode.get_node("SceneAnimation")
@onready var combatSceneNode = mainNode.get_node("Combat")
@onready var opponentNode = combatSceneNode.get_node("Opponent")
@onready var combatUINode = combatSceneNode.get_node("UI")
@onready var combatAnimationsNode = combatSceneNode.get_node("ItemAnimations")
@onready var combatTimer = combatUINode.get_node("%CombatTimer")
@onready var shopSceneNode = mainNode.get_node("Shop")
@onready var shopItemYSort = shopSceneNode.get_node("Items")
@onready var UINode = mainNode.get_node("UI")
@onready var labelsNode = UINode.get_node("Labels")
@onready var tooltipsNode = UINode.get_node("Tooltips")
@onready var recipeTooltipsNode = UINode.get_node("RecipeTooltips")
@onready var speechBubble = shopSceneNode.get_node("SpeechBubble")
@onready var playerNode = mainNode.get_node("Player")
@onready var playerNodeAnimation = mainNode.get_node("PlayerNodeAnimation")
@onready var goldPos = shopSceneNode.get_node("GoldPos")
@onready var connectingLabel = UINode.get_node("ConnectingLabel")
@onready var startCombatButton = shopSceneNode.get_node("StartCombatButton")
@onready var startCombatButtonAni = startCombatButton.get_node("AnimationPlayer")
@onready var shopKeeper = shopSceneNode.get_node("ShopKeeper")
@onready var combatLog = UINode.get_node("CombatLog/CombatLog")
@onready var titleScreen = mainNode.get_node("TitleScreen")
@onready var rerollRope = shopSceneNode.get_node("Reroll/RerollRope")
@onready var itemLibraryTutorialAni = shopSceneNode.get_node("%ItemLibraryTutorial")
@onready var undoStack = UINode.get_node("UndoStack")

var state = State.Title
var continueState = ContinueState.NotContinued
var activePauseSources = PauseSource.Unpaused
var gameSpeedBeforePause = 1.0
var PLAYER
var OPPONENT
var SELLBOX
var STORAGEBOX
var TRAILER = false
var DEVCHEATS = false
var TOOLTIPS = true
var SELECTING = false
var WRITE_OUT_STATE = false
var processTimer: Timer
var recipeBook
var itemLibrary
var otherModesUI = null
var lobbyScoreboard
var selectionBox
var wardrobe
var options
var warning = null
var versionButton
var patchNotes
var gridStorage

var locales = {"English": "en"}
var localeToLanguage: Dictionary
var steamAvailable = false
var leagueIcons = []

var curRound: int = 1
var wins: int
var losses: int
var tries: int
var triesBeforeFight: int
var survivalMode: bool
var justStartedSurvivalMode: bool
var gold: int
var gold_internal: int
var interactable: bool
var left_click = false
var draggedItem = null
var hoveredItems = []
var itemsAreFusing: bool
var craftingPriorities = {}
var sortedCraftingPriorities: Array
var fightEnded: bool = true
var runStarted: bool
var curClass = Classes.Ranger
var curMode = Mode.Unselected
var roundResults = []
var persistent: Dictionary
var arenaRunState: Dictionary
var lobbyRunState: Dictionary
var chibiMode: Array
var curLoadout = 1
var randomCharacter = false

var runWasJustContinued = false
var runWasConceded = false
var lastRunMode: int = - 1
var lastRunConcedeRound: int = - 1
var bagPityCounter: int
var lastItemDropTime = 0.0
var numTimesOutOfStamina: int
var runsStartedThisSession: int
var roundsStartedThisSession: int
var canSwitchToCombat = false
var canCancelSwitch = false
var leaveLobbyPending = false
var powerPreRun: float
var leaguePreRun: int
var leagueProgressPreRun: float
var trophiesPreRun: int
var rankingPreRun: int
var leagueExactPreRun: float
var wasRankedSwitchMode: bool
var endRunFrame = - 1
var startedCombatWithoutGold = 0
var randnum: int
var draggingFinger = - 1
var itemsUnderMouse = []
var replacementPending = false
var showHintsIsPressed = false
var itemsBeingCrafted = []

var lockedTooltipItem = null
var showHintsTimeStamp: int = - 1
var affectedLines = []

var stealLifeDamageSource: DamageSource
var unhealingDamageSource: DamageSource
var fatigueDamageSource: DamageSource
var ropeSpeedups: Dictionary
var cubeAdvanced: Dictionary
var sandbagActive = false
var curOpponentData: Dictionary
var loadoutTween: Tween
var characterTween: Tween

var winNextRun = false
var loseNextRun = false
var winNextRound = false
var loseNextRound = false

var classResources: Array

const classIcons = [
	preload("res://Assets/TitleScreen/RangerIcon.png"),
	preload("res://Assets/TitleScreen/ReaperIcon.png"),
	preload("res://Assets/TitleScreen/BerserkerIcon.png"),
	preload("res://Assets/TitleScreen/PyromancerIcon.png"),
	preload("res://Assets/TitleScreen/MageIcon.png"),
	preload("res://Assets/TitleScreen/AdventurerIcon.png"),
	preload("res://Assets/TitleScreen/EngineerIcon.png")
]

const classNameBanners = [
	preload("res://Interface/Combat/NameBanner_Ranger.png"),
	preload("res://Interface/Combat/NameBanner_Reaper.png"),
	preload("res://Interface/Combat/NameBanner_Berserker.png"),
	preload("res://Interface/Combat/NameBanner_Pyromancer.png"),
	preload("res://Interface/Combat/NameBanner_Mage.png"),
	preload("res://Interface/Combat/NameBanner_Adventurer.png"),
	preload("res://Interface/Combat/NameBanner_Engineer.png")
]

const neutralClassIcon = preload("res://Assets/TitleScreen/NeutralIcon.png")
const randomClassIcon = preload("res://Interface/DiceIcon.png")
const transitionSounds = [
	preload("res://Assets/Sound/TurningPage1.wav"),
	preload("res://Assets/Sound/TurningPage2.wav"),
	preload("res://Assets/Sound/TurningPage3.wav")]

const winSound = preload("res://Assets/Sound/Win.ogg")
const loseSound = preload("res://Assets/Sound/Lose.ogg")

var rainbowRevealParticles = load("res://Shader/RainbowRevealParticles.tscn")
var affectsLineScene = load("res://Items/Exclusive/Animations/AffectsLine.tscn")

var rankSeason2Popup = load("res://Interface/RankSeasonPopup.tscn")
var rankSeason3Popup = load("res://Interface/RankSeason3Popup.tscn")
var electricalChargeScene = load("res://Items/ElectricalCharge.tscn")
var notCraftingAnimation = load("res://Items/Exclusive/Animations/NotCraftingAnimation.tscn")

enum EventType{
	Activation = 0,
	DealDamage = 1,
	CriticalDamage = 2,
	MissedAttack = 3,
	TakeDamage = 4,
	LoseHealth = 5,
	AttackSpeed = 6,
	InvulnerableStart = 7,
	InvulnerableEnd = 8,
	Stun = 9,
	StunResisted = 10,
	CriticalResisted = 11,
	Health = 12,
	Stamina = 13,
	DrainStamina = 14,
	OutofStamina = 15,
	DamageBuff = 16,
	DamReduction = 17,
	DamIncrease = 18,
	TemporaryMaxHealth = 19,
	TemporaryMaxStamina = 20,
	BattleRageStart = 21,
	BattleRageEnd = 22,
	Reincarnate = 23,
	CooldownAdvance = 24,
	Unhealing = 98,
	Fatigue = 99,
	Block = 100,
	Lucky = 101,
	Regeneration = 102,
	Vampirism = 103,
	Spikes = 104,
	Mana = 105,
	Empower = 106,
	Heat = 107,

	Poison = 108,
	Blind = 109,

	Cold = 110,
	Win = 111,
	Loss = 112,
}

var numStackTypes = getStacks().size()

enum ItemMetrics{
	Damage = 0,
	Heal = 1,
	Overheal = 2,
	Misses = 3,
	Activations = 4,
	DamageBlocked = 5,
	MaxHealth = 6,
	OutOfStamina = 7,

	Stamina = 8,

	Block = 9,
	Lucky = 10,
	Regeneration = 11,
	Vampirism = 12,
	Spikes = 13,
	Mana = 14,
	Empower = 15,
	Heat = 16,
	Poison = 17,
	Blind = 18,
	Cold = 19,
}
@onready var eventTypeKeys = Util.invertDictionary(EventType)

const stackIdentifiers = {
	"spikes": EventType.Spikes,
	"vampirism": EventType.Vampirism,
	"poison": EventType.Poison,
	"regen": EventType.Regeneration,
	"bl": EventType.Block,
	"lucky": EventType.Lucky,
	"blind": EventType.Blind,
	"mana": EventType.Mana,
	"heat": EventType.Heat,
	"cold": EventType.Cold,
	"empower": EventType.Empower,
}

enum ItemStatistic{
	SeenInShop = 0,
	Acquired = 1,
	BoughtOnSale = 2,
	Survivals = 3,
	MostWins = 4,
	BestRankSurvival = 5,
}

enum ItemRecordStar{
	Bronze = 0,
	Silver = 1,
	Gold = 2,
	Diamond = 3,
}

enum SaleMode{
	Roll = 0,
	Sale = 1,
	NoSale = 2,
	Free = 3,
}

enum InventoryEditMode{
	Default = 0,
	BagLayer = 1,
	ItemLayer = 2,
}

enum Cursor{
	HARDWARE_SMALL = 0,
	HARDWARE_LARGE = 1,
	SOFTWARE_SMALL = 2,
	SOFTWARE_LARGE = 3,
	DEFAULT = 4,
}

enum CursorTypes{

	DEFAULT = 0,
	CLICKED = 1,
	GRABBABLE = 2,
	GRABBED = 3,
	CLICKABLE = 4,
	CLICKABLE_CLICKED = 5,
	VSIZE = 6,
	VSIZE_CLICKED = 7,
	HSIZE = 8,
	HSIZE_CLICKED = 9,
}

const defaultCursorOffset = Vector2(42, 42)

const cursorOffsets = {
	CursorTypes.DEFAULT: defaultCursorOffset,
	CursorTypes.CLICKED: defaultCursorOffset,
	CursorTypes.GRABBABLE: defaultCursorOffset,
	CursorTypes.GRABBED: defaultCursorOffset,
	CursorTypes.CLICKABLE: Vector2(45, 25),
	CursorTypes.CLICKABLE_CLICKED: Vector2(45, 25),
	CursorTypes.VSIZE: defaultCursorOffset,
	CursorTypes.VSIZE_CLICKED: defaultCursorOffset,
	CursorTypes.HSIZE: defaultCursorOffset,
	CursorTypes.HSIZE_CLICKED: defaultCursorOffset
}

var cursor = Cursor.HARDWARE_SMALL
var softwareCursor = null
var softwareCursorScene = load("res://Interface/Cursor.tscn")
var lastCursorType = CursorTypes.DEFAULT

var cursors = [
	preload("res://Assets/Cursor/Cursor_default.png"),
	preload("res://Assets/Cursor/Cursor_default_clicked.png"),
	preload("res://Assets/Cursor/Cursor_grabbable.png"),
	preload("res://Assets/Cursor/Cursor_grabbed.png"),
	preload("res://Assets/Cursor/Cursor_interactable.png"),
	preload("res://Assets/Cursor/Cursor_interactable_clicked.png"),
	preload("res://Assets/Cursor/ResizeArrow.png"),
	preload("res://Assets/Cursor/ResizeArrow_active.png"),
	preload("res://Assets/Cursor/HSizeArrow.png"),
	preload("res://Assets/Cursor/HSizeArrow_active.png")
	]

var damageNumberFormats = {
	EventType.DealDamage: "[center]{amount}",
	EventType.Health: "[center]+{amount}",
	EventType.CriticalDamage: "[center][shake rate=20 level=50]{amount}[/shake]",
	EventType.Poison: "[center]{amount}",
	EventType.Spikes: "[center]{amount}",
	EventType.Fatigue: "[center]{amount}",
	EventType.Unhealing: "[center]{amount}",
	EventType.LoseHealth: "[center]{amount}"
}

var damageNumberColors = {
	EventType.DealDamage: Color.WHITE,
	EventType.MissedAttack: Color.WHITE,
	EventType.Health: Color(0.22, 0.93, 0.22, 1),
	EventType.CriticalDamage: Color(1, 0.1, 0.1, 1),
	EventType.Poison: Color(0.507813, 1, 0.1),
	EventType.Spikes: Color(0.231075, 0.726563, 0.195831),
	EventType.Fatigue: Color(0.558566, 0.391388, 0.742188),
	EventType.Unhealing: Color(0.759822, 0.40863, 0.804688),
	EventType.LoseHealth: Color(0.884766, 0.470032, 0.470032),
	EventType.TemporaryMaxHealth: Color(0.601852, 1, 0.474609),
	EventType.Stamina: Color(1, 0.97805, 0.197266),
	EventType.TemporaryMaxStamina: Color(1, 0.987717, 0.550781),
	EventType.DamageBuff: Color.WHITE,
	EventType.CooldownAdvance: Color.WHITE
}

var scaledCursors: Array = []
var hoverSoundReadyTime: float = 2.5
var hotswapBehaviorModified: bool = false
var focusDisableFrameCounter: int = 60
var tooltipDisableFrameCounter: int = 0
var lastShowItemTooltipFrame = 0
var lastHideItemTooltipFrame = 0
var lastTooltipWasBag = false
var lastBagTooltipWasDelayed = false
var hoverResponseDisabledFramecounter: int = 0
var reactToHoverEnd = true
var usingController: bool = false
var activeControllerDevice: int = - 1
var usingTouchscreen: bool = false
var itemListOpened: bool = false
var buildHistoryDB = null
var buildHistory = null
var curHistoryData = null
var slotNames = SkinSlot.keys()
var inventoryEditMode = InventoryEditMode.Default

const statisticIncrements = {
	ItemStatistic.SeenInShop: 500,
	ItemStatistic.Acquired: 100,
	ItemStatistic.BoughtOnSale: 50,
	ItemStatistic.Survivals: 10
}

enum TutorialSteps{
	Reserve = 1,
	Lock = 2,
	GoldCarryOver = 4,
	BagMove = 8,
	SendToStorage = 16,
	Undo = 32,
	ShowRecipes = 64,
	Selection = 128,
	Shift = 256,
	Skill = 512,
	Subclass = 1024,
	Stars = 2048,
	Wins = 4096,
	Tries = 8192,
	Rotate = 16384,
	ShopSign = 32768,
	ViewCombat = 65536,
	CombatLog = 131072,
	ItemLibrary = 262144,
	CombatLogButtons = 524288,
	Toolbar = 1048576,
	HistoryFight = 2097152,
}

const tutorialPriorities = [
	TutorialSteps.Reserve,
	TutorialSteps.GoldCarryOver,
	TutorialSteps.BagMove,
	TutorialSteps.SendToStorage,
	TutorialSteps.ShowRecipes,
	TutorialSteps.Selection,
	TutorialSteps.Shift,
	TutorialSteps.Undo
]

var currentTutorialStep = - 1
@onready var tutorialEncodingToStep = Util.invertDictionary(TutorialSteps)

func versionToInt(ver: String = VERSION) -> int:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").versionToInt(self, ver)

func versionToString(ver: int) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").versionToString(self, ver)

func loadExclusiveContent() -> bool:
	return PLAYTEST or FULLVERSION or EDITOR

func showExclusiveContent() -> bool:
	return PLAYTEST or FULLVERSION or EDITOR

func loadUnreleasedClasses() -> bool:
	return FULLVERSION and (EDITOR or PLAYTEST or ENGINEER_TEST)

func loadUnreleasedContent() -> bool:
	return FULLVERSION and (EDITOR or PLAYTEST or ENGINEER_TEST)

func getClassEnum() -> Dictionary:
	if FULLVERSION:
		return Classes_Full
	else:
		return Classes

func getClassKeys() -> Array:
	return getClassEnum().keys()

func getNumClasses() -> int:
	return getClassEnum().size()

func isInLobby() -> bool:
	return RunDatabase.lobbies.isInLobby()

func getEffectiveMode() -> int:
	if curMode == Mode.History:
		return curHistoryData.mode
	else:
		return curMode

func isRankedSwitchMode() -> bool:
	return CustomRules.isRankedSwitchMode() and curMode == Mode.Unranked

func pause(pauseSource: int):
	return load("res://Runtime/Behavior/Game/Session.gd").pause(self, pauseSource)

func unpause(pauseSource: int):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").unpause(self, pauseSource)

func openMenu():
	cancelSwitch()
	emit_signal("menu_open")

var sceneVisibility: Dictionary

func openedMenu():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").openedMenu(self)

func closeMenu(restoreVisibility = true):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").closeMenu(self, restoreVisibility)

func onSceneVisibilityChanged(node):
	sceneVisibility[node] = node.visible

func isMenuOpen() -> bool:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").isMenuOpen(self)

func onItemListClosed():
	itemListOpened = false
	emit_signal("item_list_closed")

func isTouchScreenActive() -> bool:
	return usingTouchscreen

func globalPosToScreenPos(pos) -> Vector2:
	return load("res://Runtime/Behavior/Game/Session.gd").globalPosToScreenPos(self, pos)

func moveMouse(by: Vector2):
	var curMousePos = globalPosToScreenPos(get_global_mouse_position())
	Input.warp_mouse(curMousePos + by)

func moveMouseTo(pos: Vector2):
	Input.warp_mouse(globalPosToScreenPos(pos))

func unhoverAndHideTooltips():

	unlockTooltip()
	unhoverAllItems()
	hideTooltips()
	hideSockets()

func hideTooltips():
	for node in get_tree().get_nodes_in_group("Tooltip"):
		node.hide()

func getMaxNumberOfRounds():
	return MAX_ROUNDS

func getLastRoundResult():
	return load("res://Runtime/Behavior/Game/Session.gd").getLastRoundResult(self)

func getTries():
	return int(ceil(float(Expedition.flow.run.health))) if Expedition.active else 0

func giveTry():
	if tries < MAX_TRIES:
		tries += 1

func isSurvivalMode():
	return survivalMode

func canStartSurvivalMode():
	return ( not isSurvivalMode() and
			isArenaMode() and
			wins == MAX_WINS)

func startSurvivalMode():
	survivalMode = true
	justStartedSurvivalMode = true
	giveTry()

func cancelSurviveMode():
	endRun()

func wasPerfectRunBeforeSurvival():
	for i in MAX_WINS:
		if roundResults[i] != RoundResult.Win:
			return false
	return true

func getRoundsToSurvive():
	return MAX_ROUNDS + 1 - curRound

func getTrophies():
	return persistent["trophies"]

func giveTrophies(amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").giveTrophies(self, amount)

func loseTrophies(amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").loseTrophies(self, amount)

func getGainedGold(forClass, untilRound):
	var _gold = classResources[forClass].gold
	for i in range(1, untilRound + 1):
		_gold += getGoldGain(i)
	return _gold

func getGoldGain(inRound):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getGoldGain(self, inRound)

func getMaxHealthInRound(forClass, untilRound):
	var health = classResources[forClass].health
	for i in range(2, untilRound + 1):
		health += getHealthGain(i)

	return health

func getHealthGain(inRound):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getHealthGain(self, inRound)

func getStartInventoryPrice(forClass, loadout = 0):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getStartInventoryPrice(self, forClass, loadout)

func getNumWins():
	return wins

func getNumLosses():
	return losses

func getRoundResults():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRoundResults(self)

func getTotalRerolls():
	return persistent["rerolls"]

func saveGame():
	if not gameSaveQueued:
		gameSaveQueued = true
		call_deferred("actuallySaveGame")

func expandPath(format: String, steamID = null, full = false) -> String:
	return load("res://Runtime/Behavior/Game/Session.gd").expandPath(self, format, steamID, full)

func makeBaseDir():
	return load("res://Runtime/Behavior/Game/Session.gd").makeBaseDir(self)

func getLoadPath(format: String, isFile: bool = true) -> String:
	return load("res://Runtime/Behavior/Game/Session.gd").getLoadPath(self, format, isFile)

func getSavePath(format: String) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSavePath(self, format)

func actuallySaveGame():
	return load("res://Runtime/Behavior/Game/Session.gd").actuallySaveGame(self)

func findBackups(isLoad: bool):
	return load("res://Runtime/Behavior/Game/Session.gd").findBackups(self, isLoad)

func createBackupFilePath(number):
	var backupPath = getSavePath(backup_format)
	return backupPath.path_join("backup_" + str(number) + ".save")

func createBackupFilePaths(backupNumbers):
	var backupFileNames = []

	for number in backupNumbers:

		var fileName = createBackupFilePath(number)
		backupFileNames.push_back(fileName)
	return backupFileNames

func loadGame():
	return load("res://Runtime/Behavior/Game/Session.gd").loadGame(self)

func getFileContent(path):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").getFileContent(self, path)

func setPatchNoteVersion(version):
	persistent["patchNotesVersion"] = version

func getPatchNoteVersion():
	return persistent["patchNotesVersion"]

var gameSaveQueued = false
var runSaveQueued = false
var tempName: String
var tempPath: String
var tempPath_lobbies: String
var loadTemp: bool

var canCommitRun = true

func calcTempPath():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").calcTempPath(self)

func getRunStateTmpPath(mode: int = curMode):
	if mode == Mode.Lobbies:
		return tempPath_lobbies
	else:
		return tempPath

func getRunStateFormat(mode: int = curMode):
	if mode == Mode.Lobbies:
		return lobby_runstate_format
	else:
		return runstate_format

func getRunState(mode: int = curMode):
	if mode == Mode.Lobbies:
		return lobbyRunState
	else:
		return arenaRunState

func setRunState(runState, mode: int = curMode):
	if mode == Mode.Lobbies:
		lobbyRunState = runState
	else:
		arenaRunState = runState

func saveRunState():
	return Expedition.save_run()

func actuallySaveRunState():
	runSaveQueued = false
	return Expedition.save_run()

func wasRunContinued() -> bool:
	return continueState != ContinueState.NotContinued

func deleteRunStateAndRules(mode: int = curMode):
	CustomRules.reset()
	deleteRunState(mode)

func deleteRunState(mode: int = curMode):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").deleteRunState(self, mode)

enum RunStateLoadResult{
	LoadedRun = 0,
	NoRun = 1,
	FileCorrupt = 2,
}

func loadRunStateFromPath(path, mode) -> int:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").loadRunStateFromPath(self, path, mode)

func validateRun(mode: int) -> bool:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").validateRun(self, mode)

var runStateFields = [
	"version", "class", "mode", "results", "round", "wins", "losses", "tries",
	"bagcounter", "rerolls", "gold", "maxHealth", "maxStamina", "priorRounds",
	"survival", "sqn", "inventory", "storage", "shop", "reserved", "sales",
	"stashedReserved", "stashedSales", "incombat"]

func loadRunState(mode: int, instanceRunState: bool = true) -> bool:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").loadRunState(self, mode, instanceRunState)

func checkItemsValid(items: Array) -> bool:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").checkItemsValid(self, items)

func isArenaMode(mode = curMode) -> bool:
	return mode == Mode.Unranked or mode == Mode.Ranked

func hasArenaRunState() -> bool:
	return not arenaRunState.is_empty()

func suspendRunState(instanceLoadout = true):
	if hasArenaRunState():
		instanceCharacter(getSelectedClass())
		if instanceLoadout:
			setLoadout(getConfiguredLoadout())
		CustomRules.reset()
		emit_signal("runstate_suspended")

func restoreCustomRules(runState):
	var customRules = runState.get("custom", null)
	if customRules != null:
		CustomRules.fromString(customRules)

func deleteDraggedItem():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").deleteDraggedItem(self)

func initPlayerFromRunstate(mode: int = curMode):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").initPlayerFromRunstate(self, mode)

func readRoundResultsFromRunState(mode: int):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").readRoundResultsFromRunState(self, mode)

func continueLastRun(mode):
	setMode(mode)
	Expedition.continue_run(mode)
	return

func concedeLastRun():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").concedeLastRun(self)

func setMode(newMode):
	curMode = newMode

func initPlayer():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").initPlayer(self)

func defaultPersistentVar(varName, defaultVal):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").defaultPersistentVar(self, varName, defaultVal)

func limitName(_name: String) -> String:
	return _name.left(MAX_NAME_LEN)

func setPlayerName(_name: String):
	persistent["name"] = _name

func getPlayerName() -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getPlayerName(self)

func getSavestateVersion():
	return persistent.get("version", null)

func getNumStartedRuns():
	return persistent["runsStarted"]

func getRunWins():
	return persistent["runWins"]

func getPlayerIdentifier():
	return persistent["identifier"]

func getClassInternalName(charClass = curClass) -> String:
	return getClassKeys()[charClass]

func getSubclass():
	return ""

func getClassOrSubclass() -> String:
	var className = getSubclass()
	if className == "":
		className = getClassInternalName()
	return className

func getClassOrSubclassTranslationKey() -> String:
	var subclass = getSubclass()
	if subclass != "":
		return "SUBCLASS_" + subclass + "_NAME"
	else:
		return getClassTranslationKey()

func getClassTranslationKey() -> String:
	return getClassInternalName() + "_NAME"

func getClassName(charClass = curClass) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getClassName(self, charClass)

func getPveClassDescription(charClass = curClass) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getPveClassDescription(self, charClass)

func getNativeClassColor(charClass = curClass) -> Color:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getNativeClassColor(self, charClass)

func getTranslatedSubclassName(subclassName) -> String:
	return Util.tra("SUBCLASS_" + subclassName + "_NAME")

func isClassUnlocked(charClass = curClass) -> bool:
	return charClass in [Classes_Full.Berserker, Classes_Full.Reaper]

func isClassUnlockedStuffed(charClass: int) -> bool:
	return isClassUnlocked(Util.log2(charClass))

func isClassSelected(charClass) -> bool:

	return charClass == curClass

func getSeason() -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSeason(self)

func getSelectedClass() -> int:
	var selectedClass = persistent["selectedClass"]
	if not isClassUnlocked(selectedClass):
		selectedClass = Classes_Full.Berserker if Expedition.enabled else Classes.Ranger
	return selectedClass

func setLoadout(loadout: int):
	curLoadout = clampi(loadout, 0, 1)
	Expedition.setup_loadout = curLoadout
	emit_signal("loadout_changed")
	return

func getConfiguredLoadout() -> int:
	return clampi(Expedition.setup_loadout, 0, 1)

func getClassesForRandom() -> Array:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getClassesForRandom(self)

const leagueThresholds = [
	0,
	50,
	120,
	200,
	300,
	400,
	480,
	550,
	850
]

func getLeague_exact(rating) -> float:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").getLeague_exact(self, rating)

func getRatingFromLeague(leagueExact: float) -> float:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRatingFromLeague(self, leagueExact)

func getRatingDifference(leagueExact1: float, leagueExact2: float) -> float:
	return getRatingFromLeague(leagueExact1) - getRatingFromLeague(leagueExact2)

func getRatingDifference_forBonus(rating: float, leagueExact2: float) -> float:
	return getRatingFromLeague(leagueExact2) - rating

func getRanking(charClass) -> int:
	return int(getLeagueProgress(charClass) * 100)

func getLeague(charClass) -> int:
	return int(getLeague_exact(getPlayerRating(charClass)))

func getLeagueProgress(charClass) -> float:
	return fmod(getLeague_exact(getPlayerRating(charClass)), 1.0)

func getLeagueName(league):
	return Util.tra("LEAGUE_" + Leagues.keys()[league])

func isBelowLeague(league):
	return getLeague(curClass) < league

func isAtLeastInLeague(league):
	return getLeague(curClass) >= league

func getRankingDifForStats(classI, numWins: int, numLosses: int,
	numTriesLeft: int, survival: bool):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRankingDifForStats(self, classI, numWins, numLosses, numTriesLeft, survival)

func getRankingDifIfConceded():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRankingDifIfConceded(self)

func getRankingDif_noSurvival():
	return getRankingDifForStats(curClass, wins, losses, tries, false)

func getRankingDif_survival_worst():
	var maxLosses = MAX_TRIES
	if tries < MAX_TRIES:
		maxLosses += 1
	return getRankingDifForStats(curClass, wins, maxLosses, 0, true)

func getRankingDif_survival_best():
	var healedTries = tries
	if tries < MAX_TRIES:
		healedTries += 1
	return getRankingDifForStats(curClass, MAX_ROUNDS - losses, losses, healedTries, true)

func getSwitchModeRating():
	return persistent["smr"]

func setSwitchModeRating(rating):
	persistent["smr"] = rating

func _enter_tree():
	return load("res://Runtime/Behavior/Game/RunFlow.gd")._enter_tree(self)

func _ready() -> void :
	load("res://Runtime/Behavior/Game/RunFlow.gd")._ready(self)

func ready_deferred():
	return await load("res://Runtime/Behavior/Game/RunFlow.gd").ready_deferred(self)

func onReconnectedToLobby():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").onReconnectedToLobby(self)

func onReconnectedToLobby_deferred():
	sceneAnimation.advance(100)
	playerNodeAnimation.advance(100)

func onReconnectTimeout():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").onReconnectTimeout(self)

var leavingLobby = false

func leaveLobbyFromShop():
	leavingLobby = true

	returnToTitle_midRun()
	playerNodeAnimation.play("ReturnToTitle")
	RunDatabase.lobbies.leaveLobby()

func loadArenaRunAndStartOnTitle():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").loadArenaRunAndStartOnTitle(self)

func instanceCharacter(characterClass: int):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").instanceCharacter(self, characterClass)

func setRandomCharacter(_randomCharacter: bool):
	randomCharacter = _randomCharacter
	emit_signal("random_character_changed")

func initStartInventory(loadout = 0):
	Expedition.setup_loadout = clampi(int(loadout), 0, 1)
	return

func addLoadoutAni_jump(bag):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").addLoadoutAni_jump(self, bag)

func addLoadoutAni(node, isBag):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").addLoadoutAni(self, node, isBag)

func startFreshRun(mode):
	setMode(mode)
	Expedition.begin_setup(mode)
	return

func startHistoryRun(runData, roundNum: int, opponentData = null, opponentRoundNum = - 1):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").startHistoryRun(self, runData, roundNum, opponentData, opponentRoundNum)

func endHistoryRun():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").endHistoryRun(self)

func startLobbyRun():
	if randomCharacter:
		deleteDraggedItem()
	closeAllMenus()
	startFreshRun(Game.Mode.Lobbies)
	SteamHelper.unlockAchievement("LobbyStarted", true)

func addStarOfCourage():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").addStarOfCourage(self)

func initRoundResults():
	roundResults.resize(getMaxNumberOfRounds())
	roundResults.fill(RoundResult.RunOver)

func startRun():
	runStarted = true
	call_deferred("titleToShop")
	call_deferred("emit_signal", "run_started")
	return

func titleToShop():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").titleToShop(self)

func isSoftballRound():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").isSoftballRound(self)

func isSoftballStats():
	return ((wins == 0 and losses == 3) or
			(wins <= 1 and losses == 4))

func isItemHandicapStats():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").isItemHandicapStats(self)

func isShopActive() -> bool:
	return state == State.Shop and canSwitchToCombat and Expedition.active and Expedition.flow.screen_state == "SHOP_PREPARE"

func isSwitchToCombatPossible() -> bool:
	return isShopActive() and draggedItem == null

func cancelSwitch():
	return

func switchToCombat():
	return await load("res://Runtime/Behavior/Game/Presentation.gd").switchToCombat(self)

func finishSwitchingToCombat():
	Expedition.finish_switch_to_combat()
	for actor in [PLAYER, OPPONENT]:
		if is_instance_valid(actor): actor.pve_set_combat_anchor()
	return

func closeAllMenus():
	pve_close_legacy_menus(false)
	return

func forceSwitchToCombat():
	return load("res://Runtime/Behavior/Game/Presentation.gd").forceSwitchToCombat(self)

func finishForceSwitchToCombat():
	sceneAnimation.advance(COMBAT_DELAY)
	sceneAnimation.play()

	RunDatabase.lobbies.startCombat()

func onWaitingForMembersTimeout():
	return load("res://Runtime/Behavior/Game/Presentation.gd").onWaitingForMembersTimeout(self)

func forceLeaveLobby():
	return load("res://Runtime/Behavior/Game/Presentation.gd").forceLeaveLobby(self)

func initOpponent(roundReduction, droppedItems):
	return load("res://Runtime/Behavior/Game/Presentation.gd").initOpponent(self, roundReduction, droppedItems)

func initHistoryOpponent():
	return load("res://Runtime/Behavior/Game/Presentation.gd").initHistoryOpponent(self)

func addOpponentItem(tuple, item, checkValidity: bool):
	return load("res://Runtime/Behavior/Game/Presentation.gd").addOpponentItem(self, tuple, item, checkValidity)

func prepareItems(items):
	PLAYER.prepare()
	OPPONENT.prepare()

	for item in items:
		item.prepare()

func activateItems(items):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").activateItems(self, items)

func endCombat():
	return

func combatEndDeferred():
	return

func forceLoseCombat():
	return

func runOver():
	return Expedition.flow != null and Expedition.flow.screen_state == "RUN_RESULT"

func _input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Game/Presentation.gd")._input(self, event)

func showAffectedLines():
	return load("res://Runtime/Behavior/Game/Presentation.gd").showAffectedLines(self)

func clearAffectedLines():
	for line in affectedLines:
		ObjectPool.returnInstance(line)
	affectedLines.clear()

func onInventoryShifted(shift: Vector2):
	cancelSwitch()

	for line in affectedLines:
		line.moveBy(shift)

	setTutorialDone(TutorialSteps.Shift)

var editModeAnimation = load("res://Interface/EditModeAnimation.tscn")
var curEditModeAni = null

func setInventoryEditMode(editMode):
	return load("res://Runtime/Behavior/Game/Presentation.gd").setInventoryEditMode(self, editMode)

func onEditModeAniFinished(ani):
	if ani == curEditModeAni:
		curEditModeAni = null

func setItemEditMode(item, isInGridStorage = null):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setItemEditMode(self, item, isInGridStorage)

func lockTooltip(item):
	return load("res://Runtime/Behavior/Game/Presentation.gd").lockTooltip(self, item)

func unlockTooltip():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").unlockTooltip(self)

func onItemUnderMouse(item):
	itemsUnderMouse.push_back(item)

func onItemUnderMouseExited(item):
	if item in itemsUnderMouse:
		itemsUnderMouse.erase(item)

func addTranslation():
	return load("res://Runtime/Behavior/Game/Presentation.gd").addTranslation(self)

var processThread = null
var checkI = 0

func tagAllNodes():
	print("CHECKING FOR NEW NODES #", checkI)
	printNewNodes(get_tree().get_root())
	checkI += 1

func printNewNodes(node):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").printNewNodes(self, node)

var clickParticles = load("res://Interface/ClickParticles.tscn")

const clickSound = preload("res://Assets/Sound/Sand1.mp3")

func _unhandled_input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Game/Presentation.gd")._unhandled_input(self, event)

func switchToShop():
	Expedition.enter_shop()
	return

const oppoBonusOffset = 800.0
const switchAniParableOffset = 200.0
var switchAni = load("res://Interface/SwitchAnimation.tscn")

func becomeOpponent():
	return load("res://Runtime/Behavior/Game/Presentation.gd").becomeOpponent(self)

func addSwitchAniTween(tween, character, xMovement: float, yOffset: float, dur):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").addSwitchAniTween(self, tween, character, xMovement, yOffset, dur)

func finishBecomeOpponent(offset):
	return load("res://Runtime/Behavior/Game/Presentation.gd").finishBecomeOpponent(self, offset)

func becomeOpponent_old():
	return load("res://Runtime/Behavior/Game/Presentation.gd").becomeOpponent_old(self)

enum ShopBGM{
	Default = 0,
	Lobby = 1,
	Survival = 2,
	SwitchMode = 3,
	Subclass = 4,
	LastTry = 5,
}

var lastShopBGM: int = - 1

func playShopBGM():
	lastShopBGM = ShopBGM.Default
	Sound.playBGM(Sound.shopBGM)
	return

func _pve_initialize_role_stats():
	return await load("res://Runtime/Behavior/Features/Core/GameBehavior.gd")._pve_initialize_role_stats(self)

var pve_closing_legacy_menus = false

func pve_close_legacy_menus(clear_transition: bool = true):
	return load("res://Runtime/Behavior/Game/Presentation.gd").pve_close_legacy_menus(self, clear_transition)

func _pve_restore_actor_parents():
	return load("res://Runtime/Behavior/Game/Presentation.gd")._pve_restore_actor_parents(self)

func pve_prepare_title():
	return load("res://Runtime/Behavior/Game/Presentation.gd").pve_prepare_title(self)

func pve_prepare_shop():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").pve_prepare_shop(self)

func pve_prepare_combat():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").pve_prepare_combat(self)

func freeOpponent():
	return load("res://Runtime/Behavior/Game/Presentation.gd").freeOpponent(self)

func onSceneAnimationFinished(aniName):
	return load("res://Runtime/Behavior/Game/Presentation.gd").onSceneAnimationFinished(self, aniName)

func _pve_restore_health():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd")._pve_restore_health(self)

func startRound():
	Expedition.start_round()
	call_deferred("_pve_restore_health")
	return

func gainRoundGold(curGoldGain, curHealthGain):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").gainRoundGold(self, curGoldGain, curHealthGain)

const ratingDecay = 0.96
const ratingVelo = 0.63

func calcRunRatingForClass(classI = curClass, numWins = wins, numLosses = losses,
	triesLeft = tries, survival = survivalMode,
	perfectRunBeforeSurvival = wasPerfectRunBeforeSurvival()):

	var curRating = getPlayerRating(classI)

	return calcRunRating(curRating, numWins, numLosses, triesLeft, survival,
		perfectRunBeforeSurvival)

func calcRunRating(curRating, numWins = wins, numLosses = losses,
	triesLeft = tries, survival = survivalMode,
	perfectRunBeforeSurvival = wasPerfectRunBeforeSurvival()):
	return load("res://Runtime/Behavior/Game/Presentation.gd").calcRunRating(self, curRating, numWins, numLosses, triesLeft, survival, perfectRunBeforeSurvival)

func hasPlayedInSeason(season = getSeason()):
	return "rating" + season in persistent

func getRunRating(charClass, season = getSeason()):
	return persistent["rating" + season][charClass]

func setRating(rating, charClass = curClass):
	persistent["rating" + getSeason()][charClass] = rating

func getPlayerRating(charClass = null):
	if isRankedSwitchMode() or charClass == null:
		return getSwitchModeRating()
	else:
		return getRunRating(charClass)

func winRun():
	endRun()

func loseRun():
	endRun()

func wasMaxWins():
	return wins >= MAX_WINS

func wasPerfectRun():
	return wasMaxWins() and losses == 0

func hasSurvived():
	return curRound == MAX_ROUNDS + 1 and tries > 0

func wasPerfectSurvival():
	return hasSurvived() and losses == 0

func getBonusTrophies() -> int:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getBonusTrophies(self)

func endRun(commit = true, showAchievements = true):
	Expedition.render_state()
	return

func endRun_lobby():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").endRun_lobby(self)

func onRunEnded():
	deleteRunStateAndRules()
	numTimesOutOfStamina = 0
	continueState = ContinueState.NotContinued
	saveGame()
	runStarted = false
	emit_signal("run_over")

func returnToTitle_afterRun():
	Expedition.return_to_title()
	return

func returnedToTitle_afterRun():
	state = State.Title
	InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
	emit_signal("returned_to_title")
	return

func returnToTitle_midRun():
	Expedition.return_to_title()
	return

func returnedToTitle_midRun():
	state = State.Title
	InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
	emit_signal("returned_to_title")
	return

func isOtherModesUIOpen():
	return otherModesUI != null and otherModesUI.isOpen

func isLobbyUIOpen():
	return otherModesUI != null and (
		otherModesUI.joinLobbyUI.isOpen or otherModesUI.hostLobbyUI.isOpen)

func encode(g: int) -> int:
	return (g + (g << 32)) ^ randnum

func encode_static(g: int) -> int:
	return g ^ 2345345

func decode_static(g: int) -> int:
	return encode_static(g)

const decodeOffset = int(pow(2, 32))

func decode(g: int) -> int:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").decode(self, g)

func getGold() -> int:
	return decode(gold_internal)

func setGoldEncoded(amount):
	gold_internal = encode(amount)
	gold = decode(gold_internal)

func setGold(amount):
	var oldGold = decode(gold_internal)
	setGoldEncoded(amount)
	emit_signal("gold_changed", amount - oldGold)

func spendGold(amount):
	setGoldEncoded(decode(gold_internal) - amount)
	emit_signal("gold_changed", - amount)

func gainGold(amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").gainGold(self, amount)

var coinParticles = load("res://Interface/CoinParticles.tscn")

func shootGold(fromPos, toPos, amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").shootGold(self, fromPos, toPos, amount)

func getCoinPlayerLayer() -> int:
	return Game.playerNode.z_index + 20

func getCoinSellboxLayer() -> int:
	return Util.getGlobalZ(Game.SELLBOX) + 3

func itemPickedUp(item):
	cancelSwitch()
	draggedItem = item
	emit_signal("item_picked_up")
	if item.isBag():
		onBagMoved()

func itemDropped(item, dropResult):
	lastItemDropTime = Util.time
	emit_signal("item_dropped", item, dropResult)
	if draggedItem == item:
		draggedItem = null
	PLAYER.INVENTORY.cleanUp()

func onInventoryChanged():
	emit_signal("inventory_changed")

func getCombatOrReplayTime() -> float:
	if fightEnded:
		return combatLog.replayTime
	else:
		return combatTimer.combatTime

func tooltipsEnabled():
	return TOOLTIPS and not SELECTING and Util.getFrameCounter_process() > tooltipDisableFrameCounter

func disableTooltipsFor(frames):
	tooltipDisableFrameCounter = Util.getFrameCounter_process() + frames

func hoverResponseEnabled():
	return TOOLTIPS and not SELECTING and Util.getFrameCounter_process() > hoverResponseDisabledFramecounter

func disableHoverResponsesFor(frames):
	hoverResponseDisabledFramecounter = Util.getFrameCounter_process() + frames

func unhoverAllItems(clearItemsUnderMouse = true):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").unhoverAllItems(self, clearItemsUnderMouse)

func refocusHoveredItem():
	if hoveredItems.is_empty(): return
	hoveredItems[0].gainFocus()
	emit_signal("item_gained_focus", hoveredItems[0])

func hasHoverFocus(item):

	if draggedItem != null:
		return draggedItem == item

	if hoveredItems.is_empty(): return false

	return hoveredItems[0] == item

func getFocusItem():
	if draggedItem != null:
		return draggedItem

	if not hoveredItems.is_empty():
		return hoveredItems[0]

	return null

func itemHovered(item):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").itemHovered(self, item)

func recalcHoverPriority():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").recalcHoverPriority(self)

func itemHoverEnd(item):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").itemHoverEnd(self, item)

func isInsideDraggedItem(item):
	return draggedItem and item in draggedItem.draggedInsideItems

func onItemBought(item, onSale):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").onItemBought(self, item, onSale)

const specialItemBoughtSound = preload("res://Assets/Sound/LevelUp2.ogg")

func onSpecialItemBought(item):

	SteamHelper.updateRichPresence()
	emit_signal("special_item_bought", item)

	PLAYER.levelUp()
	Sound.playSound(specialItemBoughtSound)

func onItemSold(item):
	emit_signal("item_sold", item)

func onItemRotated():
	persistent["rotations"] += 1
	setTutorialDone(TutorialSteps.Rotate)

func getTotalRotations():
	return persistent["rotations"]

func onItemLocked():
	setTutorialDone(TutorialSteps.Lock)

func onItemReserved():
	setTutorialDone(TutorialSteps.Reserve)

func onBagMoved():
	setTutorialDone(TutorialSteps.BagMove)

func getNumCrafted(itemName):
	var index = ItemBook.getItemIndex(itemName)
	return persistent["craftedRecipes"].get(index, 0)

const RECIPE_REVEALED = - 1

func onCraftingTimeout():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").onCraftingTimeout(self)

func onItemCrafted(itemDescriptor: ItemDescriptor):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").onItemCrafted(self, itemDescriptor)

func onCraftingFinished():
	emit_signal("item_crafting_finished")

func getNumCraftedItems():
	return persistent["crafted"]

func revealRecipe(itemDescriptor):
	var index = ItemBook.getItemIndex(itemDescriptor.getName())
	persistent["craftedRecipes"][index] = RECIPE_REVEALED
	saveGame()

func isRecipeRevealed(itemName):
	var index = ItemBook.getItemIndex(itemName)
	return persistent["craftedRecipes"].get(index, 0) == RECIPE_REVEALED

func onCraftingReady(item):
	emit_signal("crafting_ready")

func isTutorialDone(step: int) -> bool:
	return (persistent["tutorial"] & step) > 0

func setTutorialDone(step: int):
	if persistent["tutorial"] & step == 0:
		persistent["tutorial"] |= step
		emit_signal("tutorial_done", step)

func getNextTutorialText():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").getNextTutorialText(self)

func onDecorationDestructed():
	shopKeeper.onDecorationDestructed()
	SteamHelper.unlockAchievement("Destruct", true)

func changeArrowCursor(cursorTypeArrow):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeArrow],
		Input.CURSOR_ARROW, getCursorOffset(cursorTypeArrow))

func changeHandCursor(cursorTypeHand):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeHand],
	Input.CURSOR_POINTING_HAND, getCursorOffset(cursorTypeHand))

func changeVSizeCursor(cursorTypeVSize):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeVSize],
	Input.CURSOR_VSIZE, getCursorOffset(cursorTypeVSize))

func changeHSizeCursor(cursorTypeHSize):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeHSize],
	Input.CURSOR_HSIZE, getCursorOffset(cursorTypeHSize))

func getCursorOffset(cursorType) -> Vector2:
	return cursorOffsets[cursorType] * Settings.getVal(Settings.Setting.cursor_size)

func changeCursorSize(newSize: float):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").changeCursorSize(self, newSize)

const hoverSound = preload("res://Assets/Sound/Click5.ogg")
const clickButtonSound = preload("res://Assets/Sound/Click3.wav")
var hoveredInteractable = null

func onHoverInteractable(control: Node):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").onHoverInteractable(self, control)

func onHoverInteractableEnd(control):
	if hoveredInteractable == control:

		hoveredInteractable = null

func onClickButton():
	if Util.clockTime > 3.0:
		Sound.playSound_process(clickButtonSound, 3)

func recalculateCursor():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").recalculateCursor(self)

func getCursorType():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").getCursorType(self)

var pve_high_contrast = false

func _process(delta: float) -> void :
	load("res://Runtime/Behavior/Features/Core/GameBehavior.gd")._process(self, delta)

const CURSOR_SPEED = 600.0
const CONTROLLER_DEADZONE = 0.2

var warpTimestamp_rightStick = 0
var warpTimestamp_dPad = 0
var rightStickWarps = 0
var cursorIsWarping = false
const warpCDFrames_initial = 20
const warpCDFrames_rapid = 10

func _physics_process(delta):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd")._physics_process(self, delta)

func getSoftwareCursor():
	return (cursor == Cursor.SOFTWARE_SMALL or
			cursor == Cursor.SOFTWARE_LARGE or
			SteamHelper.STEAMDECK)

const maxWarpAngle = deg_to_rad(50.0)
var cursorWarpTrail = load("res://Interface/CursorWarpTrail.tscn")
var pointsOfInterest: Array
var pointsOfInterestInfo: Dictionary
var warpPointOcclusionRects: Array
const maxSliderSteps = 10

func addControlOfInterest(control: Control, offset: Vector2 = Vector2.ZERO,
	scrollContainer = null, childToScrollTo = null, layer = 0):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").addControlOfInterest(self, control, offset, scrollContainer, childToScrollTo, layer)

func addPointOfInterest(pos: Vector2, scrollContainer = null,
	childToScrollTo = null, layer = 0):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").addPointOfInterest(self, pos, scrollContainer, childToScrollTo, layer)

func addItemOfInterest(item, layer = 0):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").addItemOfInterest(self, item, layer)

func addOcclusionRect(rect: OcclusionRect):
	warpPointOcclusionRects.push_back(rect)

func addOcclusion(topLeft: Vector2, size: Vector2, layer: int):
	warpPointOcclusionRects.push_back(OcclusionRect.new(topLeft, size, layer))

func connectToGetRectsSignals(receiver: Node, method: String):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").connectToGetRectsSignals(self, receiver, method)

func connectToWarpCursorSignals(receiver: Node, method: String):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").connectToWarpCursorSignals(self, receiver, method)

func warp(input):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").warp(self, input)

func ensureScrollVisibility(scrollContainer: ScrollContainer, child):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").ensureScrollVisibility(self, scrollContainer, child)

func setLocale(locale):
	print("SETTING LOCALE TO ", locale)
	TranslationServer.set_locale(locale)

	Util.updateLocale()
	updateLocale()

func updateLocale():
	var localizedNodes = get_tree().get_nodes_in_group("Localized")
	for node in localizedNodes:
		node.updateLocale()

	itemLibrary.updateSearchDescriptions()

func initLocale():
	setLocale(getConfigValue("Options", "language", getDefaultLocale()))

func setConfigValue(groupName, propertyName, propertyValue):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setConfigValue(self, groupName, propertyName, propertyValue)

func eraseConfigValue(groupName, propertyName):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").eraseConfigValue(self, groupName, propertyName)

func getConfigValue(groupName, propertyName, defaultValue):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getConfigValue(self, groupName, propertyName, defaultValue)

func applySetSkins():
	if not is_instance_valid(PLAYER) or not is_instance_valid(PLAYER.sprite): return
	for slot in SkinSlot.size():
		PLAYER.sprite.setSkin(slot, getSelectedSkin(slot))

func setShowChibis(showChibis):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setShowChibis(self, showChibis)

func getEffectiveChibiMode() -> bool:
	return getChibiMode() and getShowChibis()

func getShowChibis():
	return Settings.getVal(Settings.Setting.opponent_chibis)

func setChibiMode(_chibiMode):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setChibiMode(self, _chibiMode)

func getChibiMode():
	return chibiMode[curClass]

func getStacks() -> Array:
	return [EventType.Block] + getBuffs() + getDebuffs()

func getBuffs() -> Array:
	return range(EventType.Lucky, EventType.Heat + 1)

func getDebuffs() -> Array:
	return range(EventType.Poison, EventType.Cold + 1)

func isBuff(_type):
	return _type >= EventType.Block and _type <= EventType.Heat

func isDebuff(_type):
	return _type >= EventType.Poison and _type <= EventType.Cold

func isStack(_type):
	return _type >= EventType.Block and _type <= EventType.Cold

func typeToKeyword(_type):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").typeToKeyword(self, _type)

func getDefaultLocale():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getDefaultLocale(self)

func showSockets():
	var sockets = get_tree().get_nodes_in_group("Socket")
	for s in sockets:
		s.showSocket()

func hideSockets():

	var sockets = get_tree().get_nodes_in_group("Socket")
	for s in sockets:
		s.hideSocket()

func getSkinConfigKey(slot: int, charClass = curClass, chibi = getEffectiveChibiMode()):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSkinConfigKey(self, slot, charClass, chibi)

func getSelectedSkin(slot):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSelectedSkin(self, slot)

func selectSkin(slot, skinId):
	var key = getSkinConfigKey(slot)
	setConfigValue("Wardrobe", key, skinId)

func getSkinUnlockKey(slot: int, charClass = curClass, chibi = getEffectiveChibiMode()):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSkinUnlockKey(self, slot, charClass, chibi)

func isSkinAvailable(skinId: int) -> bool:
	var numSkins = SkinBook.getNumSkinsForClass(curClass, int(getEffectiveChibiMode()))
	return skinId < numSkins

func isSkinUnlocked(slot: int, skinId: int):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").isSkinUnlocked(self, slot, skinId)

func unlockSkin(slot: int, skinId: int):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").unlockSkin(self, slot, skinId)

func getStatisticsKey(statistic: int) -> String:
	return "Stat" + str(statistic)

func getItemStatistics(statistic: int, descriptor: ItemDescriptor, default = null):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getItemStatistics(self, statistic, descriptor, default)

func setItemStatistic(statistic: int, descriptor: ItemDescriptor, newValue):
	if not ITEM_STATISTICS_ENABLED: return
	var key = getStatisticsKey(statistic)
	persistent[key][descriptor.getIndex()] = newValue

func incrementItemStatistic(statistic: int, descriptor: ItemDescriptor, increment = 1):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").incrementItemStatistic(self, statistic, descriptor, increment)

func addRecord(statistic: int, descriptor: ItemDescriptor, amount: int = 0):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").addRecord(self, statistic, descriptor, amount)

func getRecordQueue():
	var runState = getRunState()
	return runState.get("rq", [])

func clearRecordQueue():
	var runState = getRunState()
	runState["rq"] = []

func showWarning(textKey, confirmKey, cancelKey):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").showWarning(self, textKey, confirmKey, cancelKey)

func onPatchNotesClosed():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").onPatchNotesClosed(self)

func fuseAll():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").fuseAll(self)

func checkForInventoryAchievements():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").checkForInventoryAchievements(self)

func writeoutState():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").writeoutState(self)

var audioMutedBeforeFocusLost = false

func _notification(what: int) -> void :

	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		clearAffectedLines()
		itemLibrary.hideRecordIcons()

		if lockedTooltipItem == null:
			showHintsIsPressed = false

			var focusItem = getFocusItem()
			if focusItem != null:
				focusItem.hideBuildIntoRecipesTooltip()
				focusItem.clearCanAffectVisuals()

		if Settings.getVal(Settings.Setting.reduce_fps_unfocused):
			OS.low_processor_usage_mode = true
			Engine.max_fps = int(20)

		if Settings.getVal(Settings.Setting.mute_unfocused):
			audioMutedBeforeFocusLost = AudioServer.is_bus_mute(Sound.MASTER_BUS)
			AudioServer.set_bus_mute(Sound.MASTER_BUS, true)

		if useShell():
			processTimer.start(Util.rng.randf_range(10, 30))

	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		set_deferred("showHintsIsPressed", false)

		if Settings.getVal(Settings.Setting.reduce_fps_unfocused):
			OS.low_processor_usage_mode = false
			Engine.max_fps = int(Settings.getVal(Settings.Setting.fps_limit))

		if Settings.getVal(Settings.Setting.mute_unfocused):
			AudioServer.set_bus_mute(Sound.MASTER_BUS, audioMutedBeforeFocusLost)

		if useShell():
			processTimer.stop()
			checkProcesses_threaded()

	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Expedition.enabled:
			quit()
			return
		saveWindowSettings()

func useShell():
	return not EDITOR and not ProjectSettings.get_setting("application/config/local_services")

func saveWindowSettings():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").saveWindowSettings(self)

var quitting: bool = false

func quit():
	return await load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").quit(self)

func joinProcessThread():
	processThread.wait_to_finish()

func checkProcesses_cyclic():
	checkProcesses_threaded()
	processTimer.start(Util.rng.randf_range(10, 30))

func checkProcesses_threaded():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").checkProcesses_threaded(self)

func checkProcesses() -> bool:
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").checkProcesses(self)

class ItemSort:
	static func sort_HoverPriority(item1: Item, item2: Item):
		return item1.getHoverPriority() > item2.getHoverPriority()

	static func sort_ShopPriority(item1: Item, item2: Item):
		return item1.getShopPriority() > item2.getShopPriority()

	static func sort_TriggerPriority(item1: Item, item2: Item):
		return item1.getTriggerPriority() > item2.getTriggerPriority()

	static func sort_BagOrder(item1: Dictionary, item2: Dictionary):
		return int(item1["d"].isBag()) > int(item2["d"].isBag())

class LineSort:
	static func sort(line1, line2):
		return line1.getLength() > line2.getLength()

class OcclusionRect:
	var rect: Rect2
	var layer: int

	func _init(_topLeft: Vector2, _size: Vector2, _layer: int):
		rect = Rect2(_topLeft, _size)
		layer = _layer

func _exit_tree():
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd")._exit_tree(self)

func _begin_shutdown():
	if is_instance_valid(Sound): Sound.shutdown()
	reactToHoverEnd = false
	hoveredItems.clear()
	itemsUnderMouse.clear()
	draggedItem = null
