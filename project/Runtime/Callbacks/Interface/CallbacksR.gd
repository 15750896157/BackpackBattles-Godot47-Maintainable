extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForRankingUI:
	const Receiver = preload("res://Interface/RankingUI.gd")

	static func _ready(subject: Receiver) -> void :
		subject.add_to_group("Localized")
		subject.updateLocale()

		Game.connect("continue_loaded", Callable(subject, "updateLocale"))
		Game.connect("runstate_loaded", Callable(subject, "updateLocale"))
		Game.connect("return_to_title", Callable(subject, "updateLocale"))
		Game.connect("returned_to_title", Callable(subject, "updateLocale"))
		Game.connect("character_changed", Callable(subject, "updateLocale"))
		Game.connect("runstate_suspended", Callable(subject, "updateLocale"))

	static func updateLocale(subject: Receiver):
		if Game.state == Game.State.Title:
			subject.visible = Game.isClassUnlocked()

		subject.leagueProgressUI.updateUI(Game.curClass)

		subject.switchModeIcon.visible = Game.isRankedSwitchMode()

class ForRankSeasonPopup:
	const Receiver = preload("res://Interface/RankSeasonPopup.gd")

	static func _ready(subject: Receiver):
		Game.pause(Game.PauseSource.PatchNotes)
		subject.animation.play("Open")
		subject.animation.advance(0.01)

		var bonusTrophies = 50

		for classNode in subject.get_node("Node2D/Classes").get_children():
			var classI = Game.getClassEnum()[classNode.name]

			var icon = classNode.get_node("ClassIcon")
			var rankLabel = classNode.get_node("Ranking")
			var emblem = classNode.get_node("LeagueEmblem")

			var rating = Game.getRunRating(classI, "1")
			var leagueExact = Game.getLeague_exact(rating)
			var league = int(leagueExact)

			bonusTrophies += league * 10

			classNode.setLeague(classI, leagueExact)

		subject.trophyLabel.formatParams = {"num":
			str("[b]", Util.highlight(bonusTrophies), "[/b]")}
		subject.trophyLabel.updateText()

		Game.giveTrophies(bonusTrophies)
		Game.saveGame()

class ForRerollRopeTag:
	const Receiver = preload("res://Interface/RerollRopeTag.gd")

	static func getColor(subject: Receiver, cost):
		var color
		if Game.getGold() < cost:
			color = Color(0.957031, 0.29989, 0.284119)
		else:
			if cost == 1:
				color = Color(1, 1, 1)
			elif cost == 2:
				color = Color(0.996094, 0.838942, 0.336571)
			else:
				color = Color(1, 0.639969, 0.291016)
		return color

class ForRopeSegment:
	const Receiver = preload("res://Interface/RopeSegment.gd")

	static func _ready(subject: Receiver):
		if not subject.ending:

			subject.start.position.y = - subject.LENGTH * 0.5
			subject.end.position.y = subject.LENGTH * 0.5

			subject.collisionShape.shape.size = Vector2(subject.WIDTH, subject.LENGTH - 4)
			subject.clickArea.size = Vector2(subject.WIDTH, subject.LENGTH)

		subject.call_deferred("ready_deferred")

	static func _integrate_forces(subject: Receiver, state: PhysicsDirectBodyState2D):
		if subject.dragged:
			var difToMouse = subject.rope.getClampedMousePos() - subject.global_position
			subject.linear_velocity = difToMouse * 5.0

		elif subject.resetPending:

			subject.constant_force = Vector2.ZERO
			subject.constant_torque = 0
			state.linear_velocity = Vector2.ZERO
			state.angular_velocity = 0
			state.transform = subject.startTransform
			subject.resetPending = false

class ForRotateHint:
	const Receiver = preload("res://Interface/RotateHint.gd")

	static func updateLocale(subject: Receiver):
		if Game.usingController:
			var text = subject.tr("HINT_Rotate_CONTROLLER")
			var icon1 = ControllerIcons.getIconFromAction("rotate_left_button_controller")
			var icon2 = ControllerIcons.getIconFromAction("rotate_right_button_controller")
			text = text.format({
				"button1": Util.imageToBbcode(icon1, 60),
				"button2": Util.imageToBbcode(icon2, 60)})
			subject.get_node("Hint").text = "[center]" + text
		else:
			subject.get_node("Hint").text = "[center]" + subject.tr("HINT_Rotate")
