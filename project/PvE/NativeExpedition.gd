extends Node

# The recovered game remains the scene, animation, input and asset foundation.
# Rules and native presentation remain separate from the flat touch UI.
# This distribution has one authoritative ruleset. Scene entry APIs remain stable.
const enabled: bool = true
const ClassRegistry = preload("res://PvE/ClassRegistry.gd")
const HUD_LAYER = preload("res://PvE/UI/HudLayer.gd")
const HUD_VM = preload("res://Code/Runtime/ViewModel/HudVM.gd")
const COMBAT_LOG_VM = preload("res://Code/Runtime/ViewModel/CombatLogVM.gd")
var combat_log_vm: COMBAT_LOG_VM
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
var route_prompt_key: String = ""
var scenery = preload("res://Code/Runtime/Loading/SceneResidency.gd").new()
var residency_clock: float = 0.0
var render_pending: bool = false
var render_queued: bool = false
var native_battle_ready: bool = false
var native_phase: int = 1
var combat_vm := preload("res://Code/Runtime/ViewModel/CombatVM.gd").new()
var hud_layer: HUD_LAYER
var hud_vm: HUD_VM
var overlay: CanvasLayer
var panel: Panel
var popup_content: VBoxContainer
var toolbar: HBoxContainer
var status: Label
var toast: Label
var tutorial_hint: Label
var toast_time: float:
	get: return hud_vm.notice_time() if hud_vm != null else 0.0
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
var restoring_result: bool = false
var transitions
var art
var menus
var menu_header: HBoxContainer
var menu_nav: HBoxContainer
var loading_screen
var native_routes

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
	loading_screen=preload("res://PvE/UI/LoadingScreen.gd").new();add_child(loading_screen)
	loading_screen.present()
	call_deferred("initialize_native")

func initialize_native():
	while not is_instance_valid(Game.PLAYER) or Game.PLAYER.INVENTORY == null:
		await get_tree().process_frame
	while Settings.initializing:
		await get_tree().process_frame
	bindings = load("res://PvE/NativeAssetBindings.gd").new(db)
	bridge = load("res://PvE/NativeBuildBridge.gd").new(self)
	# LegacyFont's compatibility binder forces its stored 24px size onto every
	# control. A native font variation keeps each reference label's authored size.
	ui_font = FontVariation.new()
	ui_font.base_font = load("res://UI/Fonts/YaHei-Regular.ttc")
	ui_font.variation_embolden = 0.5
	while not is_instance_valid(loading_screen.root):await get_tree().process_frame
	preferences = load("res://PvE/NativePreferences.gd").new(self)
	detail_views = load("res://PvE/NativeDetailViews.gd").new(self)
	combat_log_vm = COMBAT_LOG_VM.new(flow, detail_views.rules, t, effect_text)
	transitions = load("res://PvE/NativeTransitions.gd").new(self)
	menus = preload("res://PvE/UI/TouchMenus.gd").new(self)
	_mount_shared_ui()
	preferences.apply()
	art = load("res://PvE/Art/Presentation.gd").new()
	add_child(art)
	await menus.prepare_icons()
	Game.randomCharacter = false
	if not Game.isClassUnlocked(Game.curClass): Game.instanceCharacter(ClassRegistry.index_of("Berserker"))
	if enabled and SceneRouter.ENABLED:
		var routes = preload("res://PvE/NativeSceneRoutes.gd").new(self)
		var install_error: Error = await routes.install()
		if install_error == OK:
			native_routes = routes
		else:
			push_error("Native scene routing could not initialize: " + error_string(install_error))
	initialized = true
	request_render()

func route_in_progress() -> bool:
	return native_routes != null and SceneRouter.is_busy()

