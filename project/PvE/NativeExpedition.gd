extends Node

# The recovered game remains the scene, animation, input and asset foundation.
# Rules and native presentation remain separate from the flat touch UI.
# This distribution has one authoritative ruleset. Scene entry APIs remain stable.
const enabled: bool = true
var flow
var db
var bridge
var bindings
var initialized: bool = false
var active: bool:
	get: return flow != null and not flow.run.is_empty() and flow.screen_state != "MAIN_MENU"
var syncing: bool = false
var view_epoch: int = 0
var popup_epoch: int = 0
var combat_loading: bool = false
var entering_shop: bool = false
var scenery = preload("res://Runtime/Loading/SceneResidency.gd").new()
var residency_clock: float = 0.0
var render_pending: bool = false
var render_queued: bool = false
var native_battle_ready: bool = false
var native_phase: int = 1
var last_event: int = 0
var cooldown_events: Dictionary = {}
var overlay: CanvasLayer
var panel: Panel
var popup_content: VBoxContainer
var toolbar: HBoxContainer
var status: Label
var toast: Label
var tutorial_hint: Label
var toast_time: float = 0.0
var current_page: String = ""
var setup_loadout: int = 0
var setup_difficulty: String = "tutorial"
var ui_font: Font
var was_dragging: bool = false
var modal_shield: ColorRect
var popup_scroll: ScrollContainer
var last_flow_state: String = ""
var result_presented: bool = false
var preferences
var detail_views
var back_action: Callable
var ui_theme: Theme
var last_audio_tick: float = -1.0
var toolbar_locale: String = ""
var restoring_result: bool = false
var transitions
var art
var menus
var menu_header: HBoxContainer
var menu_nav: HBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	db = load("res://PvE/Rules/content/ContentDB.gd").new()
	var path = "user://pve"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-save-directory="): path = argument.trim_prefix("--qa-save-directory=")
	flow = load("res://PvE/Rules/app/GameFlow.gd").new(db, load("res://PvE/Rules/persistence/SaveService.gd").new(path))
	flow.changed.connect(request_render)
	flow.notification.connect(notice)
	flow.tutorial_changed.connect(update_tutorial_hint)
	flow.changed.connect(update_tutorial_hint)
	call_deferred("initialize_native")

func initialize_native():
	while not is_instance_valid(Game.PLAYER) or Game.PLAYER.INVENTORY == null:
		await get_tree().process_frame
	while Settings.initializing:
		await get_tree().process_frame
	bindings = load("res://PvE/NativeAssetBindings.gd").new(db)
	bridge = load("res://PvE/NativeBuildBridge.gd").new(self)
	ui_font = load("res://Assets/Fonts/Localized/NotoSansSC-Regular_.otf")
	preferences = load("res://PvE/NativePreferences.gd").new(self)
	detail_views = load("res://PvE/NativeDetailViews.gd").new(self)
	transitions = load("res://PvE/NativeTransitions.gd").new(self)
	menus = preload("res://PvE/UI/TouchMenus.gd").new(self)
	overlay = CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)
	ui_theme = Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 24
	preload("res://PvE/Art/UISkin.gd").apply(ui_theme)
	toolbar = HBoxContainer.new()
	toolbar.theme = ui_theme
	toolbar.position = Vector2(32, 1008)
	toolbar.size = Vector2(1856, 64)
	toolbar.add_theme_constant_override("separation", 4)
	overlay.add_child(toolbar)
	status = label("", overlay, 22)
	status.theme = ui_theme
	status.position = Vector2(530, 12)
	status.size = Vector2(860, 58)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	white_text(status)
	tutorial_hint = label("", overlay, 18)
	tutorial_hint.position = Vector2(430, 962)
	tutorial_hint.size = Vector2(1250, 44)
	tutorial_hint.add_theme_constant_override("line_spacing", -5)
	tutorial_hint.max_lines_visible = 2
	white_text(tutorial_hint)
	modal_shield = ColorRect.new()
	modal_shield.color = Color(0.05, 0.025, 0.01, 0.48)
	modal_shield.size = Vector2(1920, 1080)
	modal_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_shield.hide()
	overlay.add_child(modal_shield)
	panel = Panel.new()
	panel.theme = ui_theme
	panel.add_theme_stylebox_override("panel",ui_theme.get_stylebox("panel","PanelContainer"))
	panel.position = Vector2(110, 20)
	panel.size = Vector2(1700, 1040)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	var frame = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	panel.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left=60;frame.offset_right=-60;frame.offset_top=48;frame.offset_bottom=-44
	menu_header = HBoxContainer.new(); frame.add_child(menu_header)
	menu_nav = HBoxContainer.new(); menu_nav.alignment = BoxContainer.ALIGNMENT_CENTER; menu_nav.add_theme_constant_override("separation", 18); frame.add_child(menu_nav)
	popup_scroll = ScrollContainer.new()
	popup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	popup_scroll.scroll_deadzone=100000
	popup_scroll.follow_focus = false
	frame.add_child(popup_scroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 16)
	popup_scroll.add_child(popup_content)
	menus.shell.pager=preload("res://PvE/UI/PageTurner.gd").new(self,menus.shell)
	menus.shell.pager.attach(frame)
	toast = label("", overlay, 18)
	toast.position = Vector2(430, 962)
	toast.size = Vector2(1250, 44)
	toast.max_lines_visible = 2
	toast.add_theme_constant_override("line_spacing", -5)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	white_text(toast)
	panel.hide()
	toolbar.hide()
	preferences.apply()
	art = load("res://PvE/Art/Presentation.gd").new()
	add_child(art)
	await menus.prepare_icons()
	initialized = true
	Game.randomCharacter = false
	if Game.curClass not in [Game.Classes_Full.Berserker, Game.Classes_Full.Reaper]: Game.instanceCharacter(Game.Classes_Full.Berserker)
	request_render()

