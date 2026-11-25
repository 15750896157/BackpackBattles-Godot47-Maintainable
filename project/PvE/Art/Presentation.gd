extends Node
## Presentation only: authoritative rules, item shapes and saves are untouched.
const ROOT = "res://Art/20261022/"
const SHOP_KEYS = ["merchant", "shelf", "table", "storage_mat", "cell", "cell_slot", "sell", "refresh", "price", "sale", "name", "plate1", "plate2", "plate3", "health", "stamina", "class_badge"]
const COMBAT_KEYS = ["name", "plate1", "plate2", "plate3", "health", "stamina", "play", "pause", "timeline_base", "timeline_fill", "shadow", "cell", "cell_slot"]
const OFFERS = [Vector2(182,224), Vector2(490,224), Vector2(102,540), Vector2(365,540), Vector2(663,540)]
const EXTRA = "res://Art/Polish20261022/"
const CATALOG = preload("res://PvE/Art/SuppliedArt.gd")
const COMBAT_SCREEN = preload("res://PvE/UI/CombatScreen.gd")
const SHOP_SCREEN = preload("res://PvE/UI/ShopScreen.gd")
const REFERENCE_STAGES = preload("res://PvE/Art/ReferenceStages.gd")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const STATUS_BADGES = preload("res://PvE/Art/StatusBadges.gd")
var curtain
var lighting
var combat_fx
var ready_kind = ""
const STORAGE = Rect2(622, 938, 760, 124)
var view: String = ""
var epoch: int = 0
var ui: Control
var routed_title: Control
var routed_combat: COMBAT_SCREEN
var routed_shop: SHOP_SCREEN
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
const ENGLISH = {"合成 · 图鉴":"Craft · Codex", "敌情 · 路线":"Intel · Journey", "撤销":"Undo", "重做":"Redo", "出售": "Sell", "合成表": "Recipes", "刷新": "Refresh", "确认出战": "Fight", "离开商店": "Leave Shop", "战斗日志": "Battle Log", "战斗进度": "Battle Progress", "仓库 · 固定独立槽位": "Storage · independent slots", "护甲":"Armor", "生命": "Health", "耐力": "Stamina", "玩家": "Player", "敌人": "Enemy"}
var board_script = preload("res://PvE/Art/Board.gd")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	layer = CanvasLayer.new(); layer.layer = 50; add_child(layer)
	var tooltip_layer = CanvasLayer.new(); tooltip_layer.layer = 150; tooltip_layer.name = "ItemDetailLayer"; add_child(tooltip_layer)
	Game.tooltipsNode.reparent(tooltip_layer)
	Game.recipeTooltipsNode.reparent(tooltip_layer)
	curtain = preload("res://Code/Runtime/Scene/TransitionLayer.tscn").instantiate()
	curtain.configure(preload("res://PvE/Art/SceneCurtain.gd").new())
	Game.mainNode.add_child(curtain)
	lighting = preload("res://PvE/Art/Lighting.gd").new(); add_child(lighting)
	combat_fx = preload("res://PvE/Art/CombatVFX.gd").new(); combat_fx.attach(self)

func _process(delta):
	if not Expedition.initialized or AssetStream.stopping: return
	Expedition.hud_layer.set_run_controls_visible(false)
	var desired = "shop" if Game.state == Game.State.Shop else "combat" if Game.state == Game.State.Combat else "title"
	if desired != view or (desired == "title" and not is_instance_valid(routed_title) and locale != TranslationServer.get_locale()):
		view = desired
		_rebuild(desired)
	_hide_legacy()
	if desired == "shop": _layout_shop()
	elif desired == "combat": _layout_combat()
	clock += delta
	if clock < 0.08: return
	clock = 0.0
	if is_instance_valid(ui): _refresh_data()

func _clear_view() -> void:
	epoch += 1
	if is_instance_valid(ui) and ui != routed_title and ui != routed_combat:
		layer.remove_child(ui); ui.queue_free()
	if is_instance_valid(scenery): scenery.get_parent().remove_child(scenery); scenery.queue_free()
	ui = null; routed_title = null; routed_combat = null; routed_shop = null; scenery = null
	records.clear(); prices.clear(); hero_hud.clear(); enemy_hud.clear(); touch_buttons.clear()
	ready_kind = ""
	AssetStream.release("art-ui")