func _mount_shared_ui() -> void:
	ui_theme = Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 24
	preload("res://PvE/Art/UISkin.gd").apply(ui_theme)

	hud_layer = preload("res://PvE/UI/HudLayer.tscn").instantiate()
	add_child(hud_layer)
	overlay = preload("res://PvE/UI/DialogLayer.tscn").instantiate()
	add_child(overlay)
	toolbar = hud_layer.toolbar
	status = hud_layer.status
	tutorial_hint = hud_layer.tutorial_hint
	toast = overlay.get_node("Toast")
	hud_vm = HUD_VM.new(t)
	hud_layer.bind(hud_vm, ui_theme, ui_font, float(preferences.values.ui_scale), toast)

	modal_shield = overlay.get_node("ModalShield")
	panel = overlay.get_node("Panel")
	panel.theme = ui_theme
	panel.add_theme_stylebox_override("panel", ui_theme.get_stylebox("panel", "PanelContainer"))
	var frame := panel.get_node("Frame")
	menu_header = frame.get_node("Header")
	menu_nav = frame.get_node("Navigation")
	popup_scroll = frame.get_node("Scroll")
	popup_content = popup_scroll.get_node("Content")
	menus.shell.pager = preload("res://PvE/UI/PageTurner.gd").new(self, menus.shell)
	menus.shell.pager.attach(frame)

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
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		Sound.playSound(load("res://Audio/Sound/Thud5.wav"), -15)
		action.call())
	parent.add_child(node)
	return node

func clear_popup(title: String):
	menus.shell.reset_canvas()
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
	menus.shell.reset_canvas()
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
	var message := t("ui.confirm_overwrite" if key == "confirm_overwrite_run" else key)
	hud_vm.show_notice(t("ui.generic_error") if message == key else message)

func perform(result: Dictionary):
	if not result.get("ok", false): notice(str(result.get("error", "ui.generic_error")))
	else: Sound.playSound(load("res://Audio/Sound/Thud5.wav"), -12)

func request_render():
	render_pending = true
	if render_queued: return
	render_queued = true
	call_deferred("_drain_render")

func _drain_render():
	render_queued = false
	if render_pending: render_state()

func shop_render_suspended() -> bool:
	return native_routes != null and native_routes.shop_render_suspended()

func begin_setup(mode: int = 0):
	if initialized: menus.runs.setup(mode)

func create_run(role: String, loadout: String, difficulty: String, seed: int, confirmed: bool = false):
	var result = flow.new_run(role,loadout,difficulty,seed,confirmed)
	if not result.ok and result.error == "confirm_overwrite_run": menus.runs.confirm_new(role,loadout,difficulty,seed)
	else:
		if result.ok:
			if native_routes != null: native_routes.change(&"title", "new_expedition")
			else: _reset_native_run_view()
		perform(result)
	return result

func continue_run(_mode: int = 0):
	if not initialized: return
	if native_routes != null:
		if flow.screen_state != "MAIN_MENU" and route_in_progress(): return
		var restored = flow.continue_run()
		perform(restored)
		if not restored.ok: return
		match flow.screen_state:
			"COMBAT_RUNNING", "COMBAT_RESULT":
				await native_routes.change(&"combat", "continue_run", true)
			"SHOP_PREPARE":
				await native_routes.change(&"shop", "continue_run")
			_:
				await native_routes.change(&"title", "continue_run")
		return
	var loading_ticket=await art.curtain.cover("continue_run")
	var result = flow.continue_run()
	perform(result)
	if not result.ok:await art.curtain.reveal(loading_ticket);return
	if result.ok and flow.screen_state in ["COMBAT_RUNNING", "COMBAT_RESULT"]:
		restoring_result = flow.screen_state == "COMBAT_RESULT"
		result_presented = false
		native_battle_ready = false
		await enter_shop()
		Game.sceneAnimation.advance(100)
		Game.sceneAnimation.play("ShopToCombat")
		Game.sceneAnimation.advance(0.017)
	elif flow.screen_state!="SHOP_PREPARE":
		await get_tree().process_frame
		art.reveal_ready("title",loading_ticket,view_epoch)

func save_run() -> bool:
	return flow != null and flow._save()

func return_to_title():
	if not initialized: return
	if native_routes != null:
		if not flow.go_main_menu().ok:
			notice("save_write_failed")
			return
		await native_routes.change(&"title", "return_to_title")
		return
	var title_ticket = await art.curtain.cover("return_to_title")
	if not flow.go_main_menu().ok:
		notice("save_write_failed")
		art.curtain.reveal(title_ticket)
		return
	_reset_native_run_view()
	request_render()
	art.reveal_ready("title",title_ticket,view_epoch)