func white_text(control: Label):
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_color_override("font_color", Color.WHITE)
	control.add_theme_color_override("font_shadow_color", Color("281609"))
	control.add_theme_constant_override("shadow_offset_x", 2)
	control.add_theme_constant_override("shadow_offset_y", 2)

func t(key: String, params: Dictionary = {}) -> String:
	return db.text(key, "zh_CN" if TranslationServer.get_locale().begins_with("zh") else "en").format(params)

func label(text: String, parent: Node = null, size: int = 24) -> Label:
	if parent == null: parent = popup_content
	var node = Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", roundi(size * (float(preferences.values.get("ui_scale", 1.0)) if preferences != null else 1.0)))
	if ui_font != null: node.add_theme_font_override("font", ui_font)
	parent.add_child(node)
	return node

func paper_background(control: Control):
	# Use the original paper's nine-slice theme; stretching a whole popup texture
	# into a 55px row previously crushed the frame and clipped text at its border.
	control.theme = ui_theme
	if control is OptionButton: control.clip_text = true

func button(text: String, action: Callable, parent: Node = null, disabled: bool = false) -> Button:
	if parent == null: parent = popup_content
	var node = Button.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(0, 60)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent == popup_content:
		var caption_width = ui_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,ui_theme.default_font_size).x
		node.custom_minimum_size = Vector2(clampf(caption_width+110,300,900),72)
		node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.focus_mode = Control.FOCUS_ALL
	node.disabled = disabled
	node.set_meta("pve_initial_disabled", disabled)
	node.pressed.connect(func():
		Sound.playSound(load("res://Assets/Sound/Thud5.wav"), -15)
		action.call())
	parent.add_child(node)
	return node

func clear_popup(title: String):
	popup_epoch += 1
	if bridge != null: bridge.footprint_layout.pictures.clear()
	AssetStream.release("popup")
	if bindings != null: bindings.texture_cache.clear()
	# One modal owner and one input source: another original menu cannot steal
	# or release our lock. The shield also consumes clicks outside the paper.
	if preferences != null: preferences.cancel_capture()
	Game.closeAllMenus()
	Game.unhoverAndHideTooltips()
	for child in popup_content.get_children():
		popup_content.remove_child(child)
		child.queue_free()
	popup_scroll.scroll_vertical = 0
	modal_shield.show()
	panel.show()
	back_action = view_return
	InputBlocker.activate(InputBlocker.Source.Expedition, false)
	menus.shell.chrome(title)
	transitions.reveal_popup()
	call_deferred("focus_popup")

func focus_popup():
	await get_tree().process_frame
	if not panel.visible: return
	var controls = panel.find_children("*", "Control", true, false)
	var focusable: Array[Control] = []
	for control in controls:
		if control is OptionButton: control.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled): focusable.append(control)
	if focusable.is_empty(): return
	for index in focusable.size():
		focusable[index].focus_next = focusable[index].get_path_to(focusable[(index + 1) % focusable.size()])
		focusable[index].focus_previous = focusable[index].get_path_to(focusable[posmod(index - 1, focusable.size())])
	focusable[0].grab_focus()
	await get_tree().process_frame
	if panel.visible: popup_scroll.scroll_vertical = 0

func close_popup():
	if preferences != null: preferences.cancel_capture()
	if panel == null: return
	transitions.close_popup()
	panel.hide()
	modal_shield.hide()
	InputBlocker.deactivate(InputBlocker.Source.Expedition, false)
	current_page = ""
	back_action = Callable()
	popup_epoch += 1
	for child in popup_content.get_children():
		popup_content.remove_child(child)
		child.queue_free()
	if detail_views != null: detail_views.results = null
	if bridge != null: bridge.footprint_layout.pictures.clear()
	if bindings != null: bindings.texture_cache.clear()
	AssetStream.release("popup")
	AssetStream.release_metadata()

func view_return():
	close_popup()
	render_state(true)

func show_settings():
	preferences.show_page()

