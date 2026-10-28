extends RigidBody2D
class_name Item

@export var mode: int = 0:
	set(value):
		mode = value
		freeze = value != 0
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC if value == 3 else RigidBody2D.FREEZE_MODE_STATIC
		lock_rotation = value == 2

signal hovered
signal unhovered
signal picked_up
signal dropped
signal added_to_inventory
signal info_panel_clicked

enum Owner{
	Shop = 0,
	PlayerInventory = 1,
	PlayerStorageBox = 2,
	Opponent = 3,
	Title = 4,
	RecipeBook = 5,
	Tooltip = 6,
	Socket = 7,
	ItemLibrary = 8,
	InfoPanelIcon = 9,
	BuildViewer = 10,
	BuildViewerIcon = 11,
	GridStorage = 12,
	Undefined = 13,
}

enum Type{
	Bag = 0,
	Consumable = 1,
	Food = 2,
	Pet = 3,
	Weapon = 4,
	Shield = 5,
	Armor = 6,
	Gloves = 7,
	Shoes = 8,
	Helmet = 9,
	Accessory = 10,
	Potion = 11,
	Card = 12,
	Gem = 13,
	Scroll = 14,
	Book = 15,
	Skill = 16,
	ChessPiece = 17,
	Spell = 18,

	Melee = 19,
	Ranged = 20,
	Effect = 21,

	Holy = 22,
	Magic = 23,
	Vampiric = 24,
	Dark = 25,
	Nature = 26,
	Fire = 27,
	Ice = 28,
	Musical = 29,
}

enum Priority{
	Lowest = - 10000,
	Low = - 1000,
	Normal = 0,
	High = 1000,
	Highest = 10000,
}

enum CraftingPriority{
	Gem = 3,
	Mixed = 2,
	NonGem = 1,
}

enum Tag{
	None = 0,
	Lifesteal = 1,
	Stone = 2,
	Scroll = 8,
	Dragon = 16,
	Staff = 32,
	BattleRage = 64,
	Singular = 128,
	Transient = 256,
	Bow = 512,
}

enum Stack{
	None = 0,
	Block = 1,
	Lucky = 2,
	Regeneration = 4,
	Vampirism = 8,
	Spikes = 16,
	Mana = 32,
	Empower = 64,
	Heat = 128,
	Poison = 256,
	Blind = 512,
	Cold = 1024,
	Buff = 128 + 64 + 32 + 16 + 8 + 4 + 2,
	Debuff = 1024 + 512 + 256,
	BuffNoLuck = 128 + 64 + 32 + 16 + 8 + 4,
}

enum Mat{
	Default = 0,
	Wood = 1,
	Metal = 2,
	Leather = 3,
	Glass = 4,
	Stone = 5,
	Squishy = 6,
	Jewelry = 7,
	Sand = 8,
	Paper = 9,
	Slime = 10,
	Ice = 11,
	Fire = 12,
	Dragon = 13,
	Bird = 14,
	Leaf = 15,
}

enum Physics{
	Default = 0,
	Light = 1,
	Slime = 2,
	Dense = 3,
	VeryDense = 4,
	Floaty = 5,
	Sand = 6,
	Plush = 7,
	BouncyDense = 8,
	Ice = 9,
	Ghost = 10,
	BlackHole = 11,
}

enum Rarity{
	Common = 0,
	Rare = 1,
	Epic = 2,
	Legendary = 3,
	Godly = 4,
	Unique = 5,
}

enum FaceDirection{
	UP = 0,
	RIGHT = 1,
	DOWN = 2,
	LEFT = 3,
}

enum StatModified{
	No = 0,
	Positive = 1,
	Negative = 2,
}

enum DropResult{
	AddedToInventory = 0,
	Hotswap = 1,
	InventoryCollision = 2,
	OutsideInventory = 3,
	AddedToStorageBox = 4,
	Sold = 5,
	Socketed = 6,
	SocketHotswap = 7,
	Failed = 8,
}

enum PickupType{
	Grabbed = 0,
	Hotswap = 1,
	MultiSelect = 2,
}

enum Affected{
	Primary = 0,
	Secondary = 2,
	Tertiary = 4,
	Lightning = 7,
}

enum Tiles{
	Extension = 2,
	Collision = 3,
	Affected = 4,
	AffectedDynamic = 5,
	AffectedSecondary = 6,
	AffectedSecondaryDynamic = 7,
	AffectedExtension = 8,
	AffectedTertiary = 10,
	AffectedLightning = 11,
}

const affectedColorToTileId = {
	Affected.Primary: Tiles.Affected,
	Affected.Secondary: Tiles.AffectedSecondary,
	Affected.Tertiary: Tiles.AffectedTertiary,
	Affected.Lightning: Tiles.AffectedLightning
}

enum ActivationAni{
	Scale = 0,
	Jump = 1,
	SquishyJump = 2,
	VerySquishyJump = 3,
	Slash = 4,
	Stab = 5,
	Bonk = 6,
	ReverseBonk = 7,
	Chop = 8,
	Squish = 9,
	Block = 10,
	Wave = 11,
	Potion = 12,
	Sweep = 13,
	Spin = 14,
	Throw = 15,
	Shoot = 16,
	Struggle = 17,
	ReverseStab = 18,
	Hiss = 19,
	Tackle = 20,
	DoubleSlash = 21,
	Flash = 22,
}

enum Stat{
	MinDamage = 0,
	MaxDamage = 1,
	StaminaCost = 2,
	Speed = 3,
	BaseCooldown = 4,
	Accuracy = 5,
	CritChance = 6,
	Chance = 7,
	Chance2 = 8,
	Cooldown = 9,
}

static func getNumTooltipStats():
	return Stat.size()

var itemMetrics = []

enum StackChangeType{
	Added_Player = 0,
	Added_Opponent = 1,
	Removed_Player = 2,
	Removed_Opponent = 3,
	Used_Player = 4,
	Used_Opponent = 5,
}

var numStackChangeTypes = StackChangeType.size()

static func getNumNonStackItemMetrics():
	return (Game.ItemMetrics.Stamina +
			(Game.ItemMetrics.Block - Game.ItemMetrics.Stamina) * StackChangeType.size())

static func getNumItemMetrics():
	return (Game.ItemMetrics.Stamina +
			(Game.ItemMetrics.size() - Game.ItemMetrics.Stamina) * StackChangeType.size())

static func getNumStackChangeTypes():
	return StackChangeType.size()

var statDisplayOverrides = []

const rarityColors = [
	Color(0.460205, 0.874887, 0.90625),
	Color(0.0737, 0.337874, 0.898438),
	Color(0.828125, 0, 1),
	Color(1, 0.609375, 0),
	Color(0.980469, 0.946239, 0.582153),
	Color(0.094223, 0.964844, 0.250663)
]

@onready var collisionMap = $CollisionMap
@onready var animation = $AnimationPlayer
@onready var sprite = $Icon
var spriteScale
var hasSquishySprite = false
@onready var clickArea = $ClickArea

@onready var dragParticles = $DragParticles
var specificDragParticles: Array
var dragParticlesEnabled = true
@onready var sockets: Array = $Icon/Sockets.get_children()
@onready var lock = $Lock
@onready var lockAnimation = $Lock/AnimationPlayer

@onready var baseBounce: float = physics_material_override.bounce
@onready var baseFriction: float = physics_material_override.friction
const offset = 40
const impulse = 50
const momentumFactor = 20.0
var frictionTime = 15.0
var totalWeight: float

const itemMaterial = preload("res://Items/Materials/NewProgressMaterial.material")

const grayscaleMaterial = preload("res://Shader/Grayscale.material")
var shadowScene:
	get:
		return AssetStream.resolve("res://Items/Shadow.tscn")
var dropParticlesScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/DropParticles.tscn")
var tooltipScenes:
	get:
		return [
			AssetStream.resolve("res://Interface/Tooltips/CommonTooltip.tscn"),
			AssetStream.resolve("res://Interface/Tooltips/RareTooltip.tscn"),
			AssetStream.resolve("res://Interface/Tooltips/EpicTooltip.tscn"),
			AssetStream.resolve("res://Interface/Tooltips/LegendaryTooltip.tscn"),
			AssetStream.resolve("res://Interface/Tooltips/GodlyTooltip.tscn"),
			AssetStream.resolve("res://Interface/Tooltips/UniqueTooltip.tscn")]

var recipeTooltip:
	get:
		return AssetStream.resolve("res://Interface/Tooltips/RecipeTooltip.tscn")
const rotateSound = preload("res://Assets/Sound/Grind.wav")
const grabSound = preload("res://Assets/Sound/Swing1.wav")
var dustParticles:
	get:
		return AssetStream.resolve("res://Interface/DustParticles.tscn")
const hoverSound = preload("res://Assets/Sound/Click4.wav")
const lockSound = preload("res://Assets/Sound/Lock.wav")
const unlockSound = preload("res://Assets/Sound/Unlock.wav")
var sparksScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/ItemSparks.tscn")
var hoverSparksScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/ItemHoverSparks.tscn")
var rotationSparksScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/ItemRotationSparks.tscn")
var typeTransformationParticles:
	get:
		return {
			Type.Dark: AssetStream.resolve("res://Items/Particles/DarkTransformationParticles.tscn"),
			Type.Holy: AssetStream.resolve("res://Items/Particles/HolyTransformationParticles.tscn")
		}
var craftingBondScene:
	get:
		return AssetStream.resolve("res://Items/CraftingBond.tscn")
var catalystBondScene:
	get:
		return AssetStream.resolve("res://Items/CatalystBond.tscn")
var craftingLabelScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/CraftingProgressLabel.tscn")
var craftingReadyAnimation:
	get:
		return AssetStream.resolve("res://Items/Animations/CraftingReadyAnimation.tscn")
var craftedAnimation:
	get:
		return AssetStream.resolve("res://Items/Animations/CraftedAnimation.tscn")
var catalystReadyAnimation:
	get:
		return AssetStream.resolve("res://Items/Animations/CatalystReadyAnimation.tscn")
var lockLabelScene:
	get:
		return AssetStream.resolve("res://Interface/Inventory/CraftingLockLabel.tscn")
var affectedAnis:
	get:
		return {
			Affected.Primary: AssetStream.resolve("res://Interface/Inventory/AffectedStarAnimation.tscn"),
			Affected.Secondary: AssetStream.resolve("res://Interface/Inventory/AffectedStarAnimationSecondary.tscn"),
			Affected.Tertiary: AssetStream.resolve("res://Interface/Inventory/AffectedStarAnimationTertiary.tscn"),
			Affected.Lightning: AssetStream.resolve("res://Interface/Inventory/AffectedStarAnimationLightning.tscn")}
const affectedSounds = {
	Affected.Primary: preload("res://Assets/Sound/Chime1.mp3"),
	Affected.Secondary: preload("res://Assets/Sound/Chime2.mp3"),
	Affected.Tertiary: preload("res://Assets/Sound/Chime3.mp3"),
	Affected.Lightning: preload("res://Assets/Sound/Chime3.mp3")}
const affectedSoundsVolume = {
	Affected.Primary: - 8,
	Affected.Secondary: - 1,
	Affected.Tertiary: - 1,
	Affected.Lightning: - 1}