func _clear_title_inventory_overlays() -> void:
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if not is_instance_valid(actor) or actor.INVENTORY == null: continue
		for name in ["SuppliedGrid", "SuppliedHover"]:
			var node = actor.INVENTORY.get_node_or_null(name)
			if node != null: actor.INVENTORY.remove_child(node); node.queue_free()

func use_routed_title(screen: Control) -> void:
	_clear_view()
	_clear_title_inventory_overlays()
	routed_title = screen
	ui = screen
	view = "title"
	ready_kind = "title"
	locale = TranslationServer.get_locale()

func combat_screen_paths() -> Array:
	var paths: Array = []
	for key in COMBAT_SCREEN.ART_KEYS + ["shadow", "cell", "cell_slot", "cell_empty", "board_guide"]:
		paths.append(_art_path(key))
	for key in STATUS_BADGES.ICONS.values():
		var path: String = CATALOG.status_path(key)
		if not paths.has(path):
			paths.append(path)
	return paths

func bind_combat_screen(screen: COMBAT_SCREEN) -> Error:
	var art: Dictionary = {}
	for key in COMBAT_SCREEN.ART_KEYS:
		art[key] = texture(key)
	return screen.bind(Expedition.combat_vm, art, Expedition.ui_font, {
		"is_negative": func(id): return Expedition.db.get_row("statuses", id).get("polarity", "") == "negative",
		"texture": func(key): return AssetStream.resources.get(CATALOG.status_path(key)),
		"name": func(id): return Expedition.t("status." + id + ".name") if id != "armor" else local("护甲"),
	})

func use_routed_combat(screen: COMBAT_SCREEN) -> void:
	_clear_view()
	routed_combat = screen
	ui = screen
	view = "combat"
	locale = TranslationServer.get_locale()
	_attach_scenery(Game.combatSceneNode)
	REFERENCE_STAGES.combat_shadows(self)
	_layout_combat()
	_refresh_routed_combat()
	ready_kind = "combat"

func release_routed_combat(screen: Control) -> void:
	if routed_combat == screen:
		_clear_view()

func use_routed_shop(screen: SHOP_SCREEN, shop_scenery: Node2D) -> void:
	_clear_view()
	routed_shop = screen
	ui = screen
	scenery = shop_scenery
	view = "shop"
	locale = TranslationServer.get_locale()
	Game.shopSceneNode.add_child(scenery)
	layer.add_child(screen)
	touch_buttons.assign(screen.rotation_buttons())
	_layout_shop()
	screen.refresh_from_host()
	screen.show()
	ready_kind = "shop"

func release_routed_shop() -> void:
	if is_instance_valid(routed_shop):
		_clear_view()

func _attach_scenery(carrier: Node) -> void:
	scenery = Node2D.new()
	scenery.name = "SuppliedArtScenery"
	scenery.z_index = -1
	carrier.add_child(scenery)

func _rebuild(kind: String):
	locale=TranslationServer.get_locale()
	_clear_view()
	var ticket = epoch
	if kind == "title":
		if not await AssetStream.prepare(preload("res://PvE/UI/ReferenceCanvas.gd").paths(preload("res://PvE/UI/TitleLayout.gd").KEYS),"art-ui") or ticket != epoch: return
		_clear_title_inventory_overlays()
		ui=Control.new();ui.name="TitleTouchHUD";ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
		_build_title()
		ready_kind = "title"
		return
	var keys = SHOP_KEYS if kind == "shop" else COMBAT_KEYS
	var paths: Array = []
	for key in keys: paths.append(_art_path(key))
	for key in ["intel","table","shelf_top","shelf_bottom","cell","cell_slot","cell_empty","board_guide","stamina_regen","cooldown","settings","journey","codex","battle","coin"]: paths.append(_art_path(key))
	for key in CATALOG.STATUS.values(): paths.append(CATALOG.status_path(key))
	if not await AssetStream.prepare(paths, "art-ui") or ticket != epoch: return
	ui = Control.new(); ui.name = "SuppliedArtHUD"; ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	_attach_scenery(Game.shopSceneNode if kind == "shop" else Game.combatSceneNode)
	if kind == "shop": _build_shop()
	else: _build_combat()
	_refresh_data()
	ready_kind = kind