func notice(key: String):
	if key == "tutorial_action_required": show_ui_guide();return
	if toast == null: return
	toast.text = t("ui.confirm_overwrite" if key == "confirm_overwrite_run" else key)
	toast_time = 5.0
	if toast.text == key: toast.text = t("ui.generic_error")

func perform(result: Dictionary):
	if not result.get("ok", false): notice(str(result.get("error", "ui.generic_error")))
	else: Sound.playSound(load("res://Assets/Sound/Thud5.wav"), -12)

func request_render():
	render_pending = true
	if render_queued: return
	render_queued = true
	call_deferred("_drain_render")

func _drain_render():
	render_queued = false
	if render_pending: render_state()

func begin_setup(mode: int = 0):
	if initialized: menus.runs.setup(mode)

func create_run(role: String, loadout: String, difficulty: String, seed: int, confirmed: bool = false):
	var result = flow.new_run(role,loadout,difficulty,seed,confirmed)
	if not result.ok and result.error == "confirm_overwrite_run": menus.runs.confirm_new(role,loadout,difficulty,seed)
	else: perform(result)

func continue_run(_mode: int = 0):
	if not initialized: return
	var result = flow.continue_run()
	perform(result)
	if result.ok and flow.screen_state in ["COMBAT_RUNNING", "COMBAT_RESULT"]:
		restoring_result = flow.screen_state == "COMBAT_RESULT"
		result_presented = false
		native_battle_ready = false
		await enter_shop()
		Game.sceneAnimation.advance(100)
		Game.sceneAnimation.play("ShopToCombat")
		Game.sceneAnimation.advance(0.017)

func save_run() -> bool:
	return flow != null and flow._save()

func return_to_title():
	if not initialized: return
	var title_ticket = await art.curtain.cover("return_to_title")
	view_epoch += 1
	bridge.cancel_views()
	scenery.unload("shop")
	scenery.unload("combat")
	InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
	if not flow.go_main_menu().ok:
		notice("save_write_failed")
		art.curtain.reveal(title_ticket)
		return
	restoring_result = false
	Game.pve_prepare_title()
	set_playback(1.0, false)
	native_battle_ready = false
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	close_popup()
	Game.runStarted = false
	Game.sceneAnimation.play("StartOnTitle")
	Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	Game.PLAYER.shopToTitle()
	Game.PLAYER.finishAnimations()
	bridge.unload_run_views()
	Game.titleScreen.checkSavedRunState()
	Game.emit_signal("returned_to_title")
	request_render()
	art.reveal_ready("title",title_ticket,view_epoch)

func start_battle() -> bool:
	if not initialized or syncing or flow.screen_state != "SHOP_PREPARE": return false
	if is_instance_valid(Game.draggedItem): notice("native.drop_first"); return false
	var result = flow.complete_node() if flow.run.current_node.type == "merchant" else flow.start_combat()
	perform(result)
	if not result.ok: return false
	native_battle_ready = false
	result_presented = false
	last_event = 0
	native_phase = 1
	return flow.screen_state == "COMBAT_RUNNING"

func finish_switch_to_combat():
	if flow.screen_state not in ["COMBAT_RUNNING", "COMBAT_RESULT"] or combat_loading: return
	combat_loading = true
	var transition_ticket = await art.curtain.cover("enter_combat")
	var epoch = view_epoch
	if not await scenery.ensure_view("combat") or epoch != view_epoch:
		combat_loading = false
		art.curtain.reveal(transition_ticket)
		return
	cooldown_events.clear()
	for event in flow.combat_result.get("full_events", []):
		if event.type == "ITEM_ACTIVATED":
			var key = str(event.source_side) + ":" + str(event.source)
			if not cooldown_events.has(key): cooldown_events[key] = []
			cooldown_events[key].append(float(event.time))
	Game.closeAllMenus()
	Game.setInventoryEditMode(Game.InventoryEditMode.Default)
	Game.canCancelSwitch = false
	Game.canSwitchToCombat = false
	Game.freeOpponent()
	Game.OPPONENT = Game.opponentScene.instantiate()
	Game.OPPONENT.playerId = Character.ID.OPPONENT
	Game.OPPONENT.position = Vector2(1920 - Game.playerCombatPos, 880)
	Game.opponentNode.add_child(Game.OPPONENT)
	var node = flow.run.current_node
	var enemy = db.get_row("enemy_builds", str(node.get("enemy_id", "")))
	var character = Game.Classes_Full.Reaper if str(enemy.get("archetype_id", "")) in ["venom_brewer", "ember_runner"] else Game.Classes_Full.Berserker
	await AssetStream.prepare_actor(character, false, "actor-enemy", false)
	if epoch != view_epoch or not is_instance_valid(Game.OPPONENT): combat_loading = false; return
	Game.OPPONENT.setClass(character, false)
	Game.OPPONENT.setCharacterName(enemy_name(node))
	Game.PLAYER.setOpponent(Game.OPPONENT)
	Game.OPPONENT.setOpponent(Game.PLAYER)
	await bridge.render_build(Game.OPPONENT, enemy_build(node, 1), Item.Owner.Opponent)
	if epoch != view_epoch: combat_loading = false; return
	combat_loading = false
	Game.fightEnded = false
	Game.emit_signal("shop_closed")
	Game.emit_signal("switching_to_combat")
	Game.combatTimer.initialize()
	Game.PLAYER.shopToCombat()
	Game.pve_prepare_combat()
	Game.PLAYER.set_physics_process(false)
	Game.OPPONENT.set_physics_process(false)
	Sound.playBGM(Sound.battleBGM, 2)
	Sound.playSound(load("res://Assets/Sound/Drumroll.ogg"))
	native_battle_ready = not restoring_result
	_apply_timeline()
	art.reveal_ready("combat",transition_ticket,epoch)

