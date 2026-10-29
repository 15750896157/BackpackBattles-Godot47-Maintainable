extends Node
## Presentation only: authoritative rules, item shapes and saves are untouched.
const ROOT = "res://Art/20261022/"
const SHOP_KEYS = ["merchant", "shelf", "table", "storage_mat", "cell", "sell", "refresh", "price", "sale", "name", "plate1", "plate2", "plate3", "health", "stamina"]
const COMBAT_KEYS = ["name", "plate1", "plate2", "plate3", "health", "stamina", "play", "pause", "timeline_base", "timeline_fill", "shadow", "cell"]
const OFFERS = [Vector2(240, 300), Vector2(625, 300), Vector2(240, 600), Vector2(550, 600), Vector2(840, 600)]
const EXTRA = "res://Art/Polish20261022/"
const CATALOG = preload("res://PvE/Art/SuppliedArt.gd")
var curtain
var lighting
var ready_kind = ""
const STORAGE = Rect2(520, 855, 1000, 140)
var view: String = ""
var epoch: int = 0
var ui: Control
var scenery: Node2D
var layer: CanvasLayer
var records: Dictionary = {}
var prices: Array = []
var hero_hud: Dictionary = {}
var enemy_hud: Dictionary = {}
var clock: float = 0.0
var enemy_signature: String = ""
var enemy_build_cache: Dictionary = {}
var locale: String = ""
var touch_buttons:Array=[]
const ENGLISH = {"合成 · 图鉴":"Craft · Codex", "敌情 · 路线":"Intel · Journey", "撤销":"Undo", "重做":"Redo", "出售": "Sell", "合成表": "Recipes", "刷新": "Refresh", "确认出战": "Fight", "离开商店": "Leave Shop", "战斗日志": "Battle Log", "战斗进度": "Battle Progress", "仓库 · 固定独立槽位": "Storage · independent slots", "生命": "Health", "耐力": "Stamina", "玩家": "Player", "敌人": "Enemy"}
var board_script = preload("res://PvE/Art/Board.gd")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	layer = CanvasLayer.new(); layer.layer = 50; add_child(layer)
	var tooltip_layer = CanvasLayer.new(); tooltip_layer.layer = 150; tooltip_layer.name = "ItemDetailLayer"; add_child(tooltip_layer)
	Game.tooltipsNode.reparent(tooltip_layer)
	Game.recipeTooltipsNode.reparent(tooltip_layer)
	curtain = preload("res://PvE/Art/SceneCurtain.gd").new(); add_child(curtain)
	lighting = preload("res://PvE/Art/Lighting.gd").new(); add_child(lighting)
	Expedition.toolbar.position = Vector2(28, 1015)
	Expedition.toolbar.size = Vector2(1864, 56)
	Expedition.status.position = Vector2(970, 2)
	Expedition.status.size = Vector2(650, 48)

func _process(delta):
	if not Expedition.initialized or AssetStream.stopping: return
	Expedition.toolbar.hide()
	var desired = "shop" if Game.state == Game.State.Shop else "combat" if Game.state == Game.State.Combat else "title"
	if desired != view:
		view = desired
		_rebuild(desired)
	_hide_legacy()
	if desired == "shop": _layout_shop()
	elif desired == "combat": _layout_combat()
	clock += delta
	if clock < 0.08: return
	clock = 0.0
	if is_instance_valid(ui): _refresh_data()

