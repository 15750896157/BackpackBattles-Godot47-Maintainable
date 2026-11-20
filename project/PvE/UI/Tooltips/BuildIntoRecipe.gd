extends "res://PvE/UI/Tooltips/TooltipItemLayout.gd"

const ingredientLabelScene = preload("res://PvE/UI/ItemLibrary/IngredientLabel.tscn")
const catalystHatchingScene = preload("res://PvE/UI/ItemLibrary/CatalystHatching.tscn")
const ownedIconScene = preload("res://PvE/UI/Tooltips/OwnedIcon.tscn")
const shopIconScene = preload("res://PvE/UI/Tooltips/ShopIcon.tscn")

const ownedIconScale = Vector2(0.5, 0.5)
const shopIconScale = Vector2(0.3, 0.3)

@onready var equals = $Equals
@onready var animation = $AnimationPlayer

var pooled = []
var maxWidth: int
var ownedCounter: Dictionary
var shopCounter: Dictionary

func setRecipe(recipe, tooltip):
	return load("res://Code/Runtime/Behavior/Interface/Tooltips/BuildIntoRecipeBehavior.gd").setRecipe(self, recipe, tooltip)

func center(totalWidth):
	return load("res://Code/Runtime/Behavior/Interface/Tooltips/BuildIntoRecipeBehavior.gd").center(self, totalWidth)

func discard():
	super.discard()
	for node in pooled:
		ObjectPool.returnInstance(node)