func enter_shop():
	if not initialized or entering_shop: return
	entering_shop = true
	var transition_ticket = await art.curtain.cover("enter_shop")
	var epoch = view_epoch
	InputBlocker.activate(InputBlocker.Source.Streaming, false)
	var ready = await scenery.ensure_view("shop")
	entering_shop = false
	InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
	if not ready or epoch != view_epoch:
		art.curtain.reveal(transition_ticket)
		return
	Game.pve_prepare_shop()
	AssetStream.release("build-enemy")
	AssetStream.release("actor-enemy")
	var role = Game.Classes_Full.Reaper if flow.run.character_id == "alchemist" else Game.Classes_Full.Berserker
	if Game.curClass != role:
		if not await AssetStream.prepare_actor(role, Game.getEffectiveChibiMode(), "actor-player", true): return
		if epoch != view_epoch: return
		Game.instanceCharacter(role)
	Game.runStarted = true
	Game.curRound = (int(flow.run.act) - 1) * 5 + int(flow.run.step)
	Game.tries = 1
	Game.wins = flow.run.logs.filter(func(record): return int(record.winner) == 0).size()
	Game.losses = 0
	if Game.state == Game.State.Title:
		Game.titleToShop()
	else:
		Game.PLAYER.combatToShop()
		Game.sceneAnimation.play("CombatToShop")
		Game.sceneAnimation.advance(100)
	Game.state = Game.State.Shop
	Game.canSwitchToCombat = true
	await start_round()
	call_deferred("restore_native_stats")
	close_popup()
	art.reveal_ready("shop",transition_ticket,epoch)

func restore_native_stats():
	if not initialized or flow.run.is_empty() or flow.screen_state != "SHOP_PREPARE": return
	Game.PLAYER.setMaxHealth(float(flow.run.max_health))
	Game.PLAYER.setCurrentHealth(float(flow.run.health))
	Game.PLAYER.setMaxStamina(float(db.get_row("characters", flow.run.character_id).get("stamina_max", 10)))
	Game.PLAYER.set_physics_process(false)

func start_round():
	if not initialized or flow.run.is_empty() or syncing: return
	syncing = true
	InputBlocker.activate(InputBlocker.Source.Streaming, false)
	Game.setGold(int(flow.run.gold))
	Game.PLAYER.setMaxHealth(float(flow.run.max_health))
	Game.PLAYER.setCurrentHealth(float(flow.run.health))
	Game.PLAYER.setMaxStamina(float(db.get_row("characters", flow.run.character_id).get("stamina_max", 10)))
	Game.PLAYER.set_physics_process(false)
	var epoch = view_epoch
	Game.canSwitchToCombat = false
	await bridge.render_build(Game.PLAYER, flow.run.build.duplicate(true), Item.Owner.PlayerInventory)
	if epoch == view_epoch: await bridge.render_shop()
	syncing = false
	InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
	Game.canSwitchToCombat = flow.screen_state == "SHOP_PREPARE" and epoch == view_epoch
	AssetStream.release_metadata()
	if render_pending:
		render_pending = false
		request_render()

func enemy_name(node: Dictionary) -> String:
	var boss = str(node.get("boss_id", ""))
	var row = db.get_row("bosses", boss) if not boss.is_empty() else db.get_row("enemy_builds", str(node.get("enemy_id", "")))
	return t(str(row.get("name_key", "ui.no_enemy")))

func show_current_enemy():
	if not flow.run.is_empty() and not flow.run.current_node.is_empty(): show_enemy(flow.run.current_node)

func enemy_build(node: Dictionary, phase: int = 1) -> Dictionary:
	var result = {"width": 9, "height": 7, "bags": [], "items": [], "storage": [], "storage_capacity": 2}
	var boss = str(node.get("boss_id", ""))
	var id = boss if not boss.is_empty() else str(node.get("enemy_id", ""))
	if not boss.is_empty(): result.bags = db.boss_bags(boss)
	else:
		for row in db.rows("enemy_build_bags"):
			if row.enemy_build_id == id: result.bags.append({"uid": row.instance_id, "definition_id": row.bag_id, "x": int(row.origin_x), "y": int(row.origin_y), "rotation": int(row.rotation)})
	for row in db.rows("boss_build_items" if not boss.is_empty() else "enemy_build_items"):
		if str(row.get("boss_id" if not boss.is_empty() else "enemy_build_id", "")) != id: continue
		if not boss.is_empty() and int(row.phase) > phase: continue
		result.items.append({"uid": row.instance_id, "definition_id": row.item_id, "x": int(row.origin_x), "y": int(row.origin_y), "rotation": int(row.rotation)})
	return result