func _rebuild(kind: String):
	epoch += 1
	var ticket = epoch
	if is_instance_valid(ui): layer.remove_child(ui); ui.queue_free()
	if is_instance_valid(scenery): scenery.get_parent().remove_child(scenery); scenery.queue_free()
	ui = null; scenery = null; records.clear(); prices.clear(); hero_hud.clear(); enemy_hud.clear();touch_buttons.clear()
	ready_kind = ""
	AssetStream.release("art-ui")
	if kind == "title":
		for actor in [Game.PLAYER, Game.OPPONENT]:
			if not is_instance_valid(actor) or actor.INVENTORY == null: continue
			for name in ["SuppliedGrid", "SuppliedHover"]:
				var node = actor.INVENTORY.get_node_or_null(name)
				if node != null: actor.INVENTORY.remove_child(node); node.queue_free()
		ui=Control.new();ui.name="TitleTouchHUD";ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
		_build_title()
		return
	var keys = SHOP_KEYS if kind == "shop" else COMBAT_KEYS
	var paths: Array = []
	for key in keys: paths.append(_art_path(key))
	for key in ["intel","table","shelf_top","shelf_bottom","undo","redo","cell_empty","stamina_regen","cooldown"]: paths.append(_art_path(key))
	for key in CATALOG.STATUS.values(): paths.append(CATALOG.ROOT+"status/"+key+".png")
	if not await AssetStream.prepare(paths, "art-ui") or ticket != epoch: return
	ui = Control.new(); ui.name = "SuppliedArtHUD"; ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	scenery = Node2D.new(); scenery.name = "SuppliedArtScenery"
	(Game.shopSceneNode if kind == "shop" else Game.combatSceneNode).add_child(scenery)
	scenery.z_index = -1
	if kind == "shop": _build_shop()
	else: _build_combat()
	_refresh_data()
	ready_kind = kind

func texture(key: String) -> Texture2D:
	if key in ["guide","home"]:return Expedition.menus.shell.image(key)
	return AssetStream.resources.get(_art_path(key))

func _art_path(key: String) -> String:
	if key == "sale": return CATALOG.ROOT+"ui/sale.png"
	if key in ["shelf_top","shelf_bottom"]:return CATALOG.ui_path("shelf")
	if key in ["stamina_regen","cooldown"]:return CATALOG.ROOT+"status/"+key+".png"
	var supplied=CATALOG.ui_path(key)
	if not supplied.is_empty():return supplied
	return EXTRA+key+".png" if key in ["intel","undo","redo"] else ROOT+key+".png"

func picture(key: String, rect: Rect2, parent: Node, stretch: bool = false):
	var node = NinePatchRect.new() if stretch else TextureRect.new()
	node.name = "Art_" + key; node.texture = texture(key)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stretch:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: node.set_patch_margin(side, 8)
	else:
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position; node.size = rect.size
	parent.add_child(node)
	records[str(node.get_path())] = {"key": key, "rect": rect, "stretch": stretch}
	return node

func text(value: String, rect: Rect2, parent: Node, size: int = 28, color: Color = Color("fff0cd")) -> Label:
	var node = Label.new(); node.text = local(value); node.set_meta("art_text", value); node.set_meta("art_font_size", size)
	node.position = rect.position; node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", Expedition.ui_font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color("171b20"))
	node.add_theme_constant_override("outline_size", 3)
	if color.get_luminance() < 0.3:
		node.add_theme_color_override("font_outline_color",Color("fff1cc"))
		node.add_theme_constant_override("outline_size",1)
	parent.add_child(node); return node

func button(key: String, rect: Rect2, action: Callable, caption: String = "") -> TextureButton:
	var node = TextureButton.new(); node.name = "Action_" + key
	node.texture_normal = texture(key); node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position; node.size = rect.size
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action); ui.add_child(node)
	node.mouse_entered.connect(func(): _button_feedback(node,Color(1.10,1.06,1.0)))
	node.mouse_exited.connect(func(): _button_feedback(node,Color.WHITE))
	if not caption.is_empty(): text(caption, Rect2(Vector2.ZERO, rect.size), node)
	return node

func local(value: String) -> String:
	if value in ["左转","右转","放回"]:return value if TranslationServer.get_locale().begins_with("zh") else str({"左转":"Left","右转":"Right","放回":"Return"}[value])
	if value == "教程": return "教程" if TranslationServer.get_locale().begins_with("zh") else "Guide"
	if value == "仓库": return "仓库" if TranslationServer.get_locale().begins_with("zh") else "Storage"
	return value if TranslationServer.get_locale().begins_with("zh") else str(ENGLISH.get(value, value))

