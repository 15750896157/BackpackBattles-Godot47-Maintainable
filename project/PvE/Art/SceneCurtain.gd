extends "res://Code/Runtime/Scene/TransitionContext.gd"
## Native compatibility adapter. Domain/singleton access stays out of the layer.

func is_stopping() -> bool:
	return not is_instance_valid(AssetStream) or AssetStream.stopping

func appearance() -> Dictionary:
	return Expedition.preferences.values if Expedition.preferences != null else {}

func fade_targets() -> Array:
	var result: Array = []
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if not is_instance_valid(actor): continue
		for portrait in actor.find_children("Body", "Sprite2D", true, false): result.append(portrait)
		if actor.INVENTORY != null:
			for item in actor.INVENTORY.getItems():
				if is_instance_valid(item): result.append(item)
	if Game.state == Game.State.Shop:
		for slot in Game.shopSceneNode.slots:
			if is_instance_valid(slot.item): result.append(slot.item)
	return result

func before_cover() -> void:
	if is_instance_valid(Expedition.transitions.closing_ghost):
		Expedition.transitions.closing_ghost.queue_free()
		Expedition.transitions.closing_ghost = null

func acquire_input() -> void:
	InputBlocker.activate(InputBlocker.Source.Cinematic, false)

func release_input() -> void:
	if is_instance_valid(InputBlocker): InputBlocker.deactivate(InputBlocker.Source.Cinematic, false)

func begin_loading(reason: String, current: Callable) -> int:
	return await Expedition.loading_screen.begin_scene(reason, current)

func finish_loading(ticket: int) -> void:
	await Expedition.loading_screen.finish(ticket)

func cancel_loading(ticket: int) -> void:
	if is_instance_valid(Expedition) and is_instance_valid(Expedition.loading_screen):
		Expedition.loading_screen.cancel(ticket)