func _process(delta: float):
	if not initialized or AssetStream.stopping: return
	menus.shell.pager.refresh()
	# A drag or streamed rebuild may outlive the first deferred callback. Dirty
	# state is retained independently of whether a callback is already queued.
	if render_pending and not render_queued and not syncing and not restoring_result and not is_instance_valid(Game.draggedItem): request_render()
	residency_clock += delta
	if residency_clock >= 0.5:
		residency_clock = 0.0
		if not syncing and not entering_shop and not combat_loading: scenery.trim_inactive()
	if restoring_result and Game.state == Game.State.Combat and not Game.sceneAnimation.is_playing():
		restoring_result = false
		flow.playback_time = float(flow.combat_result.elapsed_time)
		native_phase = int(flow.combat_result.get("boss_phases", [1, 1])[1])
		if native_phase > 1: bridge.render_build(Game.OPPONENT, enemy_build(flow.run.current_node, native_phase), Item.Owner.Opponent)
		_apply_timeline()
		show_battle_result()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: toast.text = ""
	tutorial_hint.visible = active and toast_time <= 0
	if not flow.run.is_empty() and flow.screen_state != "MAIN_MENU": flow.run.play_seconds = float(flow.run.get("play_seconds", 0)) + delta
	if flow.screen_state == "COMBAT_RUNNING" and native_battle_ready and Game.state == Game.State.Combat and not art.curtain.busy:
		flow.advance_combat(delta)
		_apply_timeline()
		_play_events()
		_update_native_cooldowns()
	if active:
		var displayed_health = Game.PLAYER.getCurrentHealth() if flow.screen_state == "COMBAT_RUNNING" else float(flow.run.health)
		status.text = t("ui.run_header", {"act": int(flow.run.act), "step": int(flow.run.step), "hp": int(ceil(displayed_health)), "max_hp": int(ceil(flow.run.max_health)), "gold": int(flow.run.gold)})

func _apply_timeline():
	var timeline = flow.combat_result.get("timeline", [])
	if timeline.is_empty() or not is_instance_valid(Game.OPPONENT): return
	var state = timeline[0]
	for candidate in timeline:
		if float(candidate.time) > flow.playback_time: break
		state = candidate
	for side in range(2):
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		var view_state: Dictionary = state.sides[side]
		actor.maxHealth = float(view_state.max_health)
		actor.setCurrentHealth(float(view_state.health))
		actor.maxStamina = float(view_state.stamina_max)
		actor.setCurrentStamina(float(view_state.stamina))
		actor.setStacks(Game.EventType.Block, int(round(float(view_state.armor))))
		for type in {"poison": Game.EventType.Poison, "regeneration": Game.EventType.Regeneration, "burn": Game.EventType.Heat, "slow": Game.EventType.Cold, "haste": Game.EventType.Lucky, "lifesteal": Game.EventType.Vampirism, "vulnerable": Game.EventType.Blind, "fortified": Game.EventType.Empower}:
			var value = view_state.statuses.get(type, 0)
			var native_type = {"poison": Game.EventType.Poison, "regeneration": Game.EventType.Regeneration, "burn": Game.EventType.Heat, "slow": Game.EventType.Cold, "haste": Game.EventType.Lucky, "lifesteal": Game.EventType.Vampirism, "vulnerable": Game.EventType.Blind, "fortified": Game.EventType.Empower}[type]
			actor.setStacks(native_type, int(value.get("stacks", 0) if value is Dictionary else value))
			if actor.buffs.has(native_type) and is_instance_valid(actor.buffs[native_type].counter):
				actor.buffs[native_type].counter.pve_set_timeline_status(value if value is Dictionary else {})
	Game.combatTimer.combatTime = flow.playback_time
	Game.combatTimer.updateTimer()