func _build_shop():
	picture("shelf_top", Rect2(15, 300, 815, 84), scenery)
	picture("shelf_bottom", Rect2(15, 600, 951, 80), scenery)
	var merchant = picture("merchant", Rect2(0, 610, 470, 312), scenery)
	merchant.z_index = 0
	var desk = picture("table", Rect2(0, 861, 1920, 219), scenery)
	desk.z_index = 0
	picture("storage_mat", Rect2(490, 788, 1060, 222), scenery)
	picture("sell", Rect2(95, 835, 290, 165), scenery)
	text("仓库", Rect2(1100, 805, 300, 38), ui, 25)
	button("codex", Rect2(440, 690, 245, 120), open_book)
	button("journey", Rect2(785, 675, 135, 135), open_intel)
	button("undo",Rect2(1110,690,88,88),func(): Expedition.perform(Expedition.flow.edit("undo"))).tooltip_text = local("撤销")
	button("redo",Rect2(1230,690,88,88),func(): Expedition.perform(Expedition.flow.edit("redo"))).tooltip_text = local("重做")
	button("refresh", Rect2(805, 0, 120, 317), _refresh_shop)
	var refresh_caption = text("", Rect2(819, 182, 72, 35), ui, 22, Color("302114"))
	refresh_caption.name = "RefreshCost"
	var start = button("battle", Rect2(1670, 0, 225, 347), _start)
	start.name = "ArtStartBattle"
	var stage = text("确认出战", Rect2(15, 244, 195, 65), start, 40)
	stage.name = "StageCaption"
	button("settings", Rect2(1775, 365, 110, 110), Expedition.show_settings).name="Action_shop_settings"
	button("guide", Rect2(1630, 365, 110, 110), Expedition.show_ui_guide)
	# The supplied backplates belong to status displays, never generic windows.
	picture("plate1", Rect2(1300, 50, 215, 65), ui)
	var gold = text("", Rect2(1300, 50, 215, 65), ui, 32)
	gold.name = "GoldValue"
	for index in 5:
		var tag = button("price", Rect2(OFFERS[index] + Vector2(75, -70), Vector2(82, 72)), _lock.bind(index))
		var label = text("", Rect2(0, 22, 82, 42), tag, 30, Color("301d13"))
		var sale = button("sale", Rect2(OFFERS[index] + Vector2(129, -83), Vector2(38, 38)), _lock.bind(index))
		var sale_label = text("%", Rect2(OFFERS[index] + Vector2(129, -83), Vector2(38, 38)), ui, 20)
		var locked = text("", Rect2(OFFERS[index] + Vector2(-95, 14), Vector2(190, 30)), ui, 22)
		for node in [tag,sale,label,sale_label,locked]: node.z_index = 0
		prices.append({"tag": tag, "label": label, "sale": sale, "sale_label": sale_label, "lock": locked})
	hero_hud = _hud(Rect2(1470, 505, 420, 157), "玩家")
	for index in 3:
		var keys=["previous","next","close"];var captions=[local("左转"),local("右转"),local("放回")]
		var action=Expedition.menus.shell.icon_button(ui,keys[index],captions[index],_touch_action.bind(index),Vector2(94,88))
		action.position=Vector2(1110+index*110,700);action.name=["TouchRotateLeft","TouchRotateRight","TouchReturn"][index]
		touch_buttons.append(action);action.hide()

