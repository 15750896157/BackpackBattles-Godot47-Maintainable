extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/UndoStack.gd")

static func ready_deferred(subject: Receiver):
	while not is_instance_valid(Game.PLAYER) or Game.PLAYER.INVENTORY == null:
		await subject.get_tree().process_frame
	Game.connect("item_dropped", Callable(subject, "onItemDropped"))
	Game.connect("item_crafted", Callable(subject, "onItemCrafted"))
	Game.PLAYER.INVENTORY.connect("inventory_shifted", Callable(subject, "onInventoryShifted"))
	Game.STORAGEBOX.connect("pushed_all_to_storage", Callable(subject, "onPushedAllToStorage"))
	Game.connect("shop_opened", Callable(subject, "onShopOpened"))
	Game.connect("run_over", Callable(subject, "clear"))
	Game.connect("fresh_run_started", Callable(subject, "clear"))

static func _unhandled_input(subject: Receiver, event):
	if InputBlocker.isActive() or not Game.isShopActive() or Game.draggedItem != null: return
	if Util.isActionPressed_event(event, "undo"):
		subject.undo()
		subject.get_viewport().set_input_as_handled()
	elif Util.isActionPressed_event(event, "redo"):
		subject.redo()
		subject.get_viewport().set_input_as_handled()
	return

static func showLabel(subject: Receiver, undo: bool):
	subject.label.text = str(subject.curStateIndex + 1) + "/" + str(subject.states.size())
	Util.killTween(subject.tween)
	subject.tween = subject.create_tween().set_parallel()
	subject.tween.tween_property(subject.label, "modulate:a", 1.0, 0.2)
	subject.tween.tween_property(subject.label, "modulate:a", 0.0, 0.2).set_delay(1.2).from(1.0)
	var showArrow
	var hideArrow
	if undo:
		showArrow = subject.leftArrow
		hideArrow = subject.rightArrow
	else:
		showArrow = subject.rightArrow
		hideArrow = subject.leftArrow
	subject.tween.tween_property(showArrow, "modulate:a", 1.0, 0.2)
	subject.tween.tween_property(showArrow, "modulate:a", 0.0, 0.2).set_delay(1.2).from(1.0)
	subject.tween.tween_property(hideArrow, "modulate:a", 0.0, 0.1)
	subject.animation.play("RestoreSnapshot")

static func showLabelManual(subject: Receiver, slot, restore: bool):
	var t
	if restore:
		t = Util.tra("UI_LoadSnapshot")
	else:
		t = Util.tra("UI_SaveSnapshot")

	subject.label.text = t.format({"slot": slot})
	Util.finishTween(subject.tween)
	subject.tween = subject.create_tween()
	subject.tween.tween_property(subject.label, "modulate:a", 1.0, 0.2)
	subject.tween.tween_property(subject.label, "modulate:a", 0.0, 0.2).set_delay(1).from(1.0)
	subject.animation.play("RestoreSnapshot")
