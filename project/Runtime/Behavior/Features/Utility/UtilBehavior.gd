extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Util.gd")

static func _physics_process(subject: Receiver, delta):

	if not subject.get_tree().paused:
		subject.frameCounter += 1
		subject.time += delta

	var curMousePos = subject.getMousePosInWindow()
	subject.mouseVelocity = (curMousePos - subject.lastMousePos)
	subject.lastMousePos = curMousePos

static func debugOnly(subject: Receiver, val):

	if subject.debugOnlyCounter > 3:
		print("DEBUG ONLY - ", val)

	subject.debugOnlyCounter += 1

	if not OS.has_feature("editor") or ProjectSettings.get_setting("application/config/recovered_project"):
		return false

	return val

static func tra(subject: Receiver, key: String) -> String:
	var position = subject.translationCache.get(key, null)

	if position == null:
		position = subject.tr(key)
		if position == key:
			position = ""
		subject.translationCache[key] = position

	return position

static func updateLocaleInSubtree(subject: Receiver, node):
	if node.is_in_group("Localized"):
		subject.localizeFonts(node)
		node.updateLocale()

	for child in node.get_children():
		subject.updateLocaleInSubtree(child)

static func writeVarToFile(subject: Receiver, filePath, content):
	var tempPath = filePath + ".tmp"
	var err = subject.writeVarToFile_simple(tempPath, content)
	if err == OK:
		var dir = LegacyDirectory.new()
		err = dir.rename(tempPath, filePath)
		assert (err == OK)
	return err

static func writeVarToFile_simple(subject: Receiver, filePath, content):
	var err = subject.file.open(filePath, File.WRITE)
	if err == OK:
		subject.file.store_var(content)
		subject.file.close()
	else:
		assert (false)
	return err

static func wrapInColor_fixed(subject: Receiver, text: String, color: Color) -> String:
	return subject.smartColorFormat.format({
			"col": color.to_html(false),
			"length": text.length(),
			"text": text
		})

static func findFirstOf(subject: Receiver, string: String, stringsToFind: Array, startIndex: int):
	var firstIndex = INF
	for stringToFind in stringsToFind:
		var index2 = string.find(stringToFind, startIndex)
		if index2 != - 1:
			firstIndex = min(firstIndex, index2)

	if firstIndex == INF:
		firstIndex = - 1

	return firstIndex

static func isLatinLetterOrNumber(subject: Receiver, character: String):
	var ascii = ord(character)
	return ((ascii >= 65 and ascii <= 122) or
			(ascii >= 48 and ascii <= 57))

static func findWholeWord(subject: Receiver, text, searchTerm):
	var from = 0
	var length = searchTerm.length()
	while true:
		var startPos = text.findn(searchTerm, from)
		if startPos == - 1:
			return - 1
		if subject.isLatinLetterOrNumber(text[startPos + length]):

			from = startPos + 1
		else:
			return startPos

static func tryConnect(subject: Receiver, emitter, signalName, listener, methodname, binds, flags):
	for connection in emitter.get_signal_connection_list(signalName):
		var callback: Callable = connection.callable
		if callback.get_object() == listener and callback.get_method() == methodname:
			return
	emitter.connect(signalName, Callable(listener, methodname).bindv(binds), flags)

static func tryDisconnect(subject: Receiver, emitter, signalName, listener, methodname):
	for connection in emitter.get_signal_connection_list(signalName):
		var callback: Callable = connection.callable
		if callback.get_object() == listener and callback.get_method() == methodname:
			emitter.disconnect(signalName, callback)

static func setDelayed(subject: Receiver, target, propertyName, value, delay):
	var timer = subject.get_tree().create_timer(delay, false)
	timer.connect("timeout", Callable(target, "set").bind(propertyName, value), subject.CONNECT_ONE_SHOT)

static func setDelayed_process(subject: Receiver, target, propertyName, delay, value):
	var timer = subject.get_tree().create_timer(delay, true)
	timer.connect("timeout", Callable(target, "set").bind(propertyName, value), subject.CONNECT_ONE_SHOT)

static func callDelayed(subject: Receiver, target, methodName, delay, binds):
	var timer = subject.get_tree().create_timer(delay, false)
	timer.connect("timeout", Callable(target, methodName).bindv(binds), subject.CONNECT_ONE_SHOT)

static func callDelayed_process(subject: Receiver, target, methodName, delay, binds):
	var timer = subject.get_tree().create_timer(delay, true)
	timer.connect("timeout", Callable(target, methodName).bindv(binds), subject.CONNECT_ONE_SHOT)

static func finishTimer(subject: Receiver, timer: Timer):
	if not timer.is_stopped():
		timer.stop()
		for c in timer.get_signal_connection_list("timeout"):
			c.callable.call()

static func tweenMethodCurve(subject: Receiver, tween: Tween, node: Node, methodName: String, fromVal, toVal, duration: float, curve: Curve):

	tween.tween_method(Callable(subject, "lerpPosCurve").bind(node, methodName, fromVal, toVal, curve), 0.0, 1.0, duration)