func _play_events():
	var events: Array = flow.combat_result.get("full_events", [])
	while last_event < events.size() and float(events[last_event].time) <= flow.playback_time:
		var event: Dictionary = events[last_event]
		last_event += 1
		var side = int(event.get("source_side", 0))
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		if event.type == "BOSS_PHASE":
			native_phase = int(event.get("value", 2))
			bridge.render_build(Game.OPPONENT, enemy_build(flow.run.current_node, native_phase), Item.Owner.Opponent)
			Sound.playSound(load("res://Assets/Sound/LevelUp1.ogg"))
		elif event.type == "ITEM_ACTIVATED":
			for item in actor.INVENTORY.getItems():
				if str(item.get_meta("pve_uid", "")) == str(event.get("source_uid", event.get("source", ""))):
					if not bool(preferences.values.reduce_effects): item.playActivationAnimation()
					if item.isWeapon() and not bool(preferences.values.reduce_motion): actor.playAttackAnimation()
					break
		elif event.type in ["PHYSICAL_DAMAGE", "TRUE_DAMAGE", "STATUS_DAMAGE"]:
			var target = Game.PLAYER if int(event.target_side) == 0 else Game.OPPONENT
			if target.damageAnimation.has_animation("Hit") and not bool(preferences.values.reduce_flash): target.damageAnimation.play("Hit")
			if not bool(preferences.values.reduce_effects): Util.spawnNumberLabel(Game.EventType.CriticalDamage if bool(event.get("critical", false)) else Game.EventType.DealDamage, target.randDmgNumberPos(), target.randDmgNumberDir(), int(ceil(float(event.value))))
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_audio_tick >= 0.08:
				Sound.playSound(load("res://Assets/Sound/Impact.ogg"), -15)
				last_audio_tick = now

func _update_native_cooldowns():
	for side in range(2):
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		if not is_instance_valid(actor): continue
		for item in actor.INVENTORY.getItems():
			if item.isBag(): continue
			var uid = str(item.get_meta("pve_uid", ""))
			var previous = 0.0
			var next = -1.0
			for time in cooldown_events.get(str(side) + ":" + uid, []):
				if float(time) <= flow.playback_time: previous = float(time)
				else: next = float(time); break
			item.showCooldown(clampf((next - flow.playback_time) / maxf(0.05, next - previous), 0.0, 1.0) if next >= 0 else 0.0)

func set_playback(speed: float, paused: bool):
	flow.combat_speed = speed
	flow.combat_paused = paused
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	for node in [Game.playerNode, Game.opponentNode]: node.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func advance_result(): perform(flow.confirm_combat())

func render_state(force: bool = false):
	if not initialized or syncing or restoring_result or is_instance_valid(Game.draggedItem):
		render_pending = true
		return
	render_pending = false
	update_tutorial_hint()
	var state = str(flow.screen_state)
	var transitioned = state != last_flow_state
	last_flow_state = state
	toolbar.visible = active
	status.visible = active
	if state == "MAIN_MENU":
		if transitioned or force: close_popup()
		return
	if state == "SHOP_PREPARE":
		if Game.state != Game.State.Shop: enter_shop()
		else: start_round()
		if not flow.run.pending_rewards.is_empty(): show_pending()
		elif current_page == "CRAFTING" and not force and not transitioned: show_crafting()
		elif transitioned or force or current_page == "PENDING": close_popup()
		return
	if state == "COMBAT_RUNNING":
		if transitioned or force: close_popup()
		return
	if not transitioned and not force and current_page in ["INTEL", "CODEX", "RECORDS", "RECIPE_CODEX", "COMBAT_LOG", "SETTINGS", "UI_GUIDE"]: return
	if state == "ROUTE_SELECT": show_routes()
	elif state in ["EVENT", "REST"]: show_event()
	elif state == "COMBAT_RESULT": show_battle_result()
	elif state == "REWARD_SELECT": show_rewards()
	elif state in ["ACT_RESULT", "RUN_RESULT"]: show_summary()

func update_tutorial_hint():
	if tutorial_hint != null: tutorial_hint.text = ""; tutorial_hint.hide()

func show_routes():
	Sound.playBGM(Sound.shopBGM)
	menus.journey.choose_route()

func show_enemy(node: Dictionary):
	if flow.screen_state == "SHOP_PREPARE": flow.mark_tutorial("view_enemy")
	menus.journey.show_page(node)

func show_battle_result():
	native_battle_ready = false
	Game.fightEnded = true
	Game.combatTimer.combatEnd()
	set_playback(1.0, false)
	var won = int(flow.combat_result.winner_side) == 0
	if not result_presented:
		result_presented = true
		if is_instance_valid(Game.OPPONENT):
			if won: Game.PLAYER.win(); Game.OPPONENT.lose()
			else: Game.PLAYER.lose(); Game.OPPONENT.win()
		Sound.playSound(load("res://Assets/Sound/Victory.mp3" if won else "res://Assets/Sound/Fanfare_loss.mp3"))
	flow.mark_tutorial("view_combat_result")
	menus.runs.result()

func show_rewards():
	menus.runs.rewards()

func pending_controls():
	menus.runs.pending_controls()

func show_pending():
	menus.runs.pending()

func skip_reward():
	menus.runs.rewards()

func source_name(data: Dictionary) -> String:
	var id = str(data.get("def_id", ""))
	for character in db.rows("characters"):
		if character.passive_id == id: return t(character.name_key) + " · " + bilingual("被动", "Passive")
	for table in ["items", "bags", "characters", "character_passives"]:
		var row = db.get_row(table, id)
		if not row.is_empty() and row.has("name_key"): return t(row.name_key)
	return id