func _hud(rect: Rect2, title: String) -> Dictionary:
	picture("plate2", rect, ui, true)
	picture("name", Rect2(rect.position + Vector2(10, 7), Vector2(rect.size.x - 20, 33)), ui, true)
	var name_label = text(title, Rect2(rect.position + Vector2(10, 5), Vector2(rect.size.x - 20, 34)), ui, 24)
	var result = {"name": name_label}
	for index in 2:
		var bar_rect = Rect2(rect.position + Vector2(105, 53 + index * 47), Vector2(rect.size.x - 118, 31))
		picture("plate3", bar_rect, ui, true)
		var bar = TextureProgressBar.new(); bar.texture_progress = texture("health" if index == 0 else "stamina")
		bar.nine_patch_stretch = true; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.stretch_margin_left = 8; bar.stretch_margin_right = 8; bar.stretch_margin_top = 8; bar.stretch_margin_bottom = 8
		bar.position = bar_rect.position; bar.size = bar_rect.size; bar.max_value = 100; ui.add_child(bar)
		var label = text("", bar_rect, ui, 22)
		if index == 1: picture("stamina_regen",Rect2(rect.position+Vector2(10,99),Vector2(26,26)),ui)
		text("生命" if index == 0 else "耐力", Rect2(rect.position + Vector2(32 if index == 1 else 10, 52 + index * 47), Vector2(68 if index == 1 else 90, 32)), ui, 23)
		result["health" if index == 0 else "stamina"] = bar
		result["hp_text" if index == 0 else "sp_text"] = label
	var strip=HBoxContainer.new();strip.position=rect.position+Vector2(0,rect.size.y+4);strip.size=Vector2(rect.size.x,32);strip.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(strip)
	result["status_icons"]=strip;result["status_signature"]=""
	result["statuses"] = text("", Rect2(rect.position + Vector2(0, rect.size.y+36), Vector2(rect.size.x, 28)), ui, 19)
	return result

func _build_combat():
	hero_hud = _hud(Rect2(480, 820, 420, 150), "玩家")
	enemy_hud = _hud(Rect2(1020, 820, 420, 150), "敌人")
	picture("shadow", Rect2(200, 980, 260, 44), scenery)
	picture("shadow", Rect2(1460, 980, 260, 44), scenery)
	picture("timeline_base", Rect2(680, 34, 560, 70), ui)
	picture("cooldown",Rect2(634,48,32,32),ui)
	var progress = TextureProgressBar.new(); progress.name = "ArtTimeline"
	progress.texture_progress = texture("timeline_fill"); progress.nine_patch_stretch = true
	progress.position = Vector2(680, 46); progress.size = Vector2(560, 20)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(progress)
	button("pause", Rect2(758, 110, 78, 78), Game.combatTimer.onPauseButtonPressed)
	button("play", Rect2(880, 110, 78, 78), Game.combatTimer.unpause)
	var speed = Button.new(); speed.text = "×1 / ×2 / ×4"; speed.position = Vector2(1000, 120); speed.size = Vector2(220, 44)
	speed.custom_minimum_size.y = 68
	speed.pressed.connect(func(): Game.combatTimer.onFastButtonPressed()); ui.add_child(speed)
	button("settings", Rect2(1770, 28, 112, 112), Expedition.show_settings).name="Action_combat_settings"
	button("guide", Rect2(1630, 28, 112, 112), Expedition.show_ui_guide)
	button("codex", Rect2(825, 325, 125, 125), open_book)
	button("journey", Rect2(825, 495, 125, 125), open_intel)
	text("战斗进度", Rect2(815, 72, 290, 38), ui, 24)

func _build_title():
	for index in 3:
		var keys=["codex","settings","guide"]
		var actions=[Expedition.show_codex,Expedition.show_settings,Expedition.show_ui_guide]
		button(keys[index],Rect2(1740,260+index*185,140,140),actions[index])
	text("教程",Rect2(1740,740,140,40),ui,23)

func _hide_legacy():
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if not is_instance_valid(actor): continue
		actor.get_node("CombatUI").hide()
		if actor.has_node("ShopUI"): actor.get_node("ShopUI").hide()
	if Game.state == Game.State.Shop:
		var keep = ["Background", "Storagebox", "Sellbox", "Items", "SuppliedArtScenery"]
		for child in Game.shopSceneNode.get_children():
			if child is CanvasItem and child.name not in keep and not str(child.name).begins_with("ShopOffer"): child.hide()
		for slot in Game.shopSceneNode.slots:
			for child in slot.get_children():
				if child is CanvasItem: child.hide()
		for path in ["StorageShakeButton", "Chestnut", "Shadow", "Trade"]:
			var node = Game.STORAGEBOX.get_node_or_null(path) if path == "StorageShakeButton" else Game.SELLBOX.get_node_or_null(path)
			if node is CanvasItem: node.hide()
	elif Game.state == Game.State.Combat:
		Game.combatSceneNode.get_node("UI").hide()
		Game.combatSceneNode.get_node("CombatLogButtonNode").hide()
	var options = Game.mainNode.get_node_or_null("UI/OptionsButton")
	if options != null: options.hide()
	Game.mainNode.get_node("UI/Frame").hide()
	if Game.state==Game.State.Title:
		Game.titleScreen.continueNode.hide()
		for path in ["ButtonsNode","AboveBlackLayer"]:
			var unused=Game.titleScreen.get_node_or_null(path)
			if unused is CanvasItem:unused.hide()
	for path in ["UI/Toolbar", "UI/UndoStack"]: Game.mainNode.get_node(path).hide()