var globalAffectVisual:
	get:
		return AssetStream.resolve("res://Interface/Inventory/GlobalAffectVisual.tscn")

const cellSize = Vector2(80, 80)
const halfCellSize = 0.5 * cellSize
const shadowOffset_shop = Vector2(5, 1)
const shadowOffset_dropped = Vector2(5, 5)
const shadowOffset_dragged = Vector2(15, 15)
const DRAG_PRIORITY = 2
const cdEncodingFactor: = 100000.0

var me = self
var descriptor
var inventory
var ownerType: int
var placed = false
var occupiedCells = []
var mouseIsOverItem = false
var hovered_state = false
var dragged = false
var focus = false
var spotlight = false
var collisionShape
var wasJustCrafted = false

var collisionCells: Array
var extensionCells: Array
var affectedExtensionCells: Array
var affectedCellsCache: Dictionary = {}

var faceDirection = FaceDirection.UP
var pickupPosition: Vector2
var pickupRotation: float
var pickupTopLeftCell: Vector2
var pickupFaceDirection: int
var sameOrientationAsPickup: bool
var movebackTween: Tween
var rotationTween: Tween
var pickingEnabled = true
var tooltipEnabled = true
var hoverResponseEnabled = true

var focusEnabled = true
var affectedCellsActive = true
var affordable: bool

var dynamicTypes: Dictionary
var momentumStrength: float
var momentum: Vector2
var tooltip = null
var tooltipMargin = Vector2(100, 0)
var tooltipUpdateQueued = false
var shadows: Array
var spritesWithShadows: Array
var shadowOffset = shadowOffset_dropped
var shadowTween
var dropFrame: int = 0
var pickupFrame: int = 0
var currentAffectedItems: Dictionary = {}
var cachedAffectedItems: Dictionary
var mouseWheelRotationReadyTime: float = 0.0
var notEnoughGoldLabelReadyTime: float = 0.0
var averagedPosition: Vector2
var impactSoundVolume: float = 0.0
var placedByPlayer: bool
var progressMaterial = null
var insideRotationNode = null
var draggedInsideItems = []
var draggingParent = null
var sold: bool = false
var lastVelocity = Vector2.ZERO
var lastCollisionPos = Vector2.ZERO
var lastCollider = null
var impactSoundReadyTime = 0.0
var buffLabelPositionTimestamps = [0.0, 0.0, 0.0, 0.0, 0.0]
var consumed: bool
var globalAffectVisuals = []

var bondedBaseItem = null
var bondedIngredients = []
var locked = false
var bound = false
var curRecipe = null

var bondVisuals = []
var craftingLabel = null
var craftingAniReadyTime: float = 0.0

var lastActivationTime: float = 0.0
var activationsThisFrame: int = 0
var lastTriggerTime: float = 0.0
var triggersThisFrame: int = 0
var combatConnections: Array = []
var triggerTime: float
var iterationCooldown: float
var baseCooldownOverride: float
var chanceRng = BalancedRng.new()
var damageRangeRng = BalancedRange.new()
var speedScale: float = 0.0
var bonusMaxDam: float = 0.0
var bonusMinDam: float = 0.0
var removableDam: float = 0.0
var bonusDamageFactor: float = 1.0
var staminaFactor: float = 1.0
var critChancePercent: float = 0.0
var critTokens: int = 0
const BASE_CRIT_SEVERITY = 2.0
var critSeverity: float = BASE_CRIT_SEVERITY
var bonusChancePercent_mult: float = 0.0
var bonusChancePercent_additive1: float = 0.0
var bonusChancePercent_additive2: float = 0.0
var bonusAccuracy: float = 0.0
var buffPowers: Dictionary
var buffAmplificationChances: Dictionary
var damageSource = null
var doubleActivationChance: float
var doubleAttackEffectChance: float
var paramMult: Dictionary
var paramAdd: Dictionary
var numCharges = 0

var pooled: bool = false
var initialized: bool = false

@onready var hasPreDealDamageEarlyEffect = has_method("onPreDealDamage_early")
@onready var hasPreDealDamageLateEffect = has_method("onPreDealDamage_late")
@onready var hasDealtDamageEffect = has_method("onDealtDamage")
@onready var hasOnChargeReceivedEffect = has_method("onChargeReceived")
@onready var hasOnChargeLeftEffect = has_method("onChargeLeft")

func preset():
	pass

func _enter_tree() -> void:
	load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd")._enter_tree(self)

func _ready() -> void :
	load("res://Runtime/Behavior/Items/LifecycleAndText.gd")._ready(self)

func ready_deferred():
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").ready_deferred(self)

func initPhysicsMaterial():
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").initPhysicsMaterial(self)

func isA(_descriptor) -> bool:
	return descriptor == _descriptor

func getShadowOffset() -> Vector2:
	if ownerType == Owner.Shop:
		return shadowOffset_shop
	else:
		return shadowOffset_dropped

static func getStackMetricIndex(stackChangeType: int, stackType: int) -> int:
	var offsetStackType = stackType - Game.EventType.Block
	var changeTypeOffset = stackChangeType * Game.numStackTypes
	return getNumNonStackItemMetrics() + changeTypeOffset + offsetStackType

static func getMultiMetricIndex(stackChangeType: int, metric: int) -> int:
	var offsetMetric = metric - Game.ItemMetrics.Stamina
	var numMultiMetrics = offsetMetric * StackChangeType.size()
	return Game.ItemMetrics.Stamina + numMultiMetrics + stackChangeType

func cacheCollisionCells():
	collisionCells = LegacyGrid.used_cells_by_id(collisionMap, Tiles.Collision)
	extensionCells = LegacyGrid.used_cells_by_id(collisionMap, Tiles.Extension)

func initRecipeBook():
	disablePicking()
	for shadow in shadows:
		shadow.hide()
	collisionShape.disabled = true
	set_collision_layer(0)
	set_collision_mask(0)

func initItemLibrary():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").initItemLibrary(self)

func setSpotlight(_spotlight):
	hoverEnd()
	spotlight = _spotlight
	if spotlight:
		respondToHover()
	else:
		respondToHoverEnd()

func initTitle():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").initTitle(self)

func initTooltip():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").initTooltip(self)

func initBuildViewer():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").initBuildViewer(self)

func initBuildViewerIcon():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").initBuildViewerIcon(self)

func initInfoPanelIcon():
	initBuildViewerIcon()
	set_process_input(true)

func initGridStorageIcon():
	initBuildViewerIcon()
	clickArea.hide()

func getData():
	return null

func setData(_data):
	pass

func persistDataInShop() -> bool:
	return false

func getIndex() -> int:
	return descriptor.getIndex()

func getName() -> String:
	return descriptor.getName()

func getTranslatedName(removeLinebreaks = false) -> String:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getTranslatedName(self, removeLinebreaks)

func getDescription(wrapInColor = true) -> String:
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").getDescription(self, wrapInColor)

func insertParameters(descr, wrapInColor = true):
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").insertParameters(self, descr, wrapInColor)

func insertParameter(descr, paramName, value, modified = StatModified.No, checkZero = true, wrapInColor = true):
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").insertParameter(self, descr, paramName, value, modified, checkZero, wrapInColor)

func getModeDescription(text: String, colors: Array, center: bool = true, wrapInColor: bool = true):
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").getModeDescription(self, text, colors, center, wrapInColor)

func getBagEffect(number):
	return load("res://Runtime/Behavior/Items/LifecycleAndText.gd").getBagEffect(self, number)

func getFlavorText() -> String:
	if pve_is_view(): return ""
	return descriptor.getFlavorText()

func isBag() -> bool:
	return false

func isWeapon() -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").isWeapon(self)

func isPlaced() -> bool:
	return placed

func isInInventory() -> bool:
	return inventory != null and placed

func isOwnable() -> bool:
	return (ownerType == Owner.Shop or
		ownerType == Owner.PlayerInventory or
		ownerType == Owner.PlayerStorageBox)

func isOwnedByOpponent() -> bool:
	return ownerType == Owner.Opponent

func isClassItem(classIndex = null) -> bool:
	if classIndex != null:
		return descriptor.isClassItem() and descriptor.isAvailableFor(classIndex)
	return descriptor.isClassItem()

func isNeutral() -> bool:
	return descriptor.isNeutral()

func isSubclassItem() -> bool:
	return descriptor.isSubclassItem()

func isGateItem() -> bool:
	return has_method("getGatedDescriptor") or has_method("getReplaceDescriptor")

func getTriggerPriority() -> int:
	return Priority.Normal

func disablePicking():
	pickingEnabled = false

func enablePicking():
	pickingEnabled = true

func enableTooltip():
	tooltipEnabled = true

func disableTooltip():
	tooltipEnabled = false
	if tooltip:
		tooltip.discard()
		tooltip = null

func disableFocus():

	focusEnabled = false
	if focus:
		loseFocus()

func enableFocus():
	focusEnabled = true

func setEditMode(active: bool):
	return load("res://Runtime/Behavior/Items/GridGeometry.gd").setEditMode(self, active)

func setShadowAlpha(alpha: float):
	for shadow in shadows:
		shadow.self_modulate.a = alpha

func getCellsForGlobalPositions(points: Array) -> Array:
	var cells = []
	for point in points:
		cells.push_back(LegacyGrid.cell(collisionMap, point - collisionMap.global_position))
	return cells

func getGlobalPointsForCells(cells):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getGlobalPointsForCells(self, cells)

func getGlobalPointsForCells_noRotate(cells):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getGlobalPointsForCells_noRotate(self, cells)

func getNumCells():
	if pve_is_view(): return getNumOccupiedCells()
	return getNumOccupiedCells() + getNumBagCells()

func getNumOccupiedCells():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getNumOccupiedCells(self)

func getNumBagCells():
	if pve_is_view(): return getNumOccupiedCells() if isBag() else 0
	return extensionCells.size()

func getCollisionCells():
	return collisionCells

func getNormalizedCollisionCells() -> Array:
	return load("res://Runtime/Behavior/Items/GridGeometry.gd").getNormalizedCollisionCells(self)

func getCollisionPoints():
	if pve_is_view(): return Expedition.bridge.grid_points(self)
	return getGlobalPointsForCells(getCollisionCells())

func getOwnOrPlayerInventory():
	if placed:
		return inventory
	else:
		return Game.PLAYER.INVENTORY

func getAffectedCells_tilemap(color = Affected.Primary) -> Array:
	return LegacyGrid.used_cells_by_id(collisionMap, affectedColorToTileId[color])

func getAffectedCellsAfterRotate(rotatedCells, color = Affected.Primary) -> Array:
	if color == Affected.Primary:
		return getAffectedCellsAfterRotate_primary(rotatedCells)
	elif color == Affected.Secondary:
		return getAffectedCellsAfterRotate_secondary(rotatedCells)
	else:
		return []

func getAffectedCellsAfterRotate_primary(_rotatedCells):
	return []

func getAffectedCellsAfterRotate_secondary(_rotatedCells):
	return []

func getAffectedCells_noRotate(color = Affected.Primary):
	var globalCollisionPoints = getCollisionPoints()
	var rotatedCells = getCellsForGlobalPositions(globalCollisionPoints)
	var affectedCells = getAffectedCellsAfterRotate(rotatedCells, color)
	var affectedPoints = getGlobalPointsForCells_noRotate(affectedCells)
	return affectedPoints