func _reset_native_run_view(advance_epoch: bool = true):
	route_prompt_key = ""
	# New runs can start directly from a defeated combat scene. Reset the
	# presentation transaction before waiting for the next title/route reveal.
	if advance_epoch: view_epoch += 1
	if art != null and art.combat_fx != null: art.combat_fx.clear()
	bridge.cancel_views()
	scenery.unload("shop")
	scenery.unload("combat")
	InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
	entering_shop=false;combat_loading=false
	restoring_result = false
	Game.pve_prepare_title()
	set_playback(1.0, false)
	native_battle_ready = false
	combat_vm.load_result({})
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	close_popup()
	Game.runStarted = false
	if native_routes != null:
		Game.titleScreen.showTitle()
	else:
		Game.sceneAnimation.play("StartOnTitle")
		Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	Game.PLAYER.shopToTitle()
	Game.PLAYER.finishAnimations()
	bridge.unload_run_views()
	Game.titleScreen.checkSavedRunState()
	# Route/rest pages share native Title state. Their saved-run controls still
	# need rebuilding when returning, even without a native scene-state change.
	art.view = ""
	Game.emit_signal("returned_to_title")

func start_battle() -> bool:
	if not initialized or syncing or route_in_progress() or flow.screen_state != "SHOP_PREPARE": return false
	if bool(flow.run.get("route_pending", false)):
		show_routes()
		return false
	if is_instance_valid(Game.draggedItem): notice("native.drop_first"); return false
	var result = flow.complete_node() if flow.run.current_node.type == "merchant" else flow.start_combat()
	perform(result)
	if not result.ok: return false
	native_battle_ready = false
	result_presented = false
	native_phase = 1
	return flow.screen_state == "COMBAT_RUNNING"

func finish_switch_to_combat():
	if flow.screen_state not in ["COMBAT_RUNNING", "COMBAT_RESULT"] or combat_loading: return
	combat_loading = true
	var epoch = view_epoch
	var transition_ticket = await art.curtain.cover("enter_combat")
	if epoch != view_epoch: return
	if not await scenery.ensure_view("combat") or epoch != view_epoch:
		if epoch == view_epoch:
			combat_loading = false
			art.curtain.reveal(transition_ticket)
		return
	if not await prepare_native_opponent(func(): return epoch == view_epoch):
		if epoch == view_epoch:
			combat_loading = false
			art.curtain.reveal(transition_ticket)
		return
	combat_loading = false
	activate_native_combat()
	art.reveal_ready("combat",transition_ticket,epoch)

func prepare_native_opponent(current: Callable, phase: int = 1) -> bool:
	var node: Dictionary = flow.run.current_node
	var enemy = db.get_row("enemy_builds", str(node.get("enemy_id", "")))
	var character = ClassRegistry.index_of("Reaper") if str(enemy.get("archetype_id", "")) in ["venom_brewer", "ember_runner"] else ClassRegistry.index_of("Berserker")
	if not await AssetStream.prepare_actor(character, false, "actor-enemy", false) or not current.call():
		return false
	Game.freeOpponent()
	var opponent = Game.opponentScene.instantiate()
	opponent.playerId = Character.ID.OPPONENT
	opponent.position = Vector2(1920 - Game.playerCombatPos, 880)
	Game.OPPONENT = opponent
	Game.opponentNode.add_child(opponent)
	opponent.setClass(character, false)
	opponent.setCharacterName(enemy_name(node))
	Game.PLAYER.setOpponent(opponent)
	opponent.setOpponent(Game.PLAYER)
	await bridge.render_build(opponent, enemy_build(node, phase), Item.Owner.Opponent)
	return current.call() and is_instance_valid(opponent)

func activate_native_combat():
	combat_vm.load_result(flow.combat_result)
	Game.closeAllMenus()
	Game.setInventoryEditMode(Game.InventoryEditMode.Default)
	Game.canCancelSwitch = false
	Game.canSwitchToCombat = false
	Game.fightEnded = false
	Game.emit_signal("shop_closed")
	Game.emit_signal("switching_to_combat")
	Game.combatTimer.initialize()
	Game.PLAYER.shopToCombat()
	Game.pve_prepare_combat()
	Game.PLAYER.set_physics_process(false)
	Game.OPPONENT.set_physics_process(false)
	Sound.playSound(load("res://Audio/Sound/Drumroll.ogg"))
	native_battle_ready = not restoring_result
	_apply_timeline()

