extends Resource
class_name CharacterClass

@export var health: int = 30
@export var stamina: int = 5
@export var gold: int = 10
@export var startingItems: Array[Resource] = []
@export var startingItems2: Array[Resource] = []
@export var startingItems3: Array[Resource] = []
@export var notUnlockedSprite: PackedScene
@export var color: Color

var sprite_path: String
var chibi_path: String
var _sprite: PackedScene
var _chibi_sprite: PackedScene
var sprite:
	get:
		if _sprite == null: _sprite = AssetStream.resolve(sprite_path)
		return _sprite
var chibiSprite:
	get:
		if _chibi_sprite == null: _chibi_sprite = AssetStream.resolve(chibi_path)
		return _chibi_sprite

func release_resources():
	_sprite = null
	_chibi_sprite = null

var runStartSounds = []
var buySounds = []
var roundStartSounds = []
var winRoundSounds = []
var loseRoundSounds = []
var clickedSounds = []
var attackSounds = []
var damagedSounds = []
var battleRageSound = null

const spriteFormat = "res://CharacterClasses/{class}/{class}Sprite.tscn"
const chibiSpriteFormat = "res://CharacterClasses/{class}/{class}ChibiSprite.tscn"

func loadFiles(classIdentifier: String):
	return load("res://Runtime/Behavior/CharacterClasses/CharacterClassBehavior.gd").loadFiles(self, classIdentifier)

func loadSounds(classIdentifier: String):
	return load("res://Runtime/Behavior/CharacterClasses/CharacterClassBehavior.gd").loadSounds(self, classIdentifier)

func getRunStartSound():
	if runStartSounds.is_empty(): return null
	return Util.pickRandomElement(runStartSounds)

func getBuySound():
	if buySounds.is_empty(): return null
	return Util.pickRandomElement(buySounds)

func getRoundStartSound():
	if roundStartSounds.is_empty(): return null
	return Util.pickRandomElement(roundStartSounds)

func getWinRoundSound():
	if winRoundSounds.is_empty(): return null
	return Util.pickRandomElement(winRoundSounds)

func getLoseRoundSound():
	if loseRoundSounds.is_empty(): return null
	return Util.pickRandomElement(loseRoundSounds)

func getClickedSound():
	if clickedSounds.is_empty(): return null
	return Util.pickRandomElement(clickedSounds)

func getAttackSound():
	if attackSounds.is_empty(): return null
	return Util.pickRandomElement(attackSounds)

func getDamagedSound():
	if damagedSounds.is_empty(): return null
	return Util.pickRandomElement(damagedSounds)

func getStartingItems(loadout):
	if loadout == Game.Loadout.Loadout1:
		return startingItems
	elif loadout == Game.Loadout.Loadout2:
		return startingItems2
	else:
		return startingItems3

func getStartingBag(loadout) -> ItemDescriptor:
	var items = getStartingItems(loadout)
	return ItemBook.getDescriptor(items[0].itemName)