func getNumAffectedCells(color = Affected.Primary) -> int:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getNumAffectedCells(self, color)

func getAffectedPoints(color = Affected.Primary) -> Array:
	return getGlobalPointsForCells(getAffectedCells_tilemap(color)) + getAffectedCells_noRotate(color)

func getAffectedCellsInInventory(color = Affected.Primary) -> Array:
	return getOwnOrPlayerInventory().getCellsForGlobalPositions(getAffectedPoints(color))

func getItemsInAffectedCells_cached(color = Affected.Primary) -> Array:
	return getOwnOrPlayerInventory().getItemsInCells(getAffectedCellsInInventory_cached(color))

func getItemsInAffectedCells(color = Affected.Primary) -> Array:
	return getOwnOrPlayerInventory().getItemsInCells(getAffectedCellsInInventory(color))

func countItemsInAffectedCells_cached(color = Affected.Primary) -> Dictionary:
	return getOwnOrPlayerInventory().countItemsInCells(getAffectedCellsInInventory_cached(color))

func getAffectedItems(color = Affected.Primary) -> Array:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getAffectedItems(self, color)

func getAffectedItems_nocache(color = Affected.Primary) -> Array:
	var items = []
	for item in getItemsInAffectedCells(color):
		if canAffect_color(item, color):
			items.push_back(item)
	return items

func isItemAffected(item, color = Affected.Primary) -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").isItemAffected(self, item, color)

func getNumEmptyAffectedCells(color = Affected.Primary) -> int:
	return inventory.getEmptyCellsInCells(getAffectedCellsInInventory(color))

func getNumAffectedItems(color = Affected.Primary) -> int:
	return getAffectedItems(color).size()

func getFirstAffectedItem(color = Affected.Primary):
	var _affectedItems = getAffectedItems(color)
	if not _affectedItems.is_empty():
		return _affectedItems[0]
	return null

func getNumAffected_type(type: int, color = Affected.Primary) -> int:
	var num = 0
	for item in getAffectedItems(color):
		num += item.getTypeMultiplicity(type)
	return num

func getExtensionCells():
	return extensionCells

func getExtensionPoints():
	if pve_is_view(): return Expedition.bridge.grid_points(self)
	return getGlobalPointsForCells(getExtensionCells())

const correction = [
	Vector2.ZERO,
	Vector2( - cellSize.x, 0),
	Vector2( - cellSize.x, - cellSize.y),
	Vector2(0, - cellSize.y)
]

func getTopLeftGlobal() -> Vector2:
	return load("res://Runtime/Behavior/Items/GridGeometry.gd").getTopLeftGlobal(self)

func getBottomRightGlobal() -> Vector2:
	return load("res://Runtime/Behavior/Items/GridGeometry.gd").getBottomRightGlobal(self)

func getHeightRange() -> Vector2:
	return Vector2(getTopLeftGlobal().y, getBottomRightGlobal().y)

func getTopLeftCell() -> Vector2:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getTopLeftCell(self)

func getBottomCenter() -> Vector2:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getBottomCenter(self)

func previewCells():
	return load("res://Runtime/Behavior/Items/GridGeometry.gd").previewCells(self)

func activateExtendedAffectedCells():
	for cell in affectedExtensionCells:
		collisionMap.set_cell(0, Vector2i(cell), Tiles.Affected, Vector2i.ZERO, 0)
	cacheAffectedCells()

func deactivateExtendedAffectedCells():
	for cell in affectedExtensionCells:
		collisionMap.set_cell(0, Vector2i(cell), - 1, Vector2i.ZERO, 0)
	cacheAffectedCells()

func getEffectiveOwnerType() -> int:
	return ownerType

func getInventory():
	if placed:
		return inventory
	else:
		return null

static func wasAddedToInventory(dropRes):
	return dropRes == DropResult.AddedToInventory or dropRes == DropResult.Hotswap

static func wasBought(dropRes):
	return (wasAddedToInventory(dropRes) or
			dropRes == DropResult.AddedToStorageBox or
			dropRes == DropResult.Socketed or
			dropRes == DropResult.SocketHotswap)

static func wasHotSwap(dropRes):
	return dropRes == DropResult.Hotswap or dropRes == DropResult.SocketHotswap

func addToInventory(_inventory, _occupiedCells: Array, _placedByPlayer: bool):
	return load("res://Runtime/Behavior/Items/Placement.gd").addToInventory(self, _inventory, _occupiedCells, _placedByPlayer)

func onGateItemRoll():
	if rollShopChance():
		Game.shopSceneNode.addGateItem(self)

func cacheAffectedCells():
	for color in Affected.values():
		affectedCellsCache[color] = getAffectedCellsInInventory(color)

func removeFromInventory():
	return load("res://Runtime/Behavior/Items/Placement.gd").removeFromInventory(self)

func cleanCachedAffectedItems():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").cleanCachedAffectedItems(self)

func playAffectedPlacedAnimation(newItemIsAffected: Dictionary):
	return load("res://Runtime/Behavior/Items/Placement.gd").playAffectedPlacedAnimation(self, newItemIsAffected)

func onItemAdded(item):
	return load("res://Runtime/Behavior/Items/Placement.gd").onItemAdded(self, item)

func onItemRemoved(item):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").onItemRemoved(self, item)

func onItemTypeChanged(item):
	return load("res://Runtime/Behavior/Items/Placement.gd").onItemTypeChanged(self, item)

func getAffectedCellsInInventory_cached(color):
	return affectedCellsCache.get(color, [])

func canAffectDraggedItem(item, color):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canAffectDraggedItem(self, item, color)

func onAddToInventory():
	pass

func onAffectedItemAdded(item, color: int):

	pass

func onAffectedItemRemoved(item, color: int):

	pass

func onRemoveFromInventory():
	pass

func reactToItemTypeChange(item) -> bool:
	return true

func onSold():
	pass

func onBought():
	pass

var canAffectVisual:
	get:
		return AssetStream.resolve("res://Items/Exclusive/Animations/CanAffectVisual.tscn")
var canAffectVisuals = []

func previewCanAffect():
	return load("res://Runtime/Behavior/Items/Placement.gd").previewCanAffect(self)

func clearCanAffectVisuals():
	for visual in canAffectVisuals:
		visual.returnToObjectPool()
	canAffectVisuals.clear()

func liesInStorage() -> bool:
	return ownerType == Owner.PlayerStorageBox and not dragged

func pushToStorage(targetPos = Game.STORAGEBOX.center):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").pushToStorage(self, targetPos)

func addToStorageBox(addImpulse = true, tweenBouncyness: bool = true,
	checkCollisions = true, targetPos = global_position, speed = 1.0, secondCheck = false):
	return load("res://Runtime/Behavior/Items/Placement.gd").addToStorageBox(self, addImpulse, tweenBouncyness, checkCollisions, targetPos, speed, secondCheck)

func removeFromStorage():
	Util.reparentNode(self, Game.playerNode)

	killMovebackTween()
	onStorageLeft()

func onStorageLeft():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").onStorageLeft(self)

func isInGridStorage() -> bool:
	return (getEffectiveOwnerType() == Owner.PlayerStorageBox and
		Game.gridStorage.visible)

func getGridStorageProxy():
	if not dragged and isInGridStorage():

		var proxy = Game.gridStorage.getProxy(self)
		if proxy != null:
			return proxy

	return self

func onAddedToGridStorage():
	hide()
	disablePicking()
	for particles in specificDragParticles:
		particles.instantClear()
	dragParticles.instantClear()

func onRemovedFromGridStorage():
	show()
	Game.setItemEditMode(self, false)
	for gem in getGemsNoNull():
		gem.onRemovedFromGridStorage()

func makeGrabbable(extended: bool):
	set_collision_layer_value(4, extended)

func moveToFreeSpaceInStorage(targetPos = global_position,
	addImpulse = false, speed = 1.0, secondCheck = false,
	tweenBouncyness: bool = true):
	return load("res://Runtime/Behavior/Items/Placement.gd").moveToFreeSpaceInStorage(self, targetPos, addImpulse, speed, secondCheck, tweenBouncyness)

func checkIfOutofStorageBounds():
	Util.callNextFrame(self, "checkIfOutofStorageBounds2")

func checkIfOutofStorageBounds2():
	Util.callNextFrame(self, "checkIfOutofStorageBounds3")

func checkIfOutofStorageBounds3():
	if ownerType == Owner.PlayerStorageBox:
		Game.STORAGEBOX.checkIfItemIsInStorageArea(self)

const angleStep = 45

func findFreeSpace(startPos: Vector2) -> Vector2:
	return load("res://Runtime/Behavior/Items/Placement.gd").findFreeSpace(self, startPos)

func unclip():
	global_position = findFreeSpace(global_position)

func onAddedToStorageBox():
	pass

func previewCellCollision():
	Game.PLAYER.INVENTORY.previewItem(self)

var rotationMomentum = 0
var bonusRotation = 0

const moveRotationMouseFactor = 0.015
const backforce = 5.0
const fric = 15.0
const maxAngle = 10
const moveRotationSpeed = 60.0

func _process(delta: float) -> void :
	load("res://Runtime/Behavior/Items/Interaction.gd")._process(self, delta)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void :
	if state.get_contact_count() > 0:
		lastCollisionPos = state.get_contact_local_position(0)
		lastCollider = state.get_contact_collider_object(0)
	else:
		lastCollider = null

func updateShadow():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").updateShadow(self)

func lerpAngle_local(interpolationPoint, from, to):
	sprite.rotation = lerp_angle(from, to, interpolationPoint)
	updateInsideRotationNode()
	updateShadow()

func updateInsideRotationNode():
	if insideRotationNode != null:
		insideRotationNode.global_rotation = sprite.global_rotation

func rotateRight():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").rotateRight(self)

func rotateLeft():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").rotateLeft(self)

func spawnRotationSparks(rotateRight):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").spawnRotationSparks(self, rotateRight)

func setFaceDirection(_faceDirection):
	rotateTo(_faceDirection * PI * 0.5)

func rotateTo(targetRotation, duration = 0.15):
	return load("res://Runtime/Behavior/Items/Interaction.gd").rotateTo(self, targetRotation, duration)

func rotateToDeferred(targetRotation):

	setRotation(targetRotation)

func rotationFromFaceDirection(_faceDirection):
	return _faceDirection * PI * 0.5

func getGlobalFaceDirection():
	return (int((2 * global_rotation) / PI + 2.25 * PI) + 5) % 4

func setFaceDirectionInstant(_faceDirection):

	Util.finishTween(rotationTween)
	faceDirection = _faceDirection
	rotation = rotationFromFaceDirection(faceDirection)

func setRotation(_rotation):
	global_rotation = _rotation

func getFaceDirection():
	return (int((2 * rotation) / PI + 2.25 * PI) + 5) % 4

func highlight():
	sprite.position = Vector2.ZERO
	animation.play("Highlight")

func unhighlight():
	resetSprite()

var brightColor = Color(1.3, 1.3, 1.3, 1)
var defaultColor = Color.WHITE

func setBright():
	modulate = brightColor

func resetBright():
	modulate = defaultColor

func getHoverPriority():
	if dragged: return DRAG_PRIORITY
	else: return 0