func texture(key: String) -> Texture2D:
	if key in ["guide","home"]:return Expedition.menus.shell.image(key)
	return AssetStream.resources.get(_art_path(key))

func _art_path(key: String) -> String:
	if key == "class_badge": return "res://Art/Reference20261102/class_badge.png"
	if key == "coin": return "res://Art/Reference20261102/coin.png"
	if key in ["shelf_top","shelf_bottom"]:return CATALOG.ui_path("shelf")
	if key in ["stamina_regen","cooldown"]:return CATALOG.status_path(key)
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
	node.add_theme_font_override("font", Expedition.ui_font)
	node.add_theme_font_size_override("font_size", REF.font_step(size))
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color("171b20"))
	node.add_theme_constant_override("outline_size", 3)
	if color.get_luminance() < 0.3:
		node.add_theme_color_override("font_outline_color",Color("fff1cc"))
		node.add_theme_constant_override("outline_size",1)
	parent.add_child(node)
	REF.center_label(node)
	return node

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
	REFERENCE_STAGES.shop(self)

func _hud(rect: Rect2, title: String) -> Dictionary:
	picture("plate2",rect,ui)
	var enemy=title=="敌人"
	var name_rect=Rect2(rect.position+Vector2(rect.size.x-342 if enemy else 0,-47),Vector2(342,46))
	picture("name",name_rect,ui).flip_h=enemy
	var name_label=text(title,Rect2(name_rect.position+Vector2(20,0),Vector2(302,46)),ui,29)
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if enemy else HORIZONTAL_ALIGNMENT_LEFT
	var result = {"name":name_label}
	for index in 2:
		var bar_rect = Rect2(rect.position+Vector2(81+index*268,18),Vector2(205,36))
		picture("plate3",bar_rect,ui)
		var bar = TextureProgressBar.new();bar.texture_progress=texture("health" if index==0 else "stamina");bar.nine_patch_stretch=true
		bar.position=bar_rect.position;bar.size=bar_rect.size;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(bar)
		result["health" if index==0 else "stamina"]=bar
		result["hp_text" if index==0 else "sp_text"]=text("",bar_rect,ui,24)
		text("生命" if index==0 else "耐力",Rect2(rect.position+Vector2(15+index*268,15),Vector2(65,40)),ui,25)
	for index in 2:
		text("增益" if index==0 else "减益",Rect2(rect.position+Vector2(14+index*268,65),Vector2(65,40)),ui,25)
		var strip = GridContainer.new();strip.columns=4;strip.position=rect.position+Vector2(82+index*268,68);strip.size=Vector2(188,62);strip.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(strip)
		result["status_icons" if index==0 else "debuff_icons"]=strip
	result["status_signature"]=""
	result["statuses"]=text("",Rect2(rect.position+Vector2(82,112),Vector2(465,30)),ui,18)
	return result

func _build_combat():
	REFERENCE_STAGES.combat(self)

func _build_title():
	preload("res://PvE/UI/TitleLayout.gd").build(ui)

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
		for child in Game.titleScreen.get_children():
			if child is CanvasItem: child.hide()
		Game.titleScreen.continueNode.hide()
		for path in ["ButtonsNode","AboveBlackLayer"]:
			var unused=Game.titleScreen.get_node_or_null(path)
			if unused is CanvasItem:unused.hide()
	for path in ["UI/Toolbar", "UI/UndoStack"]: Game.mainNode.get_node(path).hide()

