extends RefCounted
class_name ItemDescriptor

enum StuffedClasses{
	Undefined = - 1,
	None = 0,
	Ranger = 1,
	Reaper = 2,
	Berserker = 4,
	Pyromancer = 8,
	Mage = 16,
	Adventurer = 32,
	Engineer = 64,
	Neutral = 127,
}

enum ReleaseState{
	Demo = 0,
	Full = 1,
	Unreleased = 2,
}

const PARAM_DELIMITER = "_"

var rarity = Item.Rarity.Common
var types: Array

var classes: int

var randomUniquePool = false
var material = Item.Mat.Default
var physics = Item.Physics.Default
var identifier: String
var minDam: int = 0
var maxDam: int = 0
var cd: float = 0.0
var extraCds: Array
var accuracy: float = 0.0
var chance: float = 0.0
var chance2: float = 0.0
var shopChance: float = 0.0
var tags = Item.Tag.None
var gainedStacks = Item.Stack.None
var removedStacks = Item.Stack.None
var usedStacks = Item.Stack.None
var params: Array
var namedParams: Dictionary
var sortedParamNames: Array
var paramBases: Dictionary
var paramBases_inverted: Dictionary
var descriptionKey: String
var searchDescription: String
var scene_path: String = ""
var animation_path: String = ""
var _scene: PackedScene
var _animation_scene: PackedScene
var scene: PackedScene:
	get:
		if _scene == null and not scene_path.is_empty(): _scene = AssetStream.resolve(scene_path)
		return _scene
	set(value):
		_scene = value
var animationScene:
	get:
		if _animation_scene == null and not animation_path.is_empty(): _animation_scene = AssetStream.resolve(animation_path)
		return _animation_scene
	set(value):
		_animation_scene = value

func peek_scene():
	return _scene

func has_scene() -> bool:
	return not scene_path.is_empty() or _scene != null

func release_resources():
	_scene = null
	_animation_scene = null

var price: int
var staminaCost: float = 0.0
var block: int = 0
var recipes = []
var recipesAsIngredient = []

var originatingRecipes = []
var baseIngredients: Counter
var recipeTree: Counter
var shopItem = false
var gateItem = null
var gatedItems = []
var requiredItem = null
var canActivate = true
var threshold: int = 100
var weight: float = 1.0
var startsSubclass = ""
var itemIndex: int
var sheetIndex: int
var appropriatingItems = []
var mentionedStacks: Dictionary
var mentionedTypes: Dictionary
var hasBattleRageEffect: bool
var earliestRound: int = 4
var latestRound: int = 18
var appearRounds = []
var version: int
var releaseState: int
var activationAni: int = Item.ActivationAni.Jump
var textEffect: int

static func stuffClassIndex(classI):
	return 1 << classI

func instantiate():
	var item = scene.instantiate()
	item.descriptor = self
	return item

func instantiate_pooled():
	var item = ObjectPool.instantiate(scene)
	item.descriptor = self
	item.pooled = true
	return item

func addNamedParam(paramName: String, paramVal):
	return load("res://Runtime/Behavior/Items/ItemDescriptorBehavior.gd").addNamedParam(self, paramName, paramVal)

func getIndex() -> int:
	return itemIndex

func getName() -> String:
	return identifier

func getTranslatedName() -> String:
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").getTranslatedName(self)

func getRarity() -> int:
	return rarity

static func getTypeName(type) -> String:
	return Item.Type.keys()[type]

func getTranslatedTypeName(type) -> String:
	return Util.tra("TYPE_" + Item.Type.keys()[type] + "_NAME")

func getTranslatedTypes() -> Array:
	var tTypes = []
	for type in types:
		tTypes.push_back(getTranslatedTypeName(type))
	return tTypes

func getP(index) -> float:
	if typeof(index) == TYPE_INT:
		return params[index]
	else:
		return namedParams[index]

func hasParam(paramName: String) -> bool:
	return paramName in paramBases_inverted

func getShopChance() -> float:
	return shopChance

func getDescription() -> String:
	return Util.tra(descriptionKey + "_DESCR")

func isAvailableFor(classId: int) -> bool:
	return isAvailableForStuffed(stuffClassIndex(classId))

func isAvailableForStuffed(classId: int) -> bool:
	return bool(classes & classId)

func isNeutral() -> bool:
	return classes == StuffedClasses.Neutral

func isClassItem() -> bool:
	return (classes != StuffedClasses.Neutral and
		classes != StuffedClasses.None)

func calcClassAvailability():
	return load("res://Runtime/Behavior/Items/ItemDescriptorBehavior.gd").calcClassAvailability(self)

func addAppropriatingItem(item):
	if classes == StuffedClasses.Neutral: return

	appropriatingItems.push_back(item)

func calcAppropriation():
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").calcAppropriation(self)

func getCraftingDepth() -> int:
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").getCraftingDepth(self)

func getPrice():
	return price

func getSellPrice():
	return ceil(getPrice() * 0.5)

func getSalePrice():
	return ceil(getPrice() * 0.5)

func canCraft(classId) -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").canCraft(self, classId)

func isCraftedItem() -> bool:
	return not originatingRecipes.is_empty()

func isGatedItem() -> bool:
	return gateItem != null

func isTreasure() -> bool:
	return randomUniquePool

func canOnlyExistOnce() -> bool:
	return tags & Item.Tag.Singular

func isTransient() -> bool:
	return tags & Item.Tag.Transient

func getWeight() -> float:
	return weight

func getThreshold() -> int:
	return threshold

func getThresholdWeight(itemCounter: Dictionary) -> float:
	return load("res://Runtime/Behavior/Items/ItemDescriptorBehavior.gd").getThresholdWeight(self, itemCounter)

func isShopItem() -> bool:
	return shopItem or ( not isCraftedItem() and not isGatedItem())

func hasType(type) -> bool:
	return type in types

func getTypes() -> Array:
	return types

func hasTag(tag) -> bool:
	return tag & tags

func isBag() -> bool:
	return Item.Type.Bag in types

func isWeapon() -> bool:
	return Item.Type.Weapon in types

func isMeleeWeapon() -> bool:
	return Item.Type.Melee in types and isWeapon()

func isRangedWeapon() -> bool:
	return Item.Type.Ranged in types and isWeapon()

func isStartingWeapon() -> bool:
	return isWeapon() and not identifier == "Stone"

func isGem() -> bool:
	return Item.Type.Gem in types

func isSubclassItem() -> bool:
	return startsSubclass != ""

func getFlavorTextSimple() -> String:
	return tr(str(descriptionKey, "_FLAVOR"))

func getFlavorText() -> String:
	return load("res://Runtime/Behavior/Items/ItemDescriptorBehavior.gd").getFlavorText(self)

func getNumRecipes() -> int:
	return recipes.size() + recipesAsIngredient.size()

func isReleased() -> bool:
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").isReleased(self)

func getClassesAsArray() -> Array:
	return load("res://Runtime/Behavior/Features/Items/ItemDescriptorBehavior.gd").getClassesAsArray(self)