func canGainFocus():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canGainFocus(self)

func gainFocus():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").gainFocus(self)

func respondToHover():
	return load("res://Runtime/Behavior/Items/Interaction.gd").respondToHover(self)

var buildIntoRecipesTooltipScene:
	get:
		return AssetStream.resolve("res://Interface/Tooltips/BuildIntoRecipesTooltip.tscn")
var buildIntoRecipesTooltip = null
var owningBuildIntoRecipesTooltip = null
var ownerTypesWithBuildTooltip = {
	Owner.BuildViewer: true,
	Owner.PlayerStorageBox: true,
	Owner.PlayerInventory: true,
	Owner.Opponent: true,
	Owner.GridStorage: true
}

func canShowBuildIntoRecipesTooltip() -> bool:
	return load("res://Runtime/Behavior/Items/Interaction.gd").canShowBuildIntoRecipesTooltip(self)

func canShowSubBuildIntoRecipesTooltip():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canShowSubBuildIntoRecipesTooltip(self)

func showBuildIntoRecipesTooltip():
	return load("res://Runtime/Behavior/Items/Interaction.gd").showBuildIntoRecipesTooltip(self)

func getRelatedItems() -> Array:
	return descriptor.gatedItems

func getRelatedItemColumns() -> int:
	return 5

func getRelatedItemHeight() -> int:
	return 150

func getRecipeDescriptor():
	return descriptor

func hideBuildIntoRecipesTooltip():
	if buildIntoRecipesTooltip != null:
		buildIntoRecipesTooltip.discard()
		buildIntoRecipesTooltip = null

func loseFocus():
	if dragged: return

	if not focus: return

	respondToHoverEnd()
	focus = false

func respondToHoverEnd():
	return load("res://Runtime/Behavior/Items/Interaction.gd").respondToHoverEnd(self)

func activateDragParticles():
	for specificParticles in specificDragParticles:
		specificParticles.activate()

func deactivateDragParticles():
	for specificParticles in specificDragParticles:
		specificParticles.deactivate()

func updateTooltip():
	tooltipUpdateQueued = false
	if tooltip != null:
		tooltip.updateTooltip()

func queueTooltipUpdate():
	if tooltip != null and not tooltipUpdateQueued:
		tooltipUpdateQueued = true
		call_deferred("updateTooltip")

func clearTooltip():
	if tooltip != null:
		tooltip.discard()
		tooltip = null

	hideBuildIntoRecipesTooltip()
	clearCanAffectVisuals()

func mouseEntered():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").mouseEntered(self)

const hoverableWhenMenuOpen = {
	Owner.ItemLibrary: true,
	Owner.InfoPanelIcon: true,
	Owner.Tooltip: true,
	Owner.RecipeBook: true
}

func hover():
	return load("res://Runtime/Behavior/Items/Interaction.gd").hover(self)

func mouseExited():
	Game.onItemUnderMouseExited(self)
	hoverEnd()

func hoverEnd():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").hoverEnd(self)

func isHovered():
	return hovered_state or dragged

func getScaleProp() -> String:
	if hasSquishySprite:
		return "baseScale"
	else:
		return "scale"

func setSpriteScale(newScale: Vector2):
	if hasSquishySprite:
		sprite.baseScale = newScale
	sprite.scale = newScale

func resetZ():

	z_index = 1

func pickup(pickupType = PickupType.Grabbed):
	return load("res://Runtime/Behavior/Items/Interaction.gd").pickup(self, pickupType)

func onDraggedWithParentStart(parentItem):
	draggingParent = parentItem
	finishMoveback()

func finishMoveback():
	if isMovingBack():
		movebackTween.custom_step(10)
		call_deferred("resetZ")

	Util.finishTween(rotationTween)

func onDraggedWithParentEnd():
	draggingParent = null

func canSnap() -> bool:
	return draggedInsideItems.is_empty() and draggingParent == null

func reactToDropResult(result):
	return load("res://Runtime/Behavior/Items/Interaction.gd").reactToDropResult(self, result)

func drop() -> int:
	return load("res://Runtime/Behavior/Items/Interaction.gd").drop(self)

func showClickArea():
	clickArea.show()

func cancelDrag():
	return load("res://Runtime/Behavior/Items/Interaction.gd").cancelDrag(self)

func hasSameOrientationAsPickup() -> bool:
	return sameOrientationAsPickup

func emptyTweenCallback():
	pass

func killMovebackTween():
	sprite.position = Vector2.ZERO
	Util.killTween(movebackTween)
	movebackTween = null
	showClickArea()

func moveTo(fromPos, newPos, duration = 0.2, transitionType = Tween.TRANS_QUAD):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").moveTo(self, fromPos, newPos, duration, transitionType)

func setSpriteGlobalPos(pos):
	sprite.global_position = pos
	updateShadow()

func dropIntoInventory(hotswap):
	return load("res://Runtime/Behavior/Items/Interaction.gd").dropIntoInventory(self, hotswap)

func finishInsideItemsRotation():
	if not draggedInsideItems.is_empty():
		Util.finishTween(rotationTween)

func pushDraggedItemsToStorage():
	for item in draggedInsideItems:
		Util.reparentNode(item, Game.playerNode)
		item.pushToStorage()
	correctInsideItemFacedirection()
	clearDraggedInsideItems()

func pushItemsInsideToStorage():
	pass

func reparentItemsInside():
	for item in draggedInsideItems:
		Util.reparentNode(item, Game.playerNode)
	correctInsideItemFacedirection()
	clearDraggedInsideItems()

func correctInsideItemFacedirection():
	for item in draggedInsideItems:
		item.faceDirection = item.getGlobalFaceDirection()

		item.updateShaderRotation()

func clearDraggedInsideItems():
	for item in draggedInsideItems:
		item.onDraggedWithParentEnd()
	draggedInsideItems.clear()

func initSockets():
	for socket in sockets:
		socket.item = self

func hasSockets() -> bool:
	return not sockets.is_empty()

func getNumSockets() -> int:
	return sockets.size()

func showSockets():
	for s in sockets:
		s.showSocket()

func hideSockets():
	for s in sockets:
		s.hideSocket()

func hasGems() -> bool:
	for socket in sockets:
		if socket.getGem():
			return true
	return false

func pushGemsToStorage():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").pushGemsToStorage(self)

func returnToSocket(movebackDur):
	pass

func getGems() -> Array:
	var gems = []
	for socket in sockets:
		gems.push_back(socket.getGem())
	return gems

func getGemsNoNull() -> Array:
	return Util.filterNull(getGems())

func getGemData():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getGemData(self)

func setGem(socketId: int, gem):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").setGem(self, socketId, gem)

func setGemData(gemData):
	return load("res://Runtime/Behavior/Items/CombatState.gd").setGemData(self, gemData)

func getTouchedBags():
	if isBag() or not placed:
		return []
	else:
		return inventory.getBagsInCells(occupiedCells)

func getTouchedBagsCounted():
	return load("res://Runtime/Behavior/Items/CombatState.gd").getTouchedBagsCounted(self)

const defaultSounds = [
	preload("res://Assets/Sound/Thud1.wav")]
const woodSounds = [
	preload("res://Assets/Sound/Wood1.wav"),
	preload("res://Assets/Sound/Wood2.wav")]
const metalSounds = [
	preload("res://Assets/Sound/Metal1.wav"),
	preload("res://Assets/Sound/Metal2.wav")]
const leatherSounds = [
	preload("res://Assets/Sound/Cloth1.wav"),
	preload("res://Assets/Sound/Cloth2.wav")]
const glassSounds = [
	preload("res://Assets/Sound/Glass1.wav"),
	preload("res://Assets/Sound/Glass2.wav")]
const stoneSounds = [
	preload("res://Assets/Sound/Stone1.wav"),
	preload("res://Assets/Sound/Stone2.wav")]
const squishySounds = [
	preload("res://Assets/Sound/Squishy1.wav"),
	preload("res://Assets/Sound/Bite1.wav")]
const jewelrySounds = [
	preload("res://Assets/Sound/Thud6.wav"),
	preload("res://Assets/Sound/Jewelry2.wav")]
const sandSounds = [
	preload("res://Assets/Sound/Sand2.ogg"),
	preload("res://Assets/Sound/Sand3.ogg")]
const paperSounds = [
	preload("res://Assets/Sound/TurningPage3.wav"),
	preload("res://Assets/Sound/ClosingBook1.wav")]
const slimeSounds = [
	preload("res://Assets/Sound/Slime3.mp3"),
	preload("res://Assets/Sound/Slime2.wav")]
const birdSounds = [
	preload("res://Assets/Sound/Jynx1.ogg"),
	preload("res://Assets/Sound/Jynx2.ogg")]
const fireSounds = [
	preload("res://Assets/Sound/Fire1.wav"),
	preload("res://Assets/Sound/Fire2.wav")]
const iceSounds = [
	preload("res://Assets/Sound/Ice2.wav"),
	preload("res://Assets/Sound/Ice1.wav")]
const dragonSounds = [
	preload("res://Assets/Sound/Dragon1.wav"),
	preload("res://Assets/Sound/Dragon2.wav")]
const leafSounds = [
	preload("res://Assets/Sound/Leaf1.wav"),
	preload("res://Assets/Sound/Leaf2.wav")]

func playPickupSound():
	return load("res://Runtime/Behavior/Items/CombatState.gd").playPickupSound(self)

func playDropSound(volume = 0):
	return load("res://Runtime/Behavior/Items/CombatState.gd").playDropSound(self, volume)

func canBeSold() -> bool:
	return (ownerType == Owner.PlayerInventory or
		ownerType == Owner.PlayerStorageBox or
		ownerType == Owner.Socket)

func isPickingPossible() -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").isPickingPossible(self)

func canBePicked() -> bool:
	return focus and isPickingPossible() and Util.frameCounter > dropFrame

func canBeDraggedWithBag() -> bool:
	return (pickingEnabled and
			not Util.isTweenRunning(movebackTween) and
			not draggingParent)

func canBeDropped() -> bool:
	return dragged and Util.frameCounter > pickupFrame

func _input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Items/CombatState.gd")._input(self, event)

func cacheAffectedItemsForCombat():
	for color in Affected.values():
		cachedAffectedItems[color] = currentAffectedItems[color].keys()

func prepare():
	cacheAffectedItemsForCombat()

	disablePicking()
	chanceRng.reset()
	damageRangeRng.reset()
	for gem in getGemsNoNull():
		gem.prepare()
	onPrepare()

func onPrepare():
	pass

func preCombatStart():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").preCombatStart(self)

func onPreCombatStart():
	pass

func hasStartofBattle() -> bool:
	return has_method("onCombatStart")

func combatStart():
	updateShaderRotation()

	for gem in getGemsNoNull():
		gem.combatStart()

	if hasStartofBattle():
		me.onCombatStart()

func postCombatStart():
	for gem in getGemsNoNull():
		gem.postCombatStart()

	onPostCombatStart()

func onPostCombatStart():
	pass

func repeatCombatStart():
	onPreCombatStart()
	me.onCombatStart()
	onPostCombatStart()

func resetSprite():
	return load("res://Runtime/Behavior/Items/CombatState.gd").resetSprite(self)