func _layout_shop():
	_move_inventory(Game.PLAYER.INVENTORY, Vector2(964, 169))
	Game.PLAYER.INVENTORY.scale = Vector2.ONE*grid_scale()
	Game.PLAYER.INVENTORY.z_index = 20
	_update_board(Game.PLAYER.INVENTORY, Expedition.flow.run.get("build", {}))
	for index in Game.shopSceneNode.slots.size():
		var slot = Game.shopSceneNode.slots[index]
		if slot.global_position != OFFERS[index]:
			var shift = OFFERS[index] - slot.global_position
			slot.global_position = OFFERS[index]
			if is_instance_valid(slot.item) and not slot.item.dragged and not slot.bought: slot.item.global_position += shift
	Game.STORAGEBOX.set_meta("art_storage_rect", STORAGE)
	var cloth=scenery.get_node_or_null("StorageCloth") if is_instance_valid(scenery) else null
	if cloth!=null and cloth.texture!=null:
		var image_size=cloth.texture.get_size()
		var factor=minf(cloth.size.x/image_size.x,cloth.size.y/image_size.y)
		var origin=cloth.global_position+(cloth.size-image_size*factor)*0.5
		var slots:Array=[]
		# Pixel rectangles of the four dark squares already painted into the PSD.
		for cell in [Rect2(247,80,76,76),Rect2(463,80,76,76),Rect2(644,77,76,76),Rect2(838,80,76,76)]:
			slots.append(Rect2(origin+cell.position*factor,cell.size*factor))
		Game.STORAGEBOX.set_meta("art_storage_slots",slots)
		var capacity=clampi(int(Expedition.flow.run.get("build",{}).get("storage_capacity",2)),1,slots.size())
		Game.STORAGEBOX.set_meta("art_storage_rect",slots[0].merge(slots[capacity-1]))
	if Game.STORAGEBOX.pve_capacity >= 0 and Game.STORAGEBOX.pve_slot_root != null and not Game.STORAGEBOX.has_meta("art_slots_reset"):
		Game.STORAGEBOX.pve_capacity = -1
		Game.STORAGEBOX.set_meta("art_slots_reset", true)
	Game.STORAGEBOX.pve_refresh_slots(Expedition.flow.run.get("build", {"storage_capacity": 4}))
	if Game.STORAGEBOX.has_meta("art_storage_slots"):
		for index in Game.STORAGEBOX.items.size():
			var item=Game.STORAGEBOX.items[index]
			if not is_instance_valid(item) or item.dragged:continue
			var size=Game.STORAGEBOX.pve_slot_rect(index).size
			if item.get_meta("cloth_slot_size",Vector2.ZERO)!=size:
				Expedition.bridge.fit_native_visual(item,true);item.set_meta("cloth_slot_size",size)
			Expedition.bridge.place_storage_view(item,index)
	var sell_center = Vector2(309, 966)
	var sell_size = Vector2(298, 228)
	Game.SELLBOX.global_position = sell_center
	var shape = Game.SELLBOX.get_node("CollisionShape2D")
	if not shape.has_meta("art_shape"):
		shape.shape = RectangleShape2D.new(); shape.position = Vector2.ZERO; shape.set_meta("art_shape", true)
	shape.shape.size = sell_size
	Game.SELLBOX.rect = Rect2(sell_center - sell_size * 0.5, sell_size)
	Game.SELLBOX.bottomPos.global_position = sell_center
	Game.SELLBOX.goldPos.global_position = sell_center
	Game.PLAYER.goldPos.global_position = Vector2(1609, 54)
	Game.shopSceneNode.get_node("GoldPos").global_position = Vector2(1609, 54)

func _layout_combat():
	for index in 2:
		var actor = Game.PLAYER if index == 0 else Game.OPPONENT
		if not is_instance_valid(actor): continue
		var target := routed_combat.grid_origin(index) if is_instance_valid(routed_combat) else Vector2(32 if index == 0 else 1305, 86)
		_move_inventory(actor.INVENTORY, target)
		actor.INVENTORY.scale = Vector2.ONE*grid_scale()
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

func grid_scale()->float:
	# Presentation units only. Saved 9x7 coordinates and 80-unit native masks
	# remain intact; release content displays each cell at 64 reference pixels.
	return 0.8 if Expedition.db.release_run(Expedition.flow.run) else 1.0

