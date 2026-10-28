extends Node2D

signal returned_to_pool

var poolingHandle
var animation
var label

func preset():
	animation = $AnimationPlayer
	label = $Label

	Util.localizeFonts(label)

func showProgress(itemName: String, num: int, outOf: int,
	ingredientCounter: Array) -> void :
	load("res://Runtime/Behavior/Features/Interface/Inventory/CraftingProgressLabelBehavior.gd").showProgress(self, itemName, num, outOf, ingredientCounter)

func updateProgress(itemName: String, num: int, outOf: int,
	ingredientCounter: Array) -> void :

	updateLabel(itemName, num, outOf, ingredientCounter)
	animation.play("Change")

const green = Color(0.535913, 0.982422, 0.443241)
const yellow = Color(1, 0.890196, 0)
const labelFormat = "[center][color=#{col}]{name}\n{num}/{outOf}[/color]{bonded}{missing}"
const bondedFormat = "\n[color=#{col}]{icon} {name} {num}/{outOf}"

const missingMark = preload("res://Interface/HookArrow.png")

func updateLabel(itemName: String, num: int, outOf: int,
	ingredientCounter: Array):
	return load("res://Runtime/Behavior/Features/Interface/Inventory/CraftingProgressLabelBehavior.gd").updateLabel(self, itemName, num, outOf, ingredientCounter)

func fade():
	return load("res://Runtime/Behavior/Features/Interface/Inventory/CraftingProgressLabelBehavior.gd").fade(self)

func returnToObjectPool():
	emit_signal("returned_to_pool")
	ObjectPool.returnInstance(self)