func combatEnd():

	set_physics_process(false)
	disconnectCombat()
	for gem in getGemsNoNull():
		gem.combatEnd()
	onCombatEnd()

func onCombatEnd():
	pass

func combatToShop():
	if isOwnedByOpponent():
		disableTooltip()
	else:
		resetSprite()
		cachedAffectedItems.clear()

func shopEntered(craft: bool):
	return load("res://Runtime/Behavior/Items/CombatState.gd").shopEntered(self, craft)

func onShopEntered():
	pass

func startFusing_inShop():
	return

func getCraftingPriority() -> int:
	if isGem(): return CraftingPriority.Gem

	for bonded in bondedIngredients:
		if bonded.isGem():
			return CraftingPriority.Mixed

	return CraftingPriority.NonGem

func addToCraftingQueue():
	if readyToFuse():
		Game.craftingPriorities[self] = getCraftingPriority()

func combatToTitle():
	if isOwnedByOpponent():
		disableTooltip()

func readyToFuse() -> bool:
	return curRecipe and curRecipe.getProgress(bondedIngredients) == 1

func startFusing(delay = PRE_FUSE_DUR):
	return

func readyToTransform() -> bool:
	return false

func giveGold(amount: int):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").giveGold(self, amount)

func empowerEnd():
	pass

func affectsEmpty(color) -> bool:
	return false

func canAffect(item) -> bool:
	return false

func canAffect_secondary(item) -> bool:
	return false

func canAffect_tertiary(item) -> bool:
	return false

func canAffect_lightning(item) -> bool:
	return false

func canAffect_color(item, color):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canAffect_color(self, item, color)

func isAffectingDistinct(color = Affected.Primary) -> bool:
	return false

func getNumDistinctAffectedItems(color = Affected.Primary) -> int:
	var distinctAffectedDescriptors = {}
	for item in getAffectedItems(color):
		distinctAffectedDescriptors[item.descriptor] = true
	return distinctAffectedDescriptors.size()

func getMainType() -> int:
	return descriptor.types[0]

func getTypes() -> Array:
	return dynamicTypes.keys() + descriptor.types

func hasType(type: int) -> bool:
	return type in descriptor.types or type in dynamicTypes

func getNumStaticTypes() -> int:
	return descriptor.getTypes().size()

func getTypeMultiplicity(type: int) -> int:
	return 1 if hasType(type) else 0

func addDynamicType(type: int, byItem: Item):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").addDynamicType(self, type, byItem)

func removeDynamicType(type: int, byItem: Item):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").removeDynamicType(self, type, byItem)

func hasDynamicType(type: int, fromItem: Item):
	if type in dynamicTypes:
		if fromItem.get_instance_id() in dynamicTypes[type]:
			return true

	return false

func clearDynamicTypes():
	dynamicTypes.clear()

func getTranslatedTypeName(type) -> String:
	return descriptor.getTranslatedTypeName(type)

func getTypeDescription(type) -> String:
	return Util.tra("TYPE_" + Type.keys()[type] + "_DESCR")

func getRarity() -> int:
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").getRarity(self)

func getTranslatedRarity() -> String:
	return getRarityName(getRarity())

static func getRarityName(_rarity: int) -> String:
	return Util.tr("RARITY_" + Rarity.keys()[_rarity])

func getBaseMinDamage() -> int:
	if pve_is_view(): return int(ceil(pve_stat("base_damage")))
	return descriptor.minDam

func getBaseMaxDamage() -> int:
	if pve_is_view(): return int(ceil(pve_stat("base_damage")))
	return descriptor.maxDam

func getBaseAverageDamage() -> float:
	return (getBaseMinDamage() + getBaseMaxDamage()) / 2.0

func canBeEmpowered() -> bool:
	return isWeapon() and canDamage()

func canActivate() -> bool:
	if pve_is_view(): return pve_stat("base_cooldown") > 0
	return descriptor.canActivate

func canBlock() -> bool:
	return getBlock() > 0

func getTypedDamageFactor(damSource) -> float:
	var typedDmgFactor = 1.0
	for type in damSource.types:
		typedDmgFactor += character().typedDamageFactors[type]

	return typedDmgFactor

func getMinDamage(damSource = damageSource) -> int:
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").getMinDamage(self, damSource)

func getMaxDamage(damSource = damageSource) -> int:
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").getMaxDamage(self, damSource)

func getAverageDamage() -> float:
	return (getMinDamage() + getMaxDamage()) / 2.0

func getDamageRange() -> String:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getDamageRange(self)

func randDamage() -> int:
	return Util.rng.randi_range(getMinDamage(), getMaxDamage())

func isStatModified(statVal) -> int:
	if statVal == 0:
		return StatModified.No
	elif statVal > 0:
		return StatModified.Positive
	else:
		return StatModified.Negative

func isDamageModified() -> int:
	var bonusDam = getAverageDamage() - getBaseAverageDamage()
	return isStatModified(bonusDam)

func getDPS() -> float:
	return ((getMinDamage() + getMaxDamage()) * 0.5) / getModifiedCooldown()

func isDPSModified() -> int:
	var baseDPS = getBaseAverageDamage() / getCooldown()
	var modifiedDPS = getAverageDamage() / getModifiedCooldown()
	return isStatModified(modifiedDPS - baseDPS)

func getSpeed() -> float:
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").getSpeed(self)

func getStackSpeedMods():
	return (character().getHeat() - character().getCold()) * 0.02

func hasCooldown() -> bool:
	if pve_is_view(): return pve_stat("base_cooldown") > 0
	return descriptor.cd != 0

func isCooldownActive() -> bool:
	return is_physics_processing()

func logCooldown() -> bool:
	return hasCooldown()

func getBaseCooldown() -> float:
	if pve_is_view(): return pve_stat("base_cooldown")
	return baseCooldownOverride

func getBaseCooldownIndex(index: int) -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getBaseCooldownIndex(self, index)

func getCooldown() -> float:
	if pve_is_view(): return pve_stat("base_cooldown")
	var override = statDisplayOverrides[Stat.BaseCooldown]
	if override: return override

	return baseCooldownOverride

func getCooldownIndex(index: int) -> float:
	return getBaseCooldownIndex(index)

func isCooldownModified() -> int:
	var baseCd = getBaseCooldown()
	var curCd = getModifiedCooldown()
	return isStatModified(baseCd - curCd)

func getModifiedCooldown() -> float:
	if pve_is_view(): return pve_stat("cooldown")
	return getCooldown() / getSpeed()

func getModifiedCooldownIndex(index: int):
	if pve_is_view(): return pve_stat("cooldown") if index == 0 else 0.0
	return getCooldownIndex(index) / getSpeed()

func adjustCooldown():
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").adjustCooldown(self)

func getBaseAccuracy() -> float:
	if pve_is_view(): return 100.0
	return descriptor.accuracy

func getAccuracy() -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getAccuracy(self)

func getCombatDisplayAccuracy() -> String:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getCombatDisplayAccuracy(self)

func isAccuracyModified() -> int:
	return isStatModified(getAccuracy() - getBaseAccuracy())

func getDisplayCritChance() -> String:
	var c = getCritChancePercent()
	if c > 100:
		return ">100"

	else:
		return str(snapped(c, 0.1))

func getBaseChance() -> float:
	return descriptor.chance

func isChance1Modified() -> int:
	return isStatModified(getChance() - getBaseChance())

func getBaseChance2() -> float:
	return descriptor.chance2

func isChance2Modified() -> int:
	return isStatModified(getChance2() - getBaseChance2())

func applyBonusChance(toChance, index) -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").applyBonusChance(self, toChance, index)

func getChance() -> float:
	var override = statDisplayOverrides[Stat.Chance]
	if override: return override

	return clamp(applyBonusChance(getBaseChance(), 1), 0, 100)

func getChance2() -> float:
	var override = statDisplayOverrides[Stat.Chance2]
	if override: return override

	return clamp(applyBonusChance(getBaseChance2(), 2), 0, 100)

func getShopChance() -> float:
	return descriptor.getShopChance()

func canModifyChance() -> bool:
	return getBaseChance() > 0

func getP(index) -> float:
	return descriptor.getP(index)

func getP_check(index) -> float:
	assert (descriptor.params[index] != 0)
	return descriptor.params[index]

func getP1() -> float:
	return getP_check(0)

func getP2() -> float:
	return getP_check(1)

func getP3() -> float:
	return getP_check(2)

func getP4() -> float:
	return getP_check(3)

func getP5() -> float:
	return getP_check(4)

func getP6() -> float:
	return getP_check(5)

func getP7() -> float:
	return getP_check(6)

func getP8() -> float:
	return getP_check(7)

func getP9() -> float:
	return getP_check(8)

func getP10() -> float:
	return getP_check(9)

func getP_m(paramName: String) -> float:
	var baseVal = getP(paramName)
	return getParamModified(paramName, baseVal)

func getParamModified(paramName: String, baseVal) -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getParamModified(self, paramName, baseVal)

func modifyParam(paramName: String, amount: float):
	Util.dictAdd(paramMult, paramName, amount, 1.0)

func modifyParam_add(paramName: String, amount: float):
	Util.dictAdd(paramAdd, paramName, amount)

func hasCharacter() -> bool:
	return placed and character() != null

func character():
	if placed:
		return inventory.character
	else:
		return Game.PLAYER

func opponent():
	return character().opponent

func hasOpponent() -> bool:
	return hasCharacter() and opponent() != null

func getPrice():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getPrice(self)

func getBaseSellPrice():
	if pve_is_view(): return Expedition.bridge.sell_price(self)
	return descriptor.getSellPrice()

func getSellPrice():
	if pve_is_view(): return Expedition.bridge.sell_price(self)
	return descriptor.getSellPrice()

func getSalePrice():
	if pve_is_view(): return Expedition.bridge.price_for_slot(int(get_meta("pve_shop_index", -1)))
	return descriptor.getSalePrice()

func getSalesMultiplier():
	return 1.0

func getBlock() -> int:
	if pve_is_view(): return 0
	return descriptor.block

func getBaseStaminaCost() -> float:
	if pve_is_view(): return float(pve_definition().get("stamina_cost", 0.0))
	return descriptor.staminaCost

func getStaminaCost() -> float:
	if pve_is_view(): return getBaseStaminaCost()
	var override = statDisplayOverrides[Stat.StaminaCost]
	if override: return override

	return getBaseStaminaCost() * staminaFactor

func isStaminaModified() -> int:
	return isStatModified(getBaseStaminaCost() - getStaminaCost())

func getBaseStaminaPerSecond() -> float:
	return getBaseStaminaCost() / getCooldown()

func getStaminaPerSecond() -> float:
	return getStaminaCost() / getModifiedCooldown()

func isStaminaPerSecondModified() -> int:
	var baseSPS = getBaseStaminaPerSecond()
	var modifiedSPS = getStaminaPerSecond()
	return isStatModified(baseSPS - modifiedSPS)

func getCritChancePercent() -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getCritChancePercent(self)

func addCritChancePercent(amount):
	critChancePercent += amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.CritChance)

func reduceCritChancePercent(amount):
	critChancePercent -= amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.CritChance)

func changeCritChancePercent(amount):
	critChancePercent += amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.CritChance)

func getCritTokens() -> int:
	return critTokens

func addCritTokens(amount):
	critTokens += amount