func _update_board(inventory, build: Dictionary):
	inventory.tilemap.visible = false
	var board = inventory.get_node_or_null("SuppliedGrid")
	if board == null and texture("cell") != null:
		board = Node2D.new(); board.set_script(board_script); board.name = "SuppliedGrid"; inventory.add_child(board)
	if board != null:
		board.cell_texture = texture("cell")
		board.empty_texture = texture("cell_empty")
		board.guide_texture = texture("board_guide") if Expedition.db.release_run(Expedition.flow.run) else null
		board.configure(build)
		board.z_index = _board_depth(inventory)
	if inventory.character == Game.PLAYER and inventory.get_node_or_null("SuppliedHover") == null:
		var hover = Node2D.new(); hover.name = "SuppliedHover"; hover.set_script(preload("res://PvE/Art/Hover.gd")); hover.z_index = 100; inventory.add_child(hover)

func _board_depth(inventory) -> int:
	# 层级自下而上：背包 → 9x7 网格与方块 → 物品。
	# 物品放回后由 Item.resetZ() 复位成 z_index=1、背包是 -2，因此这一层夹在两者之间，
	# 物品复位也不会再被方块盖住。
	var lowest_item := 0
	var highest_bag := 0
	var has_item := false
	var has_bag := false
	for item in inventory.getItems():
		if not is_instance_valid(item): continue
		var depth: int = Util.getGlobalZ(item)
		if item.isBag():
			highest_bag = maxi(highest_bag, depth) if has_bag else depth
			has_bag = true
		else:
			lowest_item = mini(lowest_item, depth) if has_item else depth
			has_item = true
	var target := 0
	if has_item: target = lowest_item - 1
	if has_bag: target = maxi(target, highest_bag + 1)
	return target - Util.getGlobalZ(inventory)

func _refresh_data():
	if Expedition.flow.run.is_empty(): return
	if is_instance_valid(routed_shop):
		routed_shop.refresh_from_host()
		return
	if is_instance_valid(routed_combat):
		_refresh_routed_combat()
		return
	for label in ui.find_children("*", "Label", true, false):
		var key = str(label.get_meta("art_text", ""))
		if not key.is_empty(): label.text = local(key)
	_update_hud(hero_hud, Game.PLAYER, Expedition.t(str(Expedition.db.get_row("characters", str(Expedition.flow.run.character_id)).get("name_key", ""))))
	if view == "combat":
		_update_hud(enemy_hud, Game.OPPONENT, Expedition.enemy_name(Expedition.flow.run.current_node))
		var progress = ui.get_node_or_null("ArtTimeline")
		if progress != null: progress.value = 100.0 * Expedition.flow.playback_time / maxf(0.01, float(Expedition.flow.combat_result.get("elapsed_time", 1.0)))
		ui.get_node("CombatSpeed/SpeedCaption").text = "×"+str(int(Expedition.flow.combat_speed))
		ui.get_node("CombatPausePlay").texture_normal = texture("play" if Expedition.flow.combat_paused else "pause")
	elif view == "shop":
		var chinese = TranslationServer.get_locale().begins_with("zh")
		ui.get_node("GoldValue").text = ("%d" if chinese else "%d") % int(Expedition.flow.run.gold)
		ui.get_node("RefreshCost").text = ("%d" if chinese else "%d") % Game.shopSceneNode.getRerollCost()
		ui.get_node("ArtStartBattle/StageNumber").text = ("关卡 %d-%d" if chinese else "Stage %d-%d") % [int(Expedition.flow.run.act),int(Expedition.flow.run.step)]
		ui.get_node("ArtStartBattle/StageCaption").text = ("前进" if chinese else "Continue") if Expedition.flow.run.current_node.get("type", "") == "merchant" else ("开战" if chinese else "Battle")
		if bool(Expedition.flow.run.get("route_pending", false)):ui.get_node("ArtStartBattle/StageCaption").text="选择路线" if chinese else "Choose route"
		for index in prices.size():
			var data = Expedition.bridge.slot_data(index); var shown = not data.is_empty() and not bool(data.get("sold", false))
			var item = Game.shopSceneNode.slots[index].item
			shown = shown and is_instance_valid(item) and str(item.get_meta("pve_definition_id","")) == str(data.get("definition_id",""))
			var sale = shown and bool(data.get("discounted", false))
			prices[index].tag.visible = shown; prices[index].sale.visible = sale; prices[index].sale_label.visible = sale
			prices[index].label.text = str(int(data.get("price", 0)))
			var discount=float(data.get("discount_pct",0.0))
			prices[index].sale_label.text = str(snappedf((1.0-discount)*10.0,0.1))+"\n折" if chinese else "-%d%%"%roundi(discount*100.0)
			prices[index].lock.text = ("已锁定" if chinese else "Locked") if bool(data.get("locked", false)) else ""
			prices[index].tag.disabled = Expedition.syncing or is_instance_valid(Game.draggedItem)
		var start = ui.get_node_or_null("ArtStartBattle")
		if start != null: start.disabled = Expedition.syncing or Expedition.combat_loading or curtain.busy or is_instance_valid(Game.draggedItem)
		var refresh = ui.get_node_or_null("Action_refresh")
		if refresh != null: refresh.disabled = Expedition.syncing or Expedition.render_pending or curtain.busy or is_instance_valid(Game.draggedItem)
		for action in touch_buttons:action.visible=is_instance_valid(Game.draggedItem) and not Expedition.panel.visible
	for label in ui.find_children("*", "Label", true, false):
		if label.has_meta("art_font_size"): _fit_label(label)