func _layout_shop():
	_move_inventory(Game.PLAYER.INVENTORY, Vector2(950, 140))
	Game.PLAYER.INVENTORY.scale = Vector2.ONE
	Game.PLAYER.INVENTORY.z_index = 20
	_update_board(Game.PLAYER.INVENTORY, Expedition.flow.run.get("build", {}))
	for index in Game.shopSceneNode.slots.size():
		var slot = Game.shopSceneNode.slots[index]
		if slot.global_position != OFFERS[index]:
			var shift = OFFERS[index] - slot.global_position
			slot.global_position = OFFERS[index]
			if is_instance_valid(slot.item) and not slot.item.dragged and not slot.bought: slot.item.global_position += shift
	Game.STORAGEBOX.set_meta("art_storage_rect", STORAGE)
	if Game.STORAGEBOX.pve_capacity >= 0 and Game.STORAGEBOX.pve_slot_root != null and not Game.STORAGEBOX.has_meta("art_slots_reset"):
		Game.STORAGEBOX.pve_capacity = -1
		Game.STORAGEBOX.set_meta("art_slots_reset", true)
	Game.STORAGEBOX.pve_refresh_slots(Expedition.flow.run.get("build", {"storage_capacity": 4}))
	var sell_center = Vector2(240, 917.5)
	var sell_size = Vector2(312.0 / 242.0 * 165.0, 165)
	Game.SELLBOX.global_position = sell_center
	var shape = Game.SELLBOX.get_node("CollisionShape2D")
	if not shape.has_meta("art_shape"):
		shape.shape = RectangleShape2D.new(); shape.position = Vector2.ZERO; shape.set_meta("art_shape", true)
	shape.shape.size = sell_size
	Game.SELLBOX.rect = Rect2(sell_center - sell_size * 0.5, sell_size)
	Game.SELLBOX.bottomPos.global_position = sell_center
	Game.SELLBOX.goldPos.global_position = sell_center
	Game.PLAYER.goldPos.global_position = Vector2(1500, 58)
	Game.shopSceneNode.get_node("GoldPos").global_position = Vector2(1500, 58)

func _layout_combat():
	for index in 2:
		var actor = Game.PLAYER if index == 0 else Game.OPPONENT
		if not is_instance_valid(actor): continue
		_move_inventory(actor.INVENTORY, Vector2(60 if index == 0 else 1060, 160))
		actor.INVENTORY.scale = Vector2.ONE
		actor.INVENTORY.z_index = 20
		var signature = str(Expedition.flow.run.current_node) + ":" + str(Expedition.native_phase)
		if signature != enemy_signature:
			enemy_signature = signature
			enemy_build_cache = Expedition.enemy_build(Expedition.flow.run.current_node, Expedition.native_phase)
		var build = Expedition.flow.run.get("build", {}) if index == 0 else enemy_build_cache
		_update_board(actor.INVENTORY, build)

func _move_inventory(inventory, target: Vector2):
	var shift: Vector2 = target - inventory.global_position
	if shift.length_squared() < 0.01: return
	inventory.global_position = target
	for item in inventory.getItems():
		if is_instance_valid(item) and not item.dragged: item.global_position += shift

