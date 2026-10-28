extends ToolTip

const dividerScene = preload("res://Interface/Tooltips/RecipeTooltipDivider.tscn")
const recipeScene = preload("res://Interface/Tooltips/BuildIntoRecipe.tscn")
const relatedItemsScene = preload("res://Interface/Tooltips/RelatedItems.tscn")
const lockSound = preload("res://Assets/Sound/Lock.wav")
const ninePatchMargin = 110

var entries = []
var growToRight = true
var maxWidth = 420

@onready var recipesHeader = $VBoxContainer/Header
@onready var lockHint = $LockHint
@onready var lockIcon = $LockHint/Lock
@onready var animation = $LockHint/AnimationPlayer

func _ready():
	super._ready()

	if Game.usingController:
		lockHint.formatParams = {"button": Util.getControllerIconBbcode("show_hints_controller")}
	else:
		lockHint.formatParams = {"button": (Util.getTextForEvent(InputMap.action_get_events("show_hints")[0], true))}

	lockHint.updateText()

func setItem(item, asSubTooltip: bool):
	return load("res://Runtime/Behavior/Interface/Tooltips/BuildIntoRecipesTooltipBehavior.gd").setItem(self, item, asSubTooltip)

func onTooltipLocked():
	return load("res://Runtime/Behavior/Interface/Tooltips/BuildIntoRecipesTooltipBehavior.gd").onTooltipLocked(self)

func discard():
	for entry in entries:
		entry.discard()
	queue_free()