func _refresh_routed_combat() -> void:
	if not is_instance_valid(Game.PLAYER) or not is_instance_valid(Game.OPPONENT):
		return
	var flow = Expedition.flow
	var role = Expedition.db.get_row("characters", str(flow.run.character_id))
	Expedition.combat_vm.set_screen_state({
		"locale": TranslationServer.get_locale(),
		"ui_scale": float(Expedition.preferences.values.ui_scale),
		"playback_time": flow.playback_time,
		"elapsed_time": float(flow.combat_result.get("elapsed_time", 1.0)),
		"paused": flow.combat_paused,
		"speed": flow.combat_speed,
		"player": _combat_actor_state(Game.PLAYER, Expedition.t(str(role.get("name_key", "")))),
		"enemy": _combat_actor_state(Game.OPPONENT, Expedition.enemy_name(flow.run.current_node)),
	})

func _combat_actor_state(actor, caption: String) -> Dictionary:
	return {
		"name": caption,
		"health": actor.getCurrentHealth(),
		"max_health": actor.getMaxHealth(),
		"stamina": actor.curStamina,
		"max_stamina": actor.maxStamina,
		"statuses": actor.get_meta("pve_status_timeline", {}),
		"armor": actor.get_meta("pve_armor_timeline", 0),
	}

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
	STATUS_BADGES.update(self,hud,actor)

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

func _owns_reveal(ticket: int, epoch_value: int) -> bool:
	return not AssetStream.stopping and epoch_value == Expedition.view_epoch and is_instance_valid(curtain) and ticket == curtain.generation and curtain.busy

func _reveal_target_ready(kind: String) -> bool:
	var right_state = Game.state == Game.State.Shop if kind == "shop" else Game.state == Game.State.Combat if kind == "combat" else Game.state == Game.State.Title
	if kind == "combat" and is_instance_valid(routed_combat) and not routed_combat.is_visible_in_tree():
		return false
	return right_state and not Game.sceneAnimation.is_playing() and not Expedition.syncing and not Expedition.combat_loading and ready_kind == kind

func reveal_ready(kind: String, ticket: int, epoch_value: int):
	while _owns_reveal(ticket, epoch_value):
		if not _reveal_target_ready(kind):
			await get_tree().process_frame
			continue
		await get_tree().process_frame
		# Both ownership and readiness may change during the final presentation frame.
		if not _owns_reveal(ticket, epoch_value): return
		if not _reveal_target_ready(kind): continue
		await curtain.reveal(ticket)
		return


func _button_feedback(node: Control, value: Color):
	if not is_instance_valid(node) or (node is BaseButton and node.disabled): return
	var tween = node.create_tween().set_ignore_time_scale(true)
	tween.tween_property(node,"modulate",value,0.10)