func useCritToken():
	critTokens -= 1

func addCritSeverity(amount):
	critSeverity += amount

func getCritSeverity() -> float:
	return critSeverity

func addBonusChance(amount):
	bonusChancePercent_mult += amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Chance)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Chance2)

func addBonusChance_additive(amount1, amount2 = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").addBonusChance_additive(self, amount1, amount2)

func addAccuracy(amount):
	bonusAccuracy += amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Accuracy)

func addBonusDamage(damage, removable: bool = true):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").addBonusDamage(self, damage, removable)

func changeVaryingDamage(damage):
	addBonusDamage(damage, false)

func addMinDamage(damage):
	bonusMinDam += damage
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MinDamage)

func addMaxDamage(damage):
	bonusMaxDam += damage
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MaxDamage)

func reduceBonusDamage(damage, showLabel: bool = true, removable: bool = true):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").reduceBonusDamage(self, damage, showLabel, removable)

func purgeDamage(damage):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").purgeDamage(self, damage)

func reduceMinDamage(damage):
	bonusMinDam -= damage
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MinDamage)

func reduceMaxDamage(damage):
	bonusMaxDam -= damage
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MaxDamage)

func addBonusDamageFactor(factor):
	bonusDamageFactor += factor
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MinDamage)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MaxDamage)

func reduceBonusDamageFactor(factor):
	bonusDamageFactor -= factor
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MinDamage)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.MaxDamage)

func changeStaminaFactor(amount):
	staminaFactor += amount / 100.0
	staminaFactor = max(0, staminaFactor)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.StaminaCost)

func giveDoubleActivationChance(_chance):
	doubleActivationChance += _chance / 100.0

func giveDoubleAttackEffectChance(_chance):
	doubleAttackEffectChance += _chance / 100.0

func rollDoubleAttackEffect() -> int:
	return int(Util.flip(doubleAttackEffectChance))

func dealDamage(triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").dealDamage(self, triggerEvent)

func dealEffectDamage(damage, triggerEvent = null, _damageSource = damageSource):
	_damageSource.updateEffect(self, damage)
	var damageRes = opponent().takeDamage(_damageSource, triggerEvent)
	return damageRes

func hasAttackEffect() -> bool:
	return (hasPreDealDamageEarlyEffect or
			hasPreDealDamageLateEffect or
			hasDealtDamageEffect)

func preDealDamage_early(damageRes):
	EventBus.emitSignal(self, "pre_deal_damage_early", [damageRes])

func preDealDamage_late(damageRes):
	EventBus.emitSignal(self, "pre_deal_damage_late", [damageRes])

func dealtDamage(damageRes):
	if damageRes.hasHit():
		countDamage(damageRes.damage)
	else:
		addMetric(Game.ItemMetrics.Misses)

func countDamage(damage):
	addMetric(Game.ItemMetrics.Damage, damage)

func inflictFatigueDamage(fatigueIncrease = 1):
	opponent().addFatigueDamage(fatigueIncrease)
	opponent().takeFatigueDamage(self)

func addMetric(metricsIndex, amount = 1, playerId = null, withNextEvent = false):
	itemMetrics[metricsIndex] += amount
	Game.combatLog.snapshotItemMetric(self, metricsIndex, playerId, withNextEvent)

func getMetric(metricsIndex: int):
	return itemMetrics[metricsIndex]

func giveStamina(amount = 1, triggerEvent = null):
	character().gainStamina(amount, self, triggerEvent)

func fillUpStamina():
	character().fillUpStamina()

var outOfStaminaLabelScene:
	get:
		return AssetStream.resolve("res://Interface/OutOfStaminaLabel.tscn")
const outOfStaminaSound = preload("res://Assets/Sound/Fanfare_sadtoot.ogg")

func playOutOfStaminaAnimation():
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").playOutOfStaminaAnimation(self)

func useStamina(amount = getStaminaCost()):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").useStamina(self, amount)

func drainStamina(amount, triggerEvent = null):
	return opponent().drainStamina(amount, self, triggerEvent)

func giveMaxStamina(amount):
	character().giveMaxStamina(amount)

func giveMaxStaminaTemporary(amount, triggerEvent = null, filled: bool = true):
	character().gainMaxStaminaTemporary(amount, self, triggerEvent, filled)

func giveMaxHealth(amount = getP_m("maxhealth"), triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").giveMaxHealth(self, amount, triggerEvent)

func getAffectedGoldValue() -> int:
	var gold = 0
	for item in getAffectedItems_nocache():
		gold += item.getPrice()
	return gold

func prepareReplacement():
	Game.replacementPending = true
	prepareDiscard()

func finishReplacement():
	Game.replacementPending = false

func prepareDiscard():
	if hovered_state:
		hoverEnd()
	clearTooltip()
	disableTooltip()
	disablePicking()
	disableFocus()
	Game.onItemUnderMouseExited(self)

func discard(discardGems = true):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").discard(self, discardGems)

func popIn(withParticles: bool = true, speed = 1.0, jump = false):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").popIn(self, withParticles, speed, jump)

func disappear():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").disappear(self)

func appearInLibrary():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").appearInLibrary(self)

func createParticles(scene, baseScale = Vector2.ONE):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").createParticles(self, scene, baseScale)

func deactivateParticles():
	for particles in specificDragParticles:
		if particles is GPUParticles2D and not particles.emitting:
			particles.restart()
			particles.emitting = false

func makeRigidBody():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").makeRigidBody(self)

func dropImpulse(direction = null, tweenBouncyness: bool = true):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").dropImpulse(self, direction, tweenBouncyness)

func makeNonRigidBody():
	mode = 1
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	sleeping = true

func rollChance(chance = getBaseChance()) -> bool:
	return chanceRng.rollPercent(applyBonusChance(chance, 1))

func rollChance2() -> bool:
	return chanceRng.rollPercent(applyBonusChance(descriptor.chance2, 2))

func rollShopChance(shopChance = descriptor.shopChance) -> bool:
	return chanceRng.rollPercent(shopChance)

func checkTriggerCount(limit: int) -> bool:
	if Util.time > triggersThisFrame:
		triggersThisFrame = 1
		lastTriggerTime = Util.time
	else:
		triggersThisFrame += 1
		if triggersThisFrame > limit:
			return false
	return true

func trigger():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").trigger(self)

func doCooldownEffect():
	pass

func setBaseCooldown(newBaseCd):
	baseCooldownOverride = newBaseCd
	updateBaseCooldown()

func resetBaseCooldown():
	setBaseCooldown(descriptor.cd)

func updateBaseCooldown():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").updateBaseCooldown(self)

func _physics_process(delta: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd")._physics_process(self, delta)

func getCooldownEncoded():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getCooldownEncoded(self)

func reconstructCooldown(encodedCd, timeSinceEntry):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").reconstructCooldown(self, encodedCd, timeSinceEntry)

func advanceCooldownPercent(amount):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").advanceCooldownPercent(self, amount)

func advanceCooldownSeconds(amount):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").advanceCooldownSeconds(self, amount)

func miniActivate():
	if animation.current_animation == "":
		if consumed:
			animation.play("MiniActivate_consumed")
		else:
			animation.play("MiniActivate")

func playActivationAnimation_Scale(maxScale: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").playActivationAnimation_Scale(self, maxScale)

func playActivationAnimation_Jump(height, maxScale: float = 1.0):
	return load("res://Runtime/Behavior/Items/CombatEffects.gd").playActivationAnimation_Jump(self, height, maxScale)

func playActivationAnimation_JumpSquash(height, intensity = 0.2):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").playActivationAnimation_JumpSquash(self, height, intensity)

func playActivationAnimation(aniType = descriptor.activationAni,
	consume: bool = false):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").playActivationAnimation(self, aniType, consume)

func playActivationSound():
	playDropSound( - 6)

func activate(damageRes = null, playCombatAni = true, consume = false,
	animationOverride = descriptor.activationAni):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").activate(self, damageRes, playCombatAni, consume, animationOverride)

func activateFromEvent(event):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").activateFromEvent(self, event)

func spawnLabel(type, amount):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").spawnLabel(self, type, amount)

func spawnLabel_other(type, amount):
	if Settings.getVal(Settings.Setting.buff_labels):
		Util.spawnLabelOnItem(type, self, amount)

func consume(damageRes = null, playCombatAni = true):
	activate(damageRes, playCombatAni, true)
	consumed = true

func setState(newState, withNextEvent: bool = false, event = null):
	Game.combatLog.snapshotItemState(self, newState, withNextEvent, event)
	onStateChanged(newState)

func onStateChanged(newState):
	pass

func heal(amount: int = getP_m("heal"), triggerEvent = null):
	var healed = character().heal(amount, self, triggerEvent)

func stun(duration, triggerEvent = null):
	opponent().stun(duration, self, triggerEvent)

func getBaseSpeed() -> float:
	return speedScale

func getStat(stat):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").getStat(self, stat)

func setStat(stat, value):
	statDisplayOverrides[stat] = value
	queueTooltipUpdate()

func addSpeed(amount):
	speedScale += amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Speed)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Cooldown)

func reduceSpeed(amount):
	speedScale -= amount
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Speed)
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Cooldown)

func giveBuffPower(buffType, power):
	buffPowers[buffType] += power

func changeHealAmp(amount):
	modifyParam("heal", amount)
	modifyParam("lifesteal", amount)

func getAmplificationChancePercent(buffType):
	return buffAmplificationChances[buffType]

func changeAmplificiationChancePercent(buffType, chance):
	buffAmplificationChances[buffType] += chance

func changeAmplificiationChancePercent_allBuffs(chance):
	for buff in Game.getBuffs():
		changeAmplificiationChancePercent(buff, chance)

func changeAmplificiationChancePercent_allDebuffs(chance):
	for buff in Game.getDebuffs():
		changeAmplificiationChancePercent(buff, chance)

func changeNullifyChancePercent(buffType, chance):
	buffAmplificationChances[buffType] -= chance

func giveReflectStacks(amount):
	character().changeDebuffReflectStacks(amount)

func stackChanged(stackType: int, amount: int, onPlayer: bool, used: bool = false):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").stackChanged(self, stackType, amount, onPlayer, used)

func staminaChanged(amount: float, changeType: int, withNextEvent: bool = false):
	var index = getMultiMetricIndex(changeType, Game.ItemMetrics.Stamina)

	addMetric(index, amount, character().playerId, withNextEvent)

func giveBlock(amount = getBlock(), canTriggerEffects = true, triggerEvent = null):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").giveBlock(self, amount, canTriggerEffects, triggerEvent)

func removeBlock(amount, triggerEvent = null):
	var event = opponent().loseBlock(amount, self, triggerEvent)
	if event:
		countDamage( - event.getAmount())

func loseBlock(amount, triggerEvent = null):
	character().loseBlock(amount, self, triggerEvent)

func useBlock(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Block, amount, self, triggerEvent)

func giveStacks(target, type: int, amount, triggerEvent = null):
	if amount > 0:
		return target.gainStacks(type, round(amount * buffPowers[type]), self, triggerEvent)
	return null

func giveStacksTemporary(target, type: int, amount, duration, triggerEvent = null):
	if amount > 0:
		return target.gainStacksTemporary(type, round(amount * buffPowers[type]), duration, self, triggerEvent)
	return null