func _update_board(inventory, build: Dictionary):
	inventory.tilemap.modulate.a = 0.0
	var board = inventory.get_node_or_null("SuppliedGrid")
	if board == null and texture("cell") != null:
		board = Node2D.new(); board.set_script(board_script); board.name = "SuppliedGrid"; board.z_index = -10; inventory.add_child(board)
		board.cell_texture = texture("cell")
		board.empty_texture = texture("cell_empty")
	if board != null: board.configure(build)
	if inventory.character == Game.PLAYER and inventory.get_node_or_null("SuppliedHover") == null:
		var hover = Node2D.new(); hover.name = "SuppliedHover"; hover.set_script(preload("res://PvE/Art/Hover.gd")); hover.z_index = 100; inventory.add_child(hover)

func _refresh_data():
	if Expedition.flow.run.is_empty(): return
	for label in ui.find_children("*", "Label", true, false):
		var key = str(label.get_meta("art_text", ""))
		if not key.is_empty(): label.text = local(key)
	_update_hud(hero_hud, Game.PLAYER, Expedition.t(str(Expedition.db.get_row("characters", str(Expedition.flow.run.character_id)).get("name_key", ""))))
	if view == "combat":
		_update_hud(enemy_hud, Game.OPPONENT, Expedition.enemy_name(Expedition.flow.run.current_node))
		var progress = ui.get_node_or_null("ArtTimeline")
		if progress != null: progress.value = 100.0 * Expedition.flow.playback_time / maxf(0.01, float(Expedition.flow.combat_result.get("elapsed_time", 1.0)))
	elif view == "shop":
		var chinese = TranslationServer.get_locale().begins_with("zh")
		ui.get_node("GoldValue").text = ("金币 %d" if chinese else "Gold %d") % int(Expedition.flow.run.gold)
		ui.get_node("RefreshCost").text = ("%d 金" if chinese else "%d G") % Game.shopSceneNode.getRerollCost()
		ui.get_node("ArtStartBattle/StageCaption").text = ("前进" if chinese else "Continue") if Expedition.flow.run.current_node.get("type", "") == "merchant" else ("开战" if chinese else "Battle")
		for index in prices.size():
			var data = Expedition.bridge.slot_data(index); var shown = not data.is_empty() and not bool(data.get("sold", false))
			var item = Game.shopSceneNode.slots[index].item
			shown = shown and is_instance_valid(item) and str(item.get_meta("pve_definition_id","")) == str(data.get("definition_id",""))
			var sale = shown and bool(data.get("discounted", false))
			prices[index].tag.visible = shown; prices[index].sale.visible = sale; prices[index].sale_label.visible = sale
			prices[index].label.text = str(int(data.get("price", 0)))
			prices[index].lock.text = ("已锁定" if chinese else "Locked") if bool(data.get("locked", false)) else ""
			prices[index].tag.disabled = Expedition.syncing or is_instance_valid(Game.draggedItem)
		var start = ui.get_node_or_null("ArtStartBattle")
		if start != null: start.disabled = Expedition.syncing or Expedition.combat_loading or curtain.busy or is_instance_valid(Game.draggedItem)
		var refresh = ui.get_node_or_null("Action_refresh")
		if refresh != null: refresh.disabled = Expedition.syncing or Expedition.render_pending or curtain.busy or is_instance_valid(Game.draggedItem)
		for key in ["undo","redo"]:
			var action = ui.get_node_or_null("Action_"+key)
			if action != null:
				action.disabled = Expedition.syncing or curtain.busy or is_instance_valid(Game.draggedItem)
				action.visible=not is_instance_valid(Game.draggedItem)
		for action in touch_buttons:action.visible=is_instance_valid(Game.draggedItem) and not Expedition.panel.visible
	for label in ui.find_children("*", "Label", true, false): _fit_label(label)

func _fit_label(label: Label):
	var nominal = int(label.get_meta("art_font_size", 24))
	var size = roundi(nominal * float(Expedition.preferences.values.get("ui_scale", 1.0)))
	var font = label.get_theme_font("font")
	var lines = label.text.split("\n")
	while size > 14:
		var width = 0.0
		for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if width <= label.size.x - 6 and font.get_height(size) * lines.size() <= label.size.y: break
		size -= 1
	label.add_theme_font_size_override("font_size", size)