func statistics_controls(result: Dictionary):
	for side in 2:
		label(t("native.player_side" if side == 0 else "native.enemy_side"), popup_content, 28)
		var entries: Array = result.get("item_stats_by_instance_id", {}).values().filter(func(data): return int(data.get("side", -1)) == side)
		entries.sort_custom(func(a, b): return float(a.get("damage", 0)) + float(a.get("healing", 0)) + float(a.get("armor", 0)) > float(b.get("damage", 0)) + float(b.get("healing", 0)) + float(b.get("armor", 0)))
		for data in entries:
			var name = _combat_source_label({"source": data.get("instance_id", ""), "source_side": side}, result)
			label("%s · %s %.1f · %s %.1f · %s %.1f · %s %d" % [name, t("native.damage"), float(data.get("damage", 0)), t("native.healing"), float(data.get("healing", 0)), t("native.armor"), float(data.get("armor", 0)), t("native.triggers"), int(data.get("triggers", 0))], popup_content, 22)
		var totals: Dictionary = result.get("status_totals", {}).get(str(side), result.get("status_totals", {}).get(side, {}))
		if not totals.is_empty():
			label(t("native.status_totals_heading"), popup_content, 24)
			for status in db.rows("statuses"):
				var id = str(status.id)
				if not totals.has(id): continue
				var values: Dictionary = totals[id]
				var line = label(t("native.status_totals_row", {"status": _combat_status_name(id), "applied": int(values.get("applied", 0)), "peak": int(values.get("peak", 0))}), popup_content, 22)
				line.set_meta("pve_status_total", {"side": side, "status_id": id, "applied": int(values.get("applied", 0)), "peak": int(values.get("peak", 0))})
		var starvation = result.get("stamina_starvation_time", {})
		if starvation is Dictionary: label(t("native.starvation", {"seconds": snappedf(float(starvation.get(str(side), starvation.get(side, 0))), 0.1)}))
		elif starvation is Array and side < starvation.size(): label(t("native.starvation", {"seconds": snappedf(float(starvation[side]), 0.1)}))

func _combat_status_name(id: String) -> String:
	if id.is_empty() or id == "negative": return t("native.negative_statuses")
	return detail_views.rules.term("statuses", id, TranslationServer.get_locale())

func _combat_definition_name(id: String) -> String:
	for character in db.rows("characters"):
		if str(character.passive_id) == id: return t(character.name_key) + " · " + t("native.passive")
	for table in ["items", "bags", "characters", "encounter_affixes", "statuses", "bosses"]:
		var row = db.get_row(table, id)
		if row.has("name_key"): return t(row.name_key)
	for boss in db.rows("bosses"):
		if str(boss.persistent_rule_id) == id: return t(boss.name_key)
	return ""

func _combat_source_label(event: Dictionary, result: Dictionary) -> String:
	var source = str(event.get("source", ""))
	var side = int(event.get("source_side", 0))
	if source == "__fatigue__": return t("native.fatigue_source")
	if source == "__character__": return t("native.character_source")
	for data in result.get("item_stats_by_instance_id", {}).values():
		if int(data.get("side", -1)) == side and str(data.get("instance_id", "")) == source:
			var name = _combat_definition_name(str(data.get("def_id", "")))
			if not name.is_empty(): return name
	if source.begins_with("__bag__:"):
		var uid = source.trim_prefix("__bag__:").rsplit(":", false, 1)[0]
		var checkpoint = flow.run.get("combat_checkpoint", {})
		for bag in checkpoint.get("player" if side == 0 else "enemy", {}).get("bags", []):
			if str(bag.get("instance_id", bag.get("uid", ""))) == uid:
				var name = _combat_definition_name(str(bag.get("def_id", bag.get("definition_id", ""))))
				if not name.is_empty(): return name
		return t("native.bag_effect")
	if source.begins_with("__affix__:") or source.begins_with("__passive__:"):
		var name = _combat_definition_name(source.get_slice(":", 1))
		if not name.is_empty(): return name
	if source.begins_with("__boss"):
		var node = result.get("node", flow.run.get("current_node", {}))
		var name = _combat_definition_name(str(node.get("boss_id", "")))
		return name if not name.is_empty() else t("native.boss_rule")
	var definition = _combat_definition_name(source)
	return definition if not definition.is_empty() else t("native.system_source")

func _combat_number(value) -> String:
	return str(snappedf(float(value), 0.001)) if value is int or value is float else ""