static func isChristmas(subject: Receiver) -> bool:
	var date = Time.get_date_dict_from_system()
	return (date.month == 12 or (date.month == 1 and date.day < 7))

static func reparentNode(subject: Receiver, node, newParent):
	var pos = node.global_position
	var rot = node.global_rotation
	node.get_parent().remove_child(node)
	newParent.add_child(node)
	node.global_position = pos
	node.global_rotation = rot

static func getGlobalZ(subject: Receiver, target: Node2D) -> int:
	var node = target
	var z_index = 0
	while node and node is Node2D:
		z_index += node.z_index
		if not node.z_as_relative:
			break
		node = node.get_parent()
	return z_index

static func spawnNumberLabel(subject: Receiver, type: int, globalPosition: Vector2, direction: Vector2, amount: int):

	var numberLabel = ObjectPool.instantiate(subject.NUMBERLABEL_SCENE)
	numberLabel.position = globalPosition

	Game.UINode.add_child(numberLabel)
	numberLabel.linear_velocity = direction
	numberLabel.spawnNumber(type, amount)

static func spawnBuffLabel(subject: Receiver, type: int, globalPosition: Vector2, amount):
	var buffLabel = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	buffLabel.position = globalPosition
	Game.UINode.add_child(buffLabel)
	buffLabel.linear_velocity = subject.randBuffLabelDir()
	buffLabel.spawnLabel(type, amount)

static func spawnMissLabel(subject: Receiver, globalPosition: Vector2, direction: Vector2):
	var buffLabel = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	buffLabel.position = globalPosition
	Game.UINode.add_child(buffLabel)
	buffLabel.linear_velocity = direction
	buffLabel.spawnLabel(Game.EventType.MissedAttack)

static func spawnResistedLabel(subject: Receiver, type: int, globalPosition: Vector2, amount):
	if not Settings.getVal(Settings.Setting.buff_labels): return

	var label = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	label.position = globalPosition
	Game.UINode.add_child(label)
	label.linear_velocity = subject.randBuffLabelDir()
	label.spawnLabel(type, amount, label.ChangeType.Resisted)

static func spawnProtectedLabel(subject: Receiver, type: int, globalPosition: Vector2, amount):
	if not Settings.getVal(Settings.Setting.buff_labels): return

	var label = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	label.position = globalPosition
	Game.UINode.add_child(label)
	label.linear_velocity = subject.randBuffLabelDir()
	label.spawnLabel(type, amount, label.ChangeType.Protected)

static func spawnReflectLabel(subject: Receiver, type: int, globalPosition: Vector2, amount):
	if not Settings.getVal(Settings.Setting.buff_labels): return

	var label = ObjectPool.instantiate(subject.BUFFLABEL_SCENE)
	label.position = globalPosition
	Game.UINode.add_child(label)
	label.linear_velocity = subject.randBuffLabelDir()
	label.spawnLabel(type, amount, label.ChangeType.Reflected)

static func flipWeighted(subject: Receiver, weights: Array) -> int:
	var sum = 0.0
	for weight in weights:
		sum += weight

	var val = subject.rng.randf_range(0, sum)
	var subsum = 0.0
	for i in weights.size():
		subsum += weights[i]
		if subsum >= val:
			return i

	return weights.size()

static func disconnectAll(subject: Receiver, object):
	for connection in object.get_incoming_connections():
		var incoming: Signal = connection.signal
		if incoming.get_name() not in ["tree_entered", "tree_exiting"]:
			incoming.disconnect(connection.callable)

static func disconnectSignal(subject: Receiver, object, signalName: String):
	for connection in object.get_incoming_connections():
		var incoming: Signal = connection.signal
		if incoming.get_name() == signalName:
			incoming.disconnect(connection.callable)

static func clampToRect(subject: Receiver, pos: Vector2, rect: Rect2) -> Vector2:
	pos.x = clamp(pos.x, rect.position.x, rect.end.x)
	pos.y = clamp(pos.y, rect.position.y, rect.end.y)
	return pos

static func getIcon(subject: Receiver, keyword, size):
	if not subject.icons.has(keyword): return null

	if size:
		return subject.imgFormat.format([size, subject.icons[keyword]])
	else:
		return subject.imgFormat.format([subject.iconSizes.get(keyword, 28), subject.icons[keyword]])

static func makeSimplifiedChinese(subject: Receiver, font: LegacyFont):

	if (font.font_data == subject.baskervilleRegular or
		font.font_data == subject.baskervilleBold):
		font.font_data = subject.chineseFont1
		font.spacing_top -= 6
	else:
		font.font_data = subject.chineseFont2
		font.spacing_bottom -= 6

static func makeTraditionalChinese(subject: Receiver, font: LegacyFont):
	if (font.font_data == subject.baskervilleRegular or
		font.font_data == subject.baskervilleBold):
		font.font_data = subject.traditionalChineseFont1
		font.spacing_top -= 6
	else:
		font.font_data = subject.chineseFont2
		font.spacing_bottom -= 6

