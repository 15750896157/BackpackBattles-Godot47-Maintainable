extends RefCounted
## Connects the editable result scene to one modal lifetime.
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const SCREEN = preload("res://PvE/UI/LootScreen.tscn")
const CARD = preload("res://PvE/UI/LootCard.tscn")
const MODEL = preload("res://Code/Runtime/ViewModel/LootVM.gd")
const INK = Color("513c26")

static func show_page(page) -> void:
	var owner = page.owner
	var ui = page.ui
	var model = MODEL.new(owner.flow, ui.words, owner.t, owner.enemy_name, owner.effect_text)
	var data: Dictionary = model.snapshot()
	var root: Control = ui.open_canvas(owner.flow.screen_state, data.title, SCREEN)
	var epoch: int = owner.popup_epoch
	var result_key: String = "result_victory" if data.won else "result_defeat"
	var chinese := TranslationServer.get_locale().begins_with("zh")
	var keys := ["result_shade","result_gold","result_warning"]
	keys.append_array([result_key+"_zh"] if chinese else [result_key+"_crown",result_key+"_ribbon",result_key+"_halo"])
	if data.won:
		keys.append_array(["result_reward_paper","result_red","coin","heart"])
		if not chinese: keys.append("result_sparks")
	if not await AssetStream.prepare(REF.paths(keys), "popup"):
		return
	if not current(owner, root, epoch):
		return
	var shade := REF.picture(root, "result_shade", Rect2(0,0,1920,1080), true)
	root.move_child(shade, 0)
	var header := Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	root.move_child(header, 1)
	emblem(header, data, result_key, chinese)
	if data.won:
		label(root, "Subtitle", data.subtitle, 25, Color("f5dfb7"), 2)
	var statistics := REF.button(root,"result_warning",Rect2(1574,455,59,59),owner.show_combat_log)
	statistics.name = "LootStatistics"
	statistics.tooltip_text = ui.words("战斗统计","Battle statistics")
	if data.won:
		cards(root, data, owner, model, epoch)
		label(root, "CarryHint", data.carry_hint, 23, Color("dac8a8"), 2)
	elif not data.footer.is_empty():
		label(root, "DefeatMessage", data.ended, 27, Color("f7e4bd"), 2)
	if not data.footer.is_empty():
		var button: TextureButton = root.get_node("Continue" if data.won else "ReturnHome")
		button.name = data.footer.name
		action(button, func(): choose(owner, root, epoch, model, -1, {}, not data.won),
			data.footer.caption, 30, "result_red" if button.name == "LootSkipGold" else "result_gold")
	REF.fade_in(root)
	owner.focus_popup()

static func emblem(root: Control, data: Dictionary, key: String, chinese: bool) -> void:
	var won: bool = data.won
	var halo := Rect2(587,-47,776,774) if won else Rect2(590,91,773,748)
	if chinese:
		REF.picture(root,key+"_zh",Rect2(387,18,1146,705) if won else halo,true)
		return
	REF.picture(root,key+"_halo",halo)
	if won: REF.picture(root,"result_sparks",Rect2(387,43,1146,388))
	REF.picture(root,key+"_crown",Rect2(838,100,223,199) if won else Rect2(841,238,222,196))
	var ribbon := Rect2(623,288,690,136) if won else Rect2(627,424,686,135)
	REF.picture(root,key+"_ribbon",ribbon)
	REF.text(root,data.title,Rect2(ribbon.position+Vector2(190,15),Vector2(310,74)),54,Color("fff1ce"),4)

static func current(owner, root: Control, epoch: int) -> bool:
	return epoch == owner.popup_epoch and is_instance_valid(root) and root.is_inside_tree() and root.is_visible_in_tree()

static func choose(owner, root: Control, epoch: int, model, index: int,
		displayed: Dictionary, defeat: bool = false) -> void:
	if not current(owner, root, epoch) or root.has_meta("claiming"):
		return
	root.set_meta("claiming", true)
	for button in root.find_children("*", "BaseButton", true, false):
		button.disabled = true
	var result: Dictionary = model.confirm_defeat() if defeat else model.claim(index, displayed)
	owner.perform(result)
	if defeat and result.ok and owner.flow.screen_state == "RUN_RESULT":
		owner.return_to_title()
	if not result.ok and current(owner, root, epoch):
		root.remove_meta("claiming")
		for button in root.find_children("*", "BaseButton", true, false):
			button.disabled = false

static func cards(root: Control, data: Dictionary, owner, model, epoch: int) -> void:
	var count: int = data.cards.size()
	var width: float = minf(254.0, 1120.0 / maxi(1, count) - 23.0)
	var start: float = (1920.0 - (width + 23.0) * count + 23.0) / 2.0
	var holder: Control = root.get_node("Cards")
	for index in count:
		var entry: Dictionary = data.cards[index]
		var card: Control = CARD.instantiate()
		card.position.x = start + index * (width + 23.0)
		card.size.x = width
		holder.add_child(card)
		card.get_node("Paper").texture = REF.texture("result_reward_paper")
		var icon: TextureRect = card.get_node("Icon")
		icon.texture = REF.texture(entry.icon_key)
		if not entry.icon_id.is_empty():
			owner.detail_views.fill_icon(weakref(icon), entry.icon_id, epoch)
		else:
			icon.offset_top += 28.0
			icon.offset_bottom -= 28.0
		label(card, "Title", entry.title, 30)
		if not entry.rarity.is_empty():
			label(card, "Rarity", entry.rarity, 23, Color("8c6136"))
		var button: TextureButton = card.get_node("Select")
		button.name = "LootChoice_" + str(index)
		button.set_meta("reward", entry.reward.duplicate(true))
		action(button, func(): choose(owner, root, epoch, model, index, entry.reward), data.choose, 28, "result_gold")

static func action(button: TextureButton, callback: Callable, caption: String, font_size: int, key: String) -> void:
	var rect := Rect2(button.position, button.size)
	button.texture_normal = REF.texture(key)
	# 贴图实际画出来的药丸区域。等比缩放时它比按钮框窄，若按整块按钮框排字，
	# 文案会撑出药丸两端（胜利页底部按钮原来就是这样溢出的）。
	var drawn := rect
	if button.stretch_mode != TextureButton.STRETCH_SCALE:
		var texture_size := button.texture_normal.get_size()
		var factor := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
		var fitted := texture_size * factor
		drawn = Rect2(rect.get_center() - fitted / 2.0, fitted)
	# Keep the entire authored click target while the texture fits within it.
	REF.bind_button(button, rect, callback, caption, font_size)
	var caption_node: Label = button.get_child(button.get_child_count() - 1)
	var ink := Color("fff1d0") if key == "result_red" else INK
	caption_node.position = drawn.position - rect.position
	caption_node.size = drawn.size
	# 按药丸内框收紧字号并居中，保证任何长度的文案都完整落在药丸里。
	REF.bind_text(caption_node, caption, drawn.size, font_size, ink, 0)
	button.show()

static func label(parent: Control, path: String, value: String, size: int, color: Color = INK, outline: int = 0) -> void:
	var node: Label = parent.get_node(path)
	REF.bind_text(node, value, node.size, size, color, outline)
	REF.center_label(node)
	node.show()