func _update_hud(hud: Dictionary, actor, caption: String):
	if hud.is_empty() or not is_instance_valid(actor): return
	hud.name.text = caption
	hud.health.value = 100.0 * actor.getCurrentHealth() / maxf(1.0, actor.getMaxHealth())
	hud.stamina.value = 100.0 * actor.curStamina / maxf(1.0, actor.maxStamina)
	hud.hp_text.text = "%d / %d" % [ceili(actor.getCurrentHealth()), ceili(actor.getMaxHealth())]
	hud.sp_text.text = "%.1f / %.1f" % [actor.curStamina, actor.maxStamina]
	var status_text: Array[String] = []
	var icon_statuses:Array=[]
	for type in actor.buffs:
		if actor.buffs[type].getStacks() <= 0:continue
		var key=str(Game.eventTypeKeys[type])
		if CATALOG.STATUS.has(key):icon_statuses.append([key,actor.buffs[type].getStacks()])
		else:status_text.append(Util.tra(key)+" "+str(actor.buffs[type].getStacks()))
	var signature=str(icon_statuses.map(func(value):return value[0]))
	if signature!=hud.status_signature:
		for child in hud.status_icons.get_children():hud.status_icons.remove_child(child);child.queue_free()
		for value in icon_statuses:
			var icon=TextureRect.new();icon.texture=AssetStream.resources.get(CATALOG.ROOT+"status/"+CATALOG.STATUS[value[0]]+".png");icon.custom_minimum_size=Vector2(30,30);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.tooltip_text=Util.tra(value[0]);hud.status_icons.add_child(icon)
			text(str(value[1]),Rect2(0,0,40,30),hud.status_icons,20)
		hud.status_signature=signature
	var number=0
	for value in icon_statuses:
		hud.status_icons.get_child(number*2+1).text=str(value[1]);number+=1
	hud.statuses.text = " · ".join(status_text)
	hud.statuses.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.statuses.tooltip_text = hud.statuses.text

func _refresh_shop():
	if not Expedition.syncing and not is_instance_valid(Game.draggedItem): Expedition.bridge.refresh_shop()
func _start(): Game.shopSceneNode.get_node("StartCombatButton").activateButton()
func _lock(index: int):
	var slot = Game.shopSceneNode.slots[index]
	slot.setReserved(not slot.reserved)

func _touch_action(index:int):
	var item=Game.draggedItem
	if not is_instance_valid(item):return
	if index==0:item.rotateLeft()
	elif index==1:item.rotateRight()
	else:Expedition.bridge.cancel_drag(item)
func is_touch_control_event(event:InputEvent)->bool:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch) or not is_instance_valid(Game.draggedItem):return false
	for action in touch_buttons:
		if is_instance_valid(action) and action.is_visible_in_tree() and action.get_global_rect().has_point(event.position):return true
	return false


func open_book():
	if view == "shop": Expedition.show_crafting()
	else: Expedition.show_combat_log()

func open_intel():
	if Expedition.flow.run.current_node.get("type", "").ends_with("combat") or Expedition.flow.run.current_node.get("type", "") == "boss": Expedition.show_current_enemy()
	else: Expedition.show_journey()

func reveal_ready(kind: String, ticket: int, epoch_value: int):
	while not AssetStream.stopping and epoch_value == Expedition.view_epoch:
		var right_state = Game.state == Game.State.Shop if kind == "shop" else Game.state == Game.State.Combat if kind == "combat" else Game.state == Game.State.Title
		if right_state and not Game.sceneAnimation.is_playing() and not Expedition.syncing and not Expedition.combat_loading and (kind == "title" or ready_kind == kind): break
		await get_tree().process_frame
	if AssetStream.stopping: return
	await get_tree().process_frame
	await curtain.reveal(ticket)


func _button_feedback(node: Control, value: Color):
	if not is_instance_valid(node) or (node is BaseButton and node.disabled): return
	var tween = node.create_tween().set_ignore_time_scale(true)
	tween.tween_property(node,"modulate",value,0.10)
