extends Node2D

## Shared state and public data contract of the Game autoload. Declarations retain their initialization order.

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
var lastCursorType = -1 # Apply the supplied cursor at startup, before the first mouse motion.

var cursors = preload("res://PvE/Art/CursorArt.gd").images() + [
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

var sceneVisibility: Dictionary

var gameSaveQueued = false
var runSaveQueued = false
var tempName: String
var tempPath: String
var tempPath_lobbies: String
var loadTemp: bool

var canCommitRun = true

enum RunStateLoadResult{
	LoadedRun = 0,
	NoRun = 1,
	FileCorrupt = 2,
}

var runStateFields = [
	"version", "class", "mode", "results", "round", "wins", "losses", "tries",
	"bagcounter", "rerolls", "gold", "maxHealth", "maxStamina", "priorRounds",
	"survival", "sqn", "inventory", "storage", "shop", "reserved", "sales",
	"stashedReserved", "stashedSales", "incombat"]

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

var leavingLobby = false

var editModeAnimation = load("res://Interface/EditModeAnimation.tscn")
var curEditModeAni = null

var processThread = null
var checkI = 0

var clickParticles = load("res://Interface/ClickParticles.tscn")

const clickSound = preload("res://Assets/Sound/Sand1.mp3")

const oppoBonusOffset = 800.0
const switchAniParableOffset = 200.0
var switchAni = load("res://Interface/SwitchAnimation.tscn")

enum ShopBGM{
	Default = 0,
	Lobby = 1,
	Survival = 2,
	SwitchMode = 3,
	Subclass = 4,
	LastTry = 5,
}

var lastShopBGM: int = - 1

var pve_closing_legacy_menus = false

const ratingDecay = 0.96
const ratingVelo = 0.63

const decodeOffset = int(pow(2, 32))

var coinParticles = load("res://Interface/CoinParticles.tscn")

const specialItemBoughtSound = preload("res://Assets/Sound/LevelUp2.ogg")

const RECIPE_REVEALED = - 1

const hoverSound = preload("res://Assets/Sound/Click5.ogg")
const clickButtonSound = preload("res://Assets/Sound/Click3.wav")
var hoveredInteractable = null

var pve_high_contrast = false

const CURSOR_SPEED = 600.0
const CONTROLLER_DEADZONE = 0.2

var warpTimestamp_rightStick = 0
var warpTimestamp_dPad = 0
var rightStickWarps = 0
var cursorIsWarping = false
const warpCDFrames_initial = 20
const warpCDFrames_rapid = 10

const maxWarpAngle = deg_to_rad(50.0)
var cursorWarpTrail = load("res://Interface/CursorWarpTrail.tscn")
var pointsOfInterest: Array
var pointsOfInterestInfo: Dictionary
var warpPointOcclusionRects: Array
const maxSliderSteps = 10

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
