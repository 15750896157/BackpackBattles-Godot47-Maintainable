extends ToolTip

const recipePlus = preload("res://Interface/Tooltips/RecipePlus.tscn")
const ingredientScene = preload("res://Interface/Tooltips/Ingredient.tscn")
const X_BORDER = 110
const ingredientsPerRow = 3

@onready var hboxContainer = $VBoxContainer/HBoxContainer
@onready var hboxContainer2 = $VBoxContainer/HBoxContainer2
@onready var hboxContainer3 = $VBoxContainer/HBoxContainer3
@onready var divider = $VBoxContainer/Divider
@onready var divider2 = $VBoxContainer/Divider2

var itemTooltip
var itemTopLeft
var itemSize
var ingredientControls = []

func setItem(item):
	return load("res://Runtime/Behavior/Interface/Tooltips/RecipeTooltipBehavior.gd").setItem(self, item)

func createItemTooltip(item):
	return load("res://Runtime/Behavior/Interface/Tooltips/RecipeTooltipBehavior.gd").createItemTooltip(self, item)

func updateSize():
	return load("res://Runtime/Behavior/Interface/Tooltips/RecipeTooltipBehavior.gd").updateSize(self)

func forceUpdatePosition(toolPos: Vector2, toolSize: Vector2, alignment = Alignment.Center):
	itemSize = toolSize
	itemTopLeft = toolPos
	super.forceUpdatePosition(toolPos, toolSize, alignment)

func _process(delta):
	if itemTooltip != null:
		modulate = itemTooltip.modulate

func discard():

	if itemTooltip != null:
		itemTooltip.discard()

	for ingredient in ingredientControls:
		ingredient.discard()

	super.discard()

func isDiscarded() -> bool:
	return is_queued_for_deletion()