func enter_shop():
	if not initialized or entering_shop: return
	if native_routes != null:
		await native_routes.change(&"shop", "enter_shop")
		return
	entering_shop = true
	var epoch = view_epoch
	var transition_ticket = await art.curtain.cover("enter_shop")
	if epoch != view_epoch: return
	InputBlocker.activate(InputBlocker.Source.Streaming, false)
	var ready = await scenery.ensure_view("shop")
	if epoch != view_epoch: return
	InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
	if not ready or epoch != view_epoch:
		entering_shop = false
		art.curtain.reveal(transition_ticket)
		return
	combat_vm.load_result({})
	Game.pve_prepare_shop()
	AssetStream.release("build-enemy")
	AssetStream.release("actor-enemy")
	if not await prepare_native_player(func(): return epoch == view_epoch):
		if epoch == view_epoch:
			entering_shop = false
			art.curtain.reveal(transition_ticket)
		return
	set_native_run_context()
	if Game.state == Game.State.Title:
		Game.titleToShop()
	else:
		Game.PLAYER.combatToShop()
		Game.sceneAnimation.play("CombatToShop")
		Game.sceneAnimation.advance(100)
	Game.state = Game.State.Shop
	Game.canSwitchToCombat = true
	await start_round()
	if epoch != view_epoch: return
	entering_shop = false
	call_deferred("restore_native_stats")
	close_popup()
	art.reveal_ready("shop",transition_ticket,epoch)

func set_native_run_context():
	Game.runStarted = true
	Game.curRound = (int(flow.run.act) - 1) * 5 + int(flow.run.step)
	Game.tries = 1
	Game.wins = flow.run.logs.filter(func(record): return int(record.winner) == 0).size()
	Game.losses = 0

func prepare_native_player(current: Callable) -> bool:
	# Archer uses the existing native carrier; its rules and art come from PvE.
	# 角色 id 走注册表查职业序号；查不到或职业未启用时沿用军械师（与旧行为一致）。
	var role = ClassRegistry.index_for_art_key(str(flow.run.character_id))
	if role < 0 or not Game.isClassUnlocked(role): role = ClassRegistry.index_of("Berserker")
	var catalogue = preload("res://PvE/Art/SuppliedArt.gd")
	var expected_portrait = catalogue.actor_path(catalogue.player_key(role))
	var portrait_changed = not is_instance_valid(Game.PLAYER.sprite) or Game.PLAYER.sprite.get_meta("new_art_path", "") != expected_portrait
	if Game.curClass != role or portrait_changed:
		if not await AssetStream.prepare_actor(role, Game.getEffectiveChibiMode(), "actor-player", true) or not current.call():
			return false
		Game.instanceCharacter(role)
	return current.call()

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
	if bool(flow.run.get("route_pending", false)): show_routes(); return
	if not flow.run.is_empty() and not flow.run.current_node.is_empty(): show_enemy(flow.run.current_node)