static func makeJapanese(subject: Receiver, font: LegacyFont):
	if (font.font_data == subject.baskervilleRegular or
		font.font_data == subject.baskervilleBold):
		font.font_data = subject.japaneseFont1
		font.spacing_top -= 5
		font.spacing_bottom -= 3
	else:
		font.font_data = subject.japaneseFont2

		font.size -= 2

static func makeKorean(subject: Receiver, font: LegacyFont):
	if (font.font_data == subject.baskervilleRegular or
		font.font_data == subject.baskervilleBold):
		font.font_data = subject.koreanFont1
		font.spacing_top -= 5
		font.spacing_bottom -= 3
	else:
		font.font_data = subject.koreanFont1
		font.spacing_top -= 5
		font.size -= 2

static func makeRussian(subject: Receiver, font: LegacyFont):
	if (font.font_data == subject.baskervilleRegular or
		font.font_data == subject.baskervilleBold):
		font.font_data = subject.russianFont1
		font.spacing_top -= 6
		font.spacing_bottom -= 3
	else:
		font.font_data = subject.russianFont2
		font.spacing_top -= 6
		font.size -= 2

static func getNormalFont(subject: Receiver, node):
	if subject.isControlWithSingleFont(node):
		return node.get("theme_override_fonts/font")
	elif node is RichTextLabel:
		return node.get("theme_override_fonts/normal_font")

static func setNormalFont(subject: Receiver, node, font: LegacyFont):
	if subject.isControlWithSingleFont(node):
		node.set("theme_override_fonts/font", font)
	elif node is RichTextLabel:
		node.set("theme_override_fonts/normal_font", font)

static func addFallbackFonts(subject: Receiver, font: LegacyFont):
	if not OS.has_feature("web"):
		font.add_fallback(subject.chineseFallbackFont)
		font.add_fallback(subject.japaneseFallbackFont)
		font.add_fallback(subject.koreanFallbackFont)
		font.add_fallback(subject.russianFallbackFont)

static func createPulse(subject: Receiver, pulseScene, item, pos):
	var pulse = ObjectPool.instantiate(pulseScene)
	item.get_parent().add_child(pulse)
	pulse.z_index = item.z_index
	pulse.global_position = pos
	pulse.get_node("AnimationPlayer").play("Activate")

static func getNodesForAllClasses(subject: Receiver, parent, pathFormat):
	var nodes = []
	nodes.resize(Game.Classes_Full.size())
	for className in Game.Classes_Full:
		nodes[Game.Classes_Full[className]] = parent.get_node(pathFormat.format({"class": className}))
	return nodes

static func showScreenKeyboard(subject: Receiver, lineEdit: LineEdit):
	if SteamHelper.STEAMDECK:
		lineEdit.caret_column = lineEdit.text.length()

		var res = Steam.showFloatingGamepadTextInput(0,
			0, 500, 1000, 100)

static func isActionPressed(subject: Receiver, actionName: String, checkController: bool) -> bool:
	if InputBlocker.isActive(): return false
	if Input.is_action_pressed(actionName): return true
	if checkController and Input.is_action_pressed(actionName + "_controller"): return true
	return false

static func isActionJustPressed(subject: Receiver, actionName: String, checkController: bool) -> bool:
	if InputBlocker.isActive(): return false
	if Input.is_action_just_pressed(actionName): return true
	if checkController and Input.is_action_just_pressed(actionName + "_controller"): return true
	return false

static func isClickEvent(subject: Receiver, event: InputEvent) -> bool:
	return ((event.is_action_pressed("ui_accept") or
		subject.isActionPressed_event(event, "grab_item") or
		(event is InputEventScreenTouch and event.pressed)))

static func isClickReleaseEvent(subject: Receiver, event: InputEvent) -> bool:
	return ((event.is_action_released("ui_accept") or
		subject.isActionReleased_event(event, "grab_item") or
		(event is InputEventScreenTouch and not event.pressed)))

static func showPopupMessage(subject: Receiver, translationKey, formatParams, duration):
	var popup = ObjectPool.instantiate(subject.popupMessageScene)
	Game.tooltipsNode.add_child(popup)
	popup.duration = duration
	popup.setParams(formatParams)
	popup.setText(translationKey)

static func sortDict(subject: Receiver, dict: Dictionary, shuffleBeforeSort) -> Array:
	var sorted: Array = dict.keys()
	if shuffleBeforeSort:
		sorted.shuffle()
	var dictSorter = subject.DictSorter.new(dict)
	sorted.sort_custom(Callable(dictSorter, "sort"))
	return sorted

static func walkInteractableNodes(subject: Receiver, node: Node, nodes: Array):
	for child in node.get_children():
		if (child is BaseButton or
			child is LineEdit or
			child is Slider):
			nodes.push_back(child)
		subject.walkInteractableNodes(child, nodes)
