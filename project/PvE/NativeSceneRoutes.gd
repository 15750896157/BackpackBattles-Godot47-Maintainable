extends RefCounted
## Bridge the router's view transactions to the native scene shell.
const READY_TIMEOUT_MS = 25000
const TITLE_SCENE = "res://PvE/UI/TitleScreen.tscn"
const COMBAT_SCENE = "res://PvE/UI/CombatScreen.tscn"
const TITLE_VIEW = preload("res://PvE/UI/TitleScreen.gd")
const TITLE_MODEL = preload("res://Code/Runtime/ViewModel/TitleVM.gd")
const REFERENCE = preload("res://PvE/UI/ReferenceCanvas.gd")
const SHOP_PRESENTATION = preload("res://PvE/NativeShopPresentation.gd")
var owner: Node
var shop_presentation: SHOP_PRESENTATION
var _suspended_shop_epoch := -1
var request_id := 0
var target: StringName = &""
var reason := ""

func _init(expedition: Node):
	owner = expedition
	shop_presentation = SHOP_PRESENTATION.new(owner)

func install() -> Error:
	var error = SceneRouter.configure(AssetStream, owner.art.curtain, owner.art.layer)
	if error != OK: return error
	SceneRouter.register_screen(&"title", TITLE_SCENE, REFERENCE.paths(TITLE_VIEW.ART_KEYS), _prepare_title_scene, _activate_title, _settle.bind(&"title"))
	SceneRouter.register_branch(&"shop", Game.shopSceneNode, _prepare_shop, _activate_shop, _release_shop, _cancel_shop, _settle.bind(&"shop"))
	SceneRouter.register_screen(&"combat", COMBAT_SCENE, owner.art.combat_screen_paths(), _prepare_combat_screen, _activate_combat, _settle.bind(&"combat"), _release_combat_screen, _cancel.bind(&"combat"))
	SceneRouter.set_enabled(true)
	var startup := SceneRouter.request_scene(&"title", {"epoch": owner.view_epoch, "reason": "startup", "initial": true})
	error = startup.error
	if error == OK:
		error = await SceneRouter.wait_for_request(startup.id)
	if error != OK:
		SceneRouter.shutdown()
		_show_branch(Game.titleScreen)
		return error
	SceneRouter.request_finished.connect(_finished)
	return OK

func change(next: StringName, transition_reason: String, restored: bool = false) -> int:
	if owner.route_in_progress() and target == next and reason == transition_reason and transition_reason != "new_expedition":
		return await SceneRouter.wait_for_request(request_id)
	var replacing = owner.route_in_progress()
	var epoch: int = owner.view_epoch + 1
	var admission = SceneRouter.request_scene(next, {"epoch": epoch, "reason": transition_reason, "restored": restored, "keep_cover": true})
	if admission.error != OK:
		owner.notice("ui.generic_error")
		return admission.error
	if SceneRouter.last_request_id != admission.id:
		return await SceneRouter.wait_for_request(admission.id)
	owner.view_epoch = epoch
	if replacing or next == &"title": owner.bridge.cancel_views()
	request_id = admission.id
	target = next
	reason = transition_reason
	owner.entering_shop = next == &"shop"
	owner.combat_loading = next == &"combat"
	return await SceneRouter.wait_for_request(request_id)

func _owns(options: Dictionary, current: Callable) -> bool:
	return current.call() and owner.view_epoch == int(options.get("epoch", -1)) and not AssetStream.stopping

func _prepare(options: Dictionary, current: Callable, kind: StringName) -> bool:
	while (owner.syncing or owner.bridge.drop_pending) and _owns(options, current):
		await owner.get_tree().process_frame
	if not _owns(options, current): return false
	if kind == &"title":
		if is_instance_valid(Game.draggedItem):
			Game.draggedItem.cancelDrag()
			while owner.bridge.drop_pending and _owns(options, current):
				await owner.get_tree().process_frame
		return _owns(options, current) and not is_instance_valid(Game.draggedItem)
	if kind == &"shop" and owner.flow.screen_state != "SHOP_PREPARE": return false
	if kind == &"combat" and owner.flow.screen_state not in ["COMBAT_RUNNING", "COMBAT_RESULT"]: return false
	if not await owner.scenery.ensure_view(str(kind)) or not _owns(options, current): return false
	var alive := _owns.bind(options, current)
	var restored := bool(options.get("restored", false))
	if kind == &"shop" or restored:
		if not await owner.prepare_native_player(alive) or not alive.call(): return false
	if kind == &"shop": return true
	if restored:
		var player = Game.PLAYER
		await owner.bridge.render_build(player, owner.flow.run.build.duplicate(true), Item.Owner.PlayerInventory)
		if not alive.call(): return false
	return await owner.prepare_native_opponent(alive)