func onTemporaryStacksTimeout(buffType):
	pass

func stealStack(type: int, amount, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").stealStack(self, type, amount, triggerEvent)

func giveSpikes(amount, triggerEvent = null):
	giveStacks(character(), Game.EventType.Spikes, amount, triggerEvent)

func removeSpikes(amount, triggerEvent = null):
	opponent().loseSpikes(amount, self, triggerEvent)

func loseSpikes(amount, triggerEvent = null):
	character().loseSpikes(amount, self, triggerEvent)

func useSpikes(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Spikes, amount, self, triggerEvent)

func giveVampirism(amount, triggerEvent = null):
	return giveStacks(character(), Game.EventType.Vampirism, amount, triggerEvent)

func removeVampirism(amount, triggerEvent = null):
	opponent().loseVampirism(amount, self, triggerEvent)

func useVampirism(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Vampirism, amount, self, triggerEvent)

func loseVampirism(amount, triggerEvent = null):
	character().loseVampirism(amount, self, triggerEvent)

func inflictPoison(amount, triggerEvent = null):
	return giveStacks(opponent(), Game.EventType.Poison, amount, triggerEvent)

func selfInflictPoison(amount, triggerEvent = null):
	return giveStacks(character(), Game.EventType.Poison, amount, triggerEvent)

func cleansePoison(amount: int, triggerEvent = null) -> int:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").cleansePoison(self, amount, triggerEvent)

func inflictBlind(amount, triggerEvent = null):
	giveStacks(opponent(), Game.EventType.Blind, amount, triggerEvent)

func selfInflictBlind(amount, triggerEvent = null):
	return giveStacks(character(), Game.EventType.Blind, amount, triggerEvent)

func cleanseBlind(amount: int, triggerEvent = null) -> int:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").cleanseBlind(self, amount, triggerEvent)

func giveRegeneration(amount, triggerEvent = null):
	return giveStacks(character(), Game.EventType.Regeneration, amount, triggerEvent)

func removeRegeneration(amount, triggerEvent = null):
	return opponent().loseRegeneration(amount, self, triggerEvent)

func useRegeneration(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Regeneration, amount, self, triggerEvent)

func giveLucky(amount, triggerEvent = null):
	return giveStacks(character(), Game.EventType.Lucky, amount, triggerEvent)

func tryUseLucky(amount, triggerEvent = null):
	if character().getLucky() >= amount:
		useLucky(amount, triggerEvent)
		return true
	else:
		return false

func loseLucky(amount, triggerEvent = null):
	character().loseLucky(amount, self, triggerEvent)

func removeLucky(amount, triggerEvent = null):
	opponent().loseLucky(amount, self, triggerEvent)

func useLucky(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Lucky, amount, self, triggerEvent)

func giveMana(amount, triggerEvent = null):
	giveStacks(character(), Game.EventType.Mana, amount, triggerEvent)

func giveMana_capped(amount, maximum, triggerEvent = null):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").giveMana_capped(self, amount, maximum, triggerEvent)

func checkMana(amount) -> bool:
	return character().getMana() >= amount

func useMana(amount, triggerEvent = null):
	return character().useMana(amount, self, triggerEvent)

func tryUseMana(amount, triggerEvent = null):
	var curMana = character().getMana()
	if curMana < amount:
		return null
	else:
		return useMana(amount, triggerEvent)

func removeMana(amount, triggerEvent = null):
	opponent().loseMana(amount, self, triggerEvent)

func inflictCold(amount, triggerEvent = null):
	giveStacks(opponent(), Game.EventType.Cold, amount, triggerEvent)

func cleanseCold(amount: int, triggerEvent = null) -> int:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").cleanseCold(self, amount, triggerEvent)

func giveHeat(amount, triggerEvent = null):
	giveStacks(character(), Game.EventType.Heat, amount, triggerEvent)

func loseHeat(amount, triggerEvent = null):
	character().loseHeat(amount, self, triggerEvent)

func useHeat(amount, triggerEvent = null):
	return character().useStacks(Game.EventType.Heat, amount, self, triggerEvent)

func giveEmpower(amount, triggerEvent = null):
	giveStacks(character(), Game.EventType.Empower, amount, triggerEvent)

func loseEmpower(amount, triggerEvent = null):
	character().loseEmpower(amount, self, triggerEvent)

func healthToBlock(health: float, block, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").healthToBlock(self, health, block, triggerEvent)

func getModifiedEffectDamage(baseDamage):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getModifiedEffectDamage(self, baseDamage)

func stealLife(damage, lifestealFactor: float = 1.0, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").stealLife(self, damage, lifestealFactor, triggerEvent)

func giveCritTokens(amount):
	character().gainCritTokens(amount)

const chargeSound = preload("res://Assets/Sound/Electricity1.ogg")

func sendCharge(durPerTile: float, cells: Array, speedFactor: float, event):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").sendCharge(self, durPerTile, cells, speedFactor, event)

func chargeReceived(charge):
	numCharges += 1
	if hasOnChargeReceivedEffect:
		me.onChargeReceived(charge)

func chargeLeft(charge):
	numCharges -= 1
	if hasOnChargeLeftEffect:
		me.onChargeLeft(charge)

func reactsToCharges() -> bool:
	return hasOnChargeReceivedEffect or hasOnChargeLeftEffect

func changeChargedItemStat(charge, cellIndex, flatVal, valPerTile):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").changeChargedItemStat(self, charge, cellIndex, flatVal, valPerTile)

func clearSpriteMaterial():
	sprite.set_material(null)

func giveProgressMaterial():
	sprite.set_material(progressMaterial)

func getSizeInCells() -> Vector2:
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").getSizeInCells(self)

func getTextureSize() -> Vector2:
	return sprite.texture.get_size() * sprite.global_scale

func scaleToFit(maxSize: Vector2, maxScale: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").scaleToFit(self, maxSize, maxScale)

func getSpriteOffset() -> Vector2:
	return - sprite.offset * sprite.global_scale * 0.5

func getGlobalCenter() -> Vector2:
	return global_position - getSpriteOffset().rotated(global_rotation) * 2.0

func getTextureSize_local() -> Vector2:
	return sprite.texture.get_size() * sprite.scale * scale

func scaleToFit_local(maxSize: Vector2, maxScale: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").scaleToFit_local(self, maxSize, maxScale)

func getSpriteOffset_local() -> Vector2:
	return - sprite.offset * sprite.scale * scale * 0.5

func setTexture(newTex):
	sprite.texture = newTex
	initSpriteMaterial()

func updateShadowTexture():
	shadows[0].texture = sprite.texture

func initSpriteMaterial():
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").initSpriteMaterial(self)

func updateShaderRotation():
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").updateShaderRotation(self)

var shaderTween
var canCancelShaderTween = true
var nonRotatedProgress = 0.0

func allowCancelShaderTween():
	canCancelShaderTween = true

func rotateProgress(progress: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").rotateProgress(self, progress)

func showCooldownSmooth(progress: float, fill: bool = false):
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").showCooldownSmooth(self, progress, fill)

func showCooldown(progress: float):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").showCooldown(self, progress)

func activateCooldown():
	set_physics_process(true)

func deactivateCooldown():
	set_physics_process(false)

func onAfterEffectFinished(_consume = true):
	deactivateCooldown()
	showCooldownSmooth(0, true)
	if _consume:
		consume()

func getRelativeOpponentHealth():
	return opponent().getRelativeHealth()

func getRelativeHealth():
	return character().getRelativeHealth()

const MISS_OFFSET = 100.0

func createAnimation():
	return load("res://Runtime/Behavior/Items/AnimationAndEffects.gd").createAnimation(self)

func playAnimation(hit: bool = true):
	if not descriptor.animationScene: return

	var ani = createAnimation()
	ani.intialize(hit)

func isGem():
	return false

func hasTag(tag) -> bool:
	return descriptor.hasTag(tag)

func canDamage() -> bool:
	return getBaseMinDamage() > 0 or hasTag(Tag.Lifesteal)

func canUseStamina() -> bool:
	return getBaseStaminaCost() > 0

func canHealOrLifesteal() -> bool:
	return descriptor.hasParam("heal") or descriptor.hasParam("lifesteal")

func gainsStack(stackType) -> bool:
	return descriptor.gainedStacks & stackType

func removesStack(stackType) -> bool:
	return descriptor.removedStacks & stackType

func usesStack(stackType) -> bool:
	return descriptor.usedStacks & stackType

func gainsBuffs() -> bool:
	return descriptor.gainedStacks & Stack.Buff

func usesBuffs() -> bool:
	return descriptor.usedStacks & Stack.Buff

func inflictsDebuffs() -> bool:
	return descriptor.gainedStacks & Stack.Debuff

func isBattleRageItem() -> bool:
	return descriptor.hasBattleRageEffect

func connectToCharacterBuffs(methodName):
	for buff in Game.getBuffs():
		connectForCombat(character(), character().buffs[buff].signalName, methodName)

func connectToCharacterDebuffs(methodName):
	for debuff in Game.getDebuffs():
		connectForCombat(character(), character().buffs[debuff].signalName, methodName)

func connectToOpponentDebuffs(methodName):
	for debuff in Game.getDebuffs():
		connectForCombat(opponent(), opponent().buffs[debuff].signalName, methodName)

func connectToOpponentBuffs(methodName):
	for buff in Game.getBuffs():
		connectForCombat(opponent(), opponent().buffs[buff].signalName, methodName)

func pickRandomStacks(stackTypes, numStacks, target, priorityStack = null):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").pickRandomStacks(self, stackTypes, numStacks, target, priorityStack)

func pickRandomStacksToGive(stackTypes, numStacks):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").pickRandomStacksToGive(self, stackTypes, numStacks)

func giveRandomBuffs(numBuffs: int, triggerEvent = null, availableBuffs = Game.getBuffs(),
	target = character()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").giveRandomBuffs(self, numBuffs, triggerEvent, availableBuffs, target)

func giveAllBuffs(numBuffs = 1, triggerEvent = null):
	for buff in Game.getBuffs():
		giveStacks(character(), buff, numBuffs)

func useRandomBuffs(numBuffs, triggerEvent = null, availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").useRandomBuffs(self, numBuffs, triggerEvent, availableBuffs)

func inflictRandomDebuffs(numDebuffs, triggerEvent = null, availableDebuffs = Game.getDebuffs()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").inflictRandomDebuffs(self, numDebuffs, triggerEvent, availableDebuffs)

func removeRandomBuffs(numBuffs, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").removeRandomBuffs(self, numBuffs, triggerEvent)

func stealRandomBuff(numBuffs, triggerEvent = null,
	possibleBuffs = Game.getBuffs(), priorityBuff = null):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").stealRandomBuff(self, numBuffs, triggerEvent, possibleBuffs, priorityBuff)

func cleanseRandomDebuffs(numDebuffs, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").cleanseRandomDebuffs(self, numDebuffs, triggerEvent)

func getLeastStacks(numStacks, target, availableStacks):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").getLeastStacks(self, numStacks, target, availableStacks)

func giveLeastBuffs(numBuffs, target = character(), triggerEvent = null,
	availableBuffs = Game.getBuffs()):

	var pickedStacks = getLeastStacks(numBuffs, target, availableBuffs)

	for buffType in pickedStacks:
		giveStacks(target, buffType, pickedStacks[buffType], triggerEvent)

func getMostStacks(target, availableStacks):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").getMostStacks(self, target, availableStacks)

func giveMostBuffs(numBuffs, triggerEvent = null, availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").giveMostBuffs(self, numBuffs, triggerEvent, availableBuffs)

func removeMostBuffs(numBuffs, triggerEvent = null, use: bool = false, availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").removeMostBuffs(self, numBuffs, triggerEvent, use, availableBuffs)

func getStackFraction(target, fraction: float,
	limit: int, availableStacks):
	return load("res://Runtime/Behavior/Items/StatusEffects.gd").getStackFraction(self, target, fraction, limit, availableStacks)

func multiplyBuffsLimit(bonus: float, limit: int,
	availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").multiplyBuffsLimit(self, bonus, limit, availableBuffs)

func removeBuffsFraction(fraction: float, limit: int,
	triggerEvent = null, availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").removeBuffsFraction(self, fraction, limit, triggerEvent, availableBuffs)

func stealBuffsFraction(fraction: float, limit: int,
	triggerEvent = null, availableBuffs = Game.getBuffs()):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").stealBuffsFraction(self, fraction, limit, triggerEvent, availableBuffs)

func changeAllItemsCritRate(amount):
	for item in inventory.getItems():
		if item.canBeEmpowered():
			item.changeCritChancePercent(amount)

func hasInventoryDuration() -> bool:
	return descriptor.hasParam("dur")

func connectForCombat(emitter, signalName, methodName, binds = []):
	EventBus.connectEvent(emitter, signalName, self, methodName)

func connectForCombat_signal(emitter, signalName, methodName, binds = []):
	var newConnection = SignalConnection.new(emitter, signalName,
		self, methodName, binds)
	combatConnections.push_back(newConnection)

func disconnectCombat():
	for connection in combatConnections:
		connection.destroy()
	combatConnections.clear()

func placeGeneratedItem(item, candidateCells):
	return load("res://Runtime/Behavior/Items/CraftingQueries.gd").placeGeneratedItem(self, item, candidateCells)

func reveal():
	sprite.set_material(grayscaleMaterial)
	animation.play("Reveal")

func setRevealed():
	reveal()
	animation.advance(1)

func isCrafted() -> bool:
	return descriptor.isCraftedItem()

func isTreasure() -> bool:
	return descriptor.randomUniquePool

func shift(direction: Vector2):
	return load("res://Runtime/Behavior/Items/CraftingQueries.gd").shift(self, direction)

func isMovingBack() -> bool:
	return Util.isTweenRunning(movebackTween)

func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE:
		Game.itemHoverEnd(self)
		if is_instance_valid(tooltip):
			clearTooltip()
		for visual in bondVisuals:
			if is_instance_valid(visual):
				visual.breakInstant()

func isShowCaseItem() -> bool:
	return character() == null

func getAllInInventoryOfType(descr) -> Array:
	if isOwnedByOpponent():
		return ItemBook.getItemsInInventoryOfType_opponent(descr)
	else:
		return ItemBook.getItemsInInventoryOfType(descr)

func countAllInInventoryOfType(descr) -> int:
	if isOwnedByOpponent():
		return ItemBook.countItemsInInventoryOfType_opponent(descr)
	else:
		return ItemBook.countItemsInInventoryOfType(descr)

func countAllPlacedOfType(descr) -> int:
	if isOwnedByOpponent():
		return ItemBook.countItemsInInventoryOfType_opponent(descr)
	else:
		return ItemBook.countPlacedItemsInInventoryOfType(descr)

func isTypeInInventory(descr) -> bool:
	if isOwnedByOpponent():
		return ItemBook.isItemInInventory_opponent(descr)
	else:
		return ItemBook.isItemInInventory(descr)

func isRecipeFinished():
	return curRecipe.getProgress(bondedIngredients) == 1

func getNeighborItemsAndGems():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getNeighborItemsAndGems(self)

func getCraftableNeighbors():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getCraftableNeighbors(self)

func getBusyNeighbors():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").getBusyNeighbors(self)

func canCombine() -> bool:
	return placed

func canStartNewRecipe() -> bool:
	return not isBaseItem() and isAvailableForCrafting()

func isAvailableForCrafting() -> bool:
	return not isBoundAsIngredient() and not isLocked() and not fusing

func isBusy() -> bool:
	return curRecipe != null or isBoundAsIngredient()

func getRecipes(checkClassAvailability = true):
	var recipes = []
	for recipe in descriptor.recipes:

		recipes.push_back(recipe)
	return recipes

func isBaseItem():
	return not bondedIngredients.is_empty()

func breakBondVisual(toItem):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").breakBondVisual(self, toItem)

func removeBondedBaseItem():
	bondedBaseItem = null
	setBoundAsIngredient(false)

func removeBondedIngredient(item):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").removeBondedIngredient(self, item)

func removeAllIngredients():

	bondedIngredients.clear()
	for visual in bondVisuals:
		visual.breakBond()
	bondVisuals.clear()

	showProgressLabel()
	curRecipe = null

func considerAsBond(neighbor):
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").considerAsBond(self, neighbor)

func addBondedIngredient(forRecipe, neighbor):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").addBondedIngredient(self, forRecipe, neighbor)

func addToBaseItem(baseItem):
	bondedBaseItem = baseItem
	setBoundAsIngredient(true)
	playBondAnimation()

func playBondAnimation():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").playBondAnimation(self)

func playBondFailedAnimation():
	animation.advance(10)
	animation.play("BondFailed")

func isCatalystBond(bondedItem) -> bool:
	if curRecipe == null:
		return false

	return curRecipe.isNeighborCatalyst(bondedItem)

func isLocked() -> bool:
	return locked

func canLockBag():
	return false

func canBeLocked() -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canBeLocked(self)

func setLocked(_locked, showLabel = true):

	if locked == _locked: return

	if _locked:
		lockCombining(showLabel)
	else:
		unlockCombining()
	lockAnimation.advance(1)

func unlockCombining(playAni: bool = true):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").unlockCombining(self, playAni)

func lockCombining(showLabel = true):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").lockCombining(self, showLabel)

func showLockLabel():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").showLockLabel(self)

func getLockPosition() -> Vector2:
	return lock.global_position

func isBoundAsIngredient():
	return bound

func setBoundAsIngredient(_bound: bool):
	bound = _bound

func canPreviewFusions():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").canPreviewFusions(self)

func getGemsOfItems(items):
	var gems = []
	for item in items:
		gems.append_array(item.getGemsNoNull())
	return gems

func getCraftingPreviewPosition():
	return getGridStorageProxy().global_position

func previewFusions():
	return

func previewRecipeIngredients():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").previewRecipeIngredients(self)

func previewFusionToItem(hoveredIngredient):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").previewFusionToItem(self, hoveredIngredient)

func hasShopItemCraftCandidates() -> bool:
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").hasShopItemCraftCandidates(self)

func isBaseItemForShopItem(item) -> bool:
	for recipe in getRecipes(false):
		for ingredient in recipe.ingredients:
			if recipe.fitsIngredient(item, ingredient):
				return true
	return false

func typeInIngredients(candidate, ingredients):
	for ingredient in ingredients:
		if candidate.hasType(ingredient):
			return true
	return false

func getTextEffect() -> int:
	return descriptor.textEffect

func getFusionItemName() -> String:
	return curRecipe.fusedItem.getTranslatedName()

func showProgressLabel():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").showProgressLabel(self)

func onCraftingLabelReturned():
	craftingLabel = null

func createBondVisual(bondNeighbor):
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").createBondVisual(self, bondNeighbor)

func updateBondVisuals():
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").updateBondVisuals(self)

const PRE_FUSE_DUR = 1.0
const PRE_FUSE_DUR_COG = 0.2
const FUSE_DUR = 1.0
const TRANSFORMATION_DUR = 1.0
const fuseMaterial = preload("res://Shader/ItemFuseMaterial.tres")
var fuseParticlesScene1:
	get:
		return AssetStream.resolve("res://Shader/ItemsFusingParticles.tscn")
var fuseParticlesScene2:
	get:
		return AssetStream.resolve("res://Shader/ItemFuseParticles.tscn")
const fuseSound1 = preload("res://Assets/Sound/Boil.ogg")
const fuseSound2 = preload("res://Assets/Sound/Hammer2.ogg")
const fuseSound3 = preload("res://Assets/Sound/Craft.ogg")
const craftingReadySound = preload("res://Assets/Sound/Hammer4.mp3")

var fusing = false
var willBeConsumed = false
var fuseParticles1 = null
var fuseParticles2 = null
var fuseTween = null
var fusingBonds: Array

func fuse():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").fuse(self)

func onFusingAsIngredient():
	pass

func onFusingAsCatalystFinished():
	clearSpriteMaterial()
	setBoundAsIngredient(false)

func createCraftedShockwave(fusedItem):
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").createCraftedShockwave(self, fusedItem)

func finishFusing():
	return

func allowGeneratingFusionItem() -> bool:
	return true

func catalystFusingFinished():
	fusing = false
	bondedBaseItem = null
	updateShaderRotation()
	CraftingManager.itemAdded(self)

func onFusingFinished(validBonds):
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").onFusingFinished(self, validBonds)

func onCraftedFrom(baseItem, ingredients):
	pass

func getCraftingOffset(_forDirection):
	return Vector2.ZERO

func playCraftedAnimation(originPosition: Vector2):
	moveTo(originPosition, global_position, 0.2)
	animation.advance(10)
	animation.play("Crafted")

const labelOffsets = [Vector2.ZERO, Vector2(30, 30), Vector2( - 30, 30),
	Vector2(30, - 30), Vector2( - 30, - 30)]

func getNextFreeLabelPosition() -> Vector2:
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").getNextFreeLabelPosition(self)

func countTypes(ofItems: Array) -> Dictionary:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").countTypes(self, ofItems)

func insertCounter(text: String, keyword: String, amount: int) -> String:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").insertCounter(self, text, keyword, amount)

func onRestoreSnapshot():
	finishMoveback()
	animation.advance(10)
	animation.play("RestoreSnapshot")

func getShopPriority() -> int:
	return Priority.Normal

func findBondsWithAffectedItems():
	return load("res://Runtime/Behavior/Items/CraftingLifecycle.gd").findBondsWithAffectedItems(self)

class SignalConnection:
	var emitter
	var signalName
	var receiver
	var methodName

	func _init(_emitter, _signalName, _receiver, _methodName, binds = []):
		emitter = _emitter
		signalName = _signalName
		receiver = _receiver
		methodName = _methodName

		emitter.connect(signalName, Callable(receiver, methodName).bindv(binds))

	func destroy():
		Util.tryDisconnect(emitter, signalName, receiver, methodName)

# PvE instances retain all recovered sprites and drag animations.
func pve_is_view() -> bool:
	return has_meta("pve_definition_id") and Expedition.enabled and Expedition.bridge != null

func pve_definition() -> Dictionary:
	return Expedition.flow.placement.definition(str(get_meta("pve_definition_id", "")))

func pve_stat(key: String) -> float:
	return load("res://Runtime/Behavior/Features/Items/ItemBehavior.gd").pve_stat(self, key)