func combat_event_text(event: Dictionary, result: Dictionary = {}) -> String:
	if result.is_empty(): result = _combat_log_result()
	var kind = str(event.get("type", ""))
	var translated = t("native.event_" + kind)
	if translated.begins_with("native.event_"): translated = t("native.battle_log")
	var source_side = int(event.get("source_side", 0))
	var target_side = int(event.get("target_side", source_side))
	var source = t("native.player_side" if source_side == 0 else "native.enemy_side") + " · " + _combat_source_label(event, result)
	var target = t("native.both_sides") if target_side < 0 else t("native.player_side" if target_side == 0 else "native.enemy_side")
	if not str(event.get("target_instance_id", "")).is_empty(): target += " · " + _combat_source_label({"source": event.target_instance_id, "source_side": target_side}, result)
	var details: Array[String] = []
	if event.has("status_id"): details.append(_combat_status_name(str(event.status_id)))
	if event.has("stat"):
		var stat = str(event.stat)
		details.append(t("native.stat_" + stat) if t("native.stat_" + stat) != "native.stat_" + stat else t("native.modifier"))
		if stat in ["cooldown_pct", "crit_chance", "status_power"]: details.append(_combat_number(float(event.get("value", 0)) * 100.0) + "%")
		else: details.append(_combat_number(event.get("value", 0)))
	elif event.has("value"): details.append(_combat_number(event.value))
	if float(event.get("armor_absorbed", 0)) > 0.0: details.append(t("native.armor_absorbed", {"amount": _combat_number(event.armor_absorbed)}))
	if bool(event.get("critical", false)): details.append(t("native.critical"))
	if float(event.get("duration", 0)) > 0.0: details.append(t("native.duration_seconds", {"seconds": _combat_number(event.duration)}))
	if event.has("telegraph_seconds"): details.append(t("native.duration_seconds", {"seconds": _combat_number(event.telegraph_seconds)}))
	if kind == "RUN_EFFECT": details.append(effect_text(str(event.get("effect_type", "")), {"amount": event.get("value", 0), "count": event.get("value", 0)}))
	if event.has("reason"):
		var reason = t("native.reason_" + str(event.reason))
		if not reason.begins_with("native.reason_"): details.append(reason)
	return "%.2f s · %s → %s · %s · %s" % [float(event.get("time", 0)), source, target, translated, " · ".join(details)]

func bilingual(chinese: String, english: String) -> String:
	return chinese if TranslationServer.get_locale().begins_with("zh") else english

func _combat_log_result() -> Dictionary:
	if not flow.combat_result.is_empty(): return flow.combat_result
	if not flow.run.is_empty():
		if not flow.run.get("last_combat_result", {}).is_empty(): return flow.run.last_combat_result
		if not flow.run.logs.is_empty(): return flow.run.logs.back()
	return {}

func show_combat_log(page: int = 0, full: bool = false):
	menus.runs.log_page(page,full)

func show_records():
	menus.library.show_page("records")

func effect_text(kind: String, params) -> String:
	var parsed = db.parse_params(params)
	var aliases = {"item_pool": "random_item", "bag_pool": "random_bag", "upgrade_item": "upgrade", "recipe_upgrade": "upgrade", "execute_recipe": "recipe", "sell_ratio_bonus": "sell_bonus", "interest_cap_delta": "interest", "storage_slot": "storage", "recipe_discovery": "discovery", "cleanse_run_debuff": "cleanse"}
	return t("ui.effect_" + str(aliases.get(kind, kind)), {"amount": parsed.get("amount", parsed.get("count", 1)), "pct": int(round(float(parsed.get("amount", 0)) * 100)), "minimum": parsed.get("min_health", 1), "duration": parsed.get("duration_nodes", parsed.get("duration_battles", 1)), "tier": parsed.get("tier", 1), "rarity": t("rarity." + str(parsed.get("rarity", "common"))), "item": ""})

func show_event():
	menus.runs.event()

func show_summary():
	menus.runs.summary()

func show_crafting():
	menus.library.show_page("recipes")

func show_craft_confirmation(candidate: Dictionary):
	menus.runs.craft(candidate)

func show_journey():
	menus.journey.show_page()

func show_codex():
	menus.library.show_page()

func _block_menu_scroll(event:InputEvent):
	if not initialized or panel==null or not panel.visible:return
	if (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]) or event is InputEventPanGesture:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if not initialized: return
	if preferences.capture_action != "":
		if preferences.capture(event): get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and panel.visible:
		if current_page in ["SETUP", "CODEX", "RECORDS", "RECIPE_CODEX", "SETTINGS", "CRAFTING", "CRAFTING_CONFIRM", "INTEL", "COMBAT_LOG", "JOURNEY", "UI_GUIDE"]:
			if back_action.is_valid(): back_action.call()
			else: close_popup()
		else: show_settings()
		get_viewport().set_input_as_handled()
		return
	if panel.visible: return
	if active and flow.screen_state == "SHOP_PREPARE" and not InputBlocker.isActive():
		if event.is_action_pressed("undo") or event.is_action_pressed("redo"):
			perform(flow.edit("undo" if event.is_action_pressed("undo") else "redo"))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_focus_next"):
			show_current_enemy()
			get_viewport().set_input_as_handled()

func show_ui_guide():
	menus.guide.show_page()

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and flow != null: flow._save()

func _input(event: InputEvent):
	if initialized and preferences.capture_action != "" and preferences.capture(event): get_viewport().set_input_as_handled()
	_block_menu_scroll(event)