func _show_branch(carrier: Node2D):
	carrier.position = Vector2.ZERO
	carrier.show()
	owner.scenery.set_carrier_active(carrier, true)

func _release(carrier: Node2D):
	carrier.hide()
	owner.scenery.set_carrier_active(carrier, false)

func _cancel(options: Dictionary, kind: StringName):
	# The next worker starts only after the current prepare has unwound.
	if owner.view_epoch != int(options.get("epoch", -1)): return
	if SceneRouter.current_screen_id != kind:
		owner.scenery.unload(str(kind))
		if kind == &"combat":
			AssetStream.release("actor-enemy")
			AssetStream.release("build-enemy")
			Game.freeOpponent(false)

func _prepare_title_scene(carrier: Node, options: Dictionary, current: Callable) -> bool:
	if not await _prepare(options, current, &"title") or not _owns(options, current):
		return false
	var art: Dictionary = {}
	for key in TITLE_VIEW.ART_KEYS:
		art[key] = REFERENCE.texture(key)
	var model := TITLE_MODEL.new(owner.flow.saves, owner.db, TranslationServer.get_locale, _can_interact, _title_action)
	return carrier.bind(model, art, owner.ui_font) == OK

func _prepare_combat_screen(screen: Control, options: Dictionary, current: Callable) -> bool:
	if not _owns(options, current) or owner.art.bind_combat_screen(screen) != OK:
		return false
	return await _prepare(options, current, &"combat")

func _prepare_shop(options: Dictionary, current: Callable) -> bool:
	var alive := _owns.bind(options, current)
	if owner.flow.screen_state != "SHOP_PREPARE" or not await shop_presentation.prepare(int(options.epoch), alive):
		return false
	return await _prepare(options, current, &"shop")

func _cancel_shop(options: Dictionary) -> void:
	shop_presentation.cancel(int(options.epoch))
	_cancel(options, &"shop")

func _release_shop(carrier: Node2D) -> void:
	shop_presentation.release()
	_release(carrier)

func shop_render_suspended() -> bool:
	# Keep dirty work after a failed or explicitly cancelled mount. A continue or route
	# supersedes this epoch; a frame tick alone must not retry forever.
	return _suspended_shop_epoch == owner.view_epoch and Game.state != Game.State.Shop and owner.flow.screen_state == "SHOP_PREPARE"

func _can_interact() -> bool:
	return owner.initialized and not owner.route_in_progress() and not AssetStream.stopping and not InputBlocker.isActive() and not owner.loading_screen.visible and not owner.panel.visible

func _title_action(action: StringName) -> void:
	match action:
		&"new_run": owner.menus.runs.new_setup()
		&"continue_run": owner.continue_run()
		&"settings": owner.show_settings()
		&"codex": owner.show_codex()
		&"quit": Game.quit()

func _activate_title(carrier: Control, options: Dictionary):
	if bool(options.get("initial", false)):
		Game.sceneAnimation.stop()
		Game.titleScreen.showTitle()
		_release(Game.shopSceneNode)
		_release(Game.combatSceneNode)
	else:
		owner._reset_native_run_view(false)
	_release(Game.titleScreen)
	carrier.process_mode = Node.PROCESS_MODE_INHERIT
	carrier.show()
	owner.art.use_routed_title(carrier)