func prompt_route_when_ready(epoch: int):
	while epoch == view_epoch and flow.screen_state == "SHOP_PREPARE" and (entering_shop or syncing or art.curtain.busy):
		await get_tree().process_frame
	if epoch != view_epoch or flow.screen_state != "SHOP_PREPARE" or not bool(flow.run.get("route_pending", false)) or panel.visible: return
	var key = "%s:%d:%d" % [flow.run.run_id,int(flow.run.act),int(flow.run.step)]
	if key == route_prompt_key: return
	route_prompt_key = key
	show_routes()

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
	if render_pending and not render_queued and not syncing and not restoring_result and not is_instance_valid(Game.draggedItem) and not route_in_progress() and not shop_render_suspended(): request_render()
	residency_clock += delta
	if residency_clock >= 0.5:
		residency_clock = 0.0
		if not syncing and not entering_shop and not combat_loading: scenery.trim_inactive()
	if restoring_result and Game.state == Game.State.Combat and not Game.sceneAnimation.is_playing() and not route_in_progress():
		restoring_result = false
		flow.playback_time = float(flow.combat_result.elapsed_time)
		combat_vm.sync_event_cursor(flow.playback_time)
		native_phase = int(flow.combat_result.get("boss_phases", [1, 1])[1])
		if native_phase > 1: bridge.render_build(Game.OPPONENT, enemy_build(flow.run.current_node, native_phase), Item.Owner.Opponent)
		_apply_timeline()
		show_battle_result()
	hud_vm.advance(delta)
	tutorial_hint.visible = active and toast_time <= 0
	if not flow.run.is_empty() and flow.screen_state != "MAIN_MENU": flow.run.play_seconds = float(flow.run.get("play_seconds", 0)) + delta
	if flow.screen_state == "COMBAT_RUNNING" and native_battle_ready and Game.state == Game.State.Combat and not art.curtain.busy and not route_in_progress():
		flow.advance_combat(delta)
		_apply_timeline()
		_play_events()
		_update_native_cooldowns()
	if active:
		var displayed_health = Game.PLAYER.getCurrentHealth() if flow.screen_state == "COMBAT_RUNNING" else float(flow.run.health)
		hud_vm.update_status(flow.run, displayed_health)

func _apply_timeline():
	if not is_instance_valid(Game.OPPONENT): return
	var playback_time: float = flow.playback_time
	combat_vm.set_playback_time(playback_time)
	var state := combat_vm.frame_at(playback_time)
	if state.is_empty(): return
	for side in range(2):
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		var view_state: Dictionary = state.sides[side]
		actor.set_meta("pve_status_timeline",view_state.statuses)
		actor.set_meta("pve_armor_timeline",float(view_state.armor))
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
	for event in combat_vm.consume_events_through(flow.playback_time):
		if art != null and art.combat_fx != null: art.combat_fx.consume(event)
		var side = int(event.get("source_side", 0))
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		if event.type == "BOSS_PHASE":
			native_phase = int(event.get("value", 2))
			bridge.render_build(Game.OPPONENT, enemy_build(flow.run.current_node, native_phase), Item.Owner.Opponent)
			Sound.playSound(load("res://Audio/Sound/LevelUp1.ogg"))
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
				Sound.playSound(load("res://Audio/Sound/Impact.ogg"), -15)
				last_audio_tick = now

func _update_native_cooldowns():
	for side in range(2):
		var actor = Game.PLAYER if side == 0 else Game.OPPONENT
		if not is_instance_valid(actor): continue
		for item in actor.INVENTORY.getItems():
			if item.isBag(): continue
			var uid = str(item.get_meta("pve_uid", ""))
			item.showCooldown(combat_vm.cooldown_fraction(side, uid, flow.playback_time))

func set_playback(speed: float, paused: bool):
	flow.combat_speed = speed
	flow.combat_paused = paused
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	for node in [Game.playerNode, Game.opponentNode]: node.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func advance_result(): perform(flow.confirm_combat())

func render_state(force: bool = false, settling_route: bool = false):
	if shop_render_suspended(): return
	if not initialized or syncing or restoring_result or is_instance_valid(Game.draggedItem) or (route_in_progress() and not settling_route):
		render_pending = true
		return
	render_pending = false
	update_tutorial_hint()
	var state = str(flow.screen_state)
	var transitioned = state != last_flow_state
	last_flow_state = state
	hud_layer.set_run_controls_visible(active)
	if state == "MAIN_MENU":
		if transitioned or force: close_popup()
		return
	if state == "SHOP_PREPARE":
		if Game.state != Game.State.Shop: enter_shop()
		elif not settling_route: start_round()
		if not flow.run.pending_rewards.is_empty(): show_pending()
		elif current_page == "CRAFTING" and not force and not transitioned: show_crafting()
		elif transitioned or force or current_page == "PENDING": close_popup()
		prompt_route_when_ready(view_epoch)
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
		Sound.playSound(load("res://Audio/Sound/Victory.mp3" if won else "res://Audio/Sound/Fanfare_loss.mp3"))
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

func combat_event_text(event: Dictionary, result: Dictionary = {}) -> String:
	return combat_log_vm.event_text(event, result)

func bilingual(chinese: String, english: String) -> String:
	return chinese if TranslationServer.get_locale().begins_with("zh") else english

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
