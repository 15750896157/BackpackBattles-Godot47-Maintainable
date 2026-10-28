extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/ItemBoundChecker.gd")

static func cleanUp(subject: Receiver):
	var exitTimes_new = {}
	for body in subject.exitTimes:
		if is_instance_valid(body) and body.ownerType == Item.Owner.PlayerStorageBox:
			exitTimes_new[body] = subject.exitTimes[body]
			if not body.dragged:
				var ticksSinceExit = subject.ticks - subject.exitTimes[body]

				if subject.exitTimes.size() > 3:
					if ticksSinceExit >= 5:
						body.global_position = Vector2(1000, - 500)
						body.rotation = 0
						print("resetting (full)", body.getName())

				else:
					if ticksSinceExit >= 2:
						body.global_position = Vector2(1000, - 200)
						body.linear_velocity.y = Util.rng.randf_range(300, 600)
						body.lastCollisionPos = body.global_position
						print("resetting ", body.getName())

	subject.exitTimes = exitTimes_new
	subject.updateIndicator()

static func onBodyExited(subject: Receiver, body):
	if Game.isShopActive():
		if body is Item and body.ownerType == Item.Owner.PlayerStorageBox:

			if not body.dragged:
				subject.exitTimes[body] = subject.ticks

				subject.indicatorTimer.start(5.0)

				body.connect("added_to_inventory", Callable(subject, "onItemAddedToInventory").bind(body))
				body.connect("picked_up", Callable(subject, "onItemPickedUp").bind(body))

static func onIndicatorPressed(subject: Receiver):
	Game.cancelSwitch()
	var item
	for offScreenItem in subject.exitTimes.keys():
		if (is_instance_valid(offScreenItem) and
			offScreenItem.ownerType == Item.Owner.PlayerStorageBox):
				item = offScreenItem
				break

	item.global_position = subject.get_global_mouse_position()
	item.pickup()
	subject.updateIndicator()