func _activate_shop(carrier: Node2D, options: Dictionary):
	var from_title = Game.state == Game.State.Title
	_show_branch(carrier)
	carrier.z_index = 10
	owner.combat_vm.load_result({})
	Game.pve_prepare_shop()
	AssetStream.release("build-enemy")
	AssetStream.release("actor-enemy")
	owner.set_native_run_context()
	if from_title:
		Game.PLAYER.titleToShop()
		Sound.playSound(Game.transitionSounds[0])
		Game.emit_signal("switch_to_shop")
		Game.emit_signal("title_to_shop")
	else:
		Game.PLAYER.combatToShop()
	Game.state = Game.State.Shop
	Game.canSwitchToCombat = false
	shop_presentation.activate(int(options.epoch))
	Game.emit_signal("pre_shop_opened_from_title" if from_title else "pre_shop_opened_from_combat")
	if from_title: Game.emit_signal("run_started")

func _activate_combat(screen: Control, options: Dictionary):
	var carrier = Game.combatSceneNode
	_show_branch(carrier)
	carrier.backgroundNode.position = Vector2.ZERO
	Game.combatTimer.position = Vector2.ZERO
	var log_button = carrier.combatLogButton
	log_button.position = Vector2(905, 191)
	log_button.modulate = Color.WHITE
	Game.startCombatButton.cancelSwitch()
	Game.startCombatButton.playSwitchSound()
	if options.get("restored", false):
		owner.set_native_run_context()
	else:
		Game.emit_signal("combat_start_pressed")
	owner.restoring_result = owner.flow.screen_state == "COMBAT_RESULT"
	owner.native_phase = 1
	owner.result_presented = false
	owner.activate_native_combat()
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if actor.animation.current_animation in ["OpponentInit", "EnterCombatFromShop"]: actor.animation.advance(100)
		actor.pve_set_combat_anchor()
	Game.state = Game.State.Combat
	owner.combat_loading = false
	screen.process_mode = Node.PROCESS_MODE_INHERIT
	owner.combat_vm.screen_action_requested.connect(_combat_action.bind(screen))
	owner.art.use_routed_combat(screen)
	Game.emit_signal("combat_scene_entered")

func _combat_action(action: StringName, screen: Control) -> void:
	if SceneRouter.get_current_node() != screen or not _can_interact():
		return
	match action:
		&"pause_play":
			if owner.flow.combat_paused: Game.combatTimer.unpause()
			else: Game.combatTimer.onPauseButtonPressed()
		&"speed": Game.combatTimer.onFastButtonPressed()
		&"settings": owner.show_settings()

func _release_combat_screen(screen: Control) -> void:
	if not is_instance_valid(owner):
		return
	var action := _combat_action.bind(screen)
	if owner.combat_vm.screen_action_requested.is_connected(action):
		owner.combat_vm.screen_action_requested.disconnect(action)
	if SceneRouter.current_screen_id == &"combat" and SceneRouter.get_current_node() != screen:
		return
	if is_instance_valid(owner.art):
		owner.art.release_routed_combat(screen)
	if is_instance_valid(Game.combatSceneNode):
		_release(Game.combatSceneNode)
		owner.scenery.unload("combat")

func _settle(options: Dictionary, current: Callable, kind: StringName) -> bool:
	if kind == &"shop":
		owner.render_state(false, true)
		await owner.start_round()
		if not _owns(options, current): return false
		owner.entering_shop = false
		owner.restore_native_stats()
		Game.emit_signal("shop_opened")
	elif kind == &"title" and not bool(options.get("initial", false)):
		owner.render_state(true, true)
	var deadline := Time.get_ticks_msec() + READY_TIMEOUT_MS
	while _owns(options, current) and Time.get_ticks_msec() < deadline:
		if owner.art._reveal_target_ready(str(kind)):
			await owner.get_tree().process_frame
			if not _owns(options, current): return false
			if owner.art._reveal_target_ready(str(kind)): return true
		else:
			await owner.get_tree().process_frame
	return false

func _finished(id: int, screen: StringName, error: int):
	if id != request_id: return
	owner.entering_shop = false
	owner.combat_loading = false
	if screen == &"shop" and error != OK and SceneRouter.last_request_id == id:
		_suspended_shop_epoch = owner.view_epoch
		owner.render_pending = true
	if error != OK and error != ERR_SKIP:
		if screen != &"shop": owner.render_pending = false
		owner.notice("native_asset_missing")
