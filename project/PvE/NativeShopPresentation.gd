extends RefCounted
## Stages an editable overlay and scenery for the fixed native shop carrier.

const VIEW = preload("res://PvE/UI/ShopScreen.gd")
const MODEL = preload("res://Runtime/ViewModel/ShopVM.gd")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const SCREEN_PATH = "res://PvE/UI/ShopScreen.tscn"
const SCENERY_PATH = "res://PvE/UI/ShopScenery.tscn"
const SCOPE = "art-routed-shop"
const SHARED_KEYS = ["cell", "cell_empty", "board_guide"]

var owner: Node
var _epoch := -1
var _screen: VIEW
var _scenery: Node2D

func _init(expedition: Node) -> void:
	owner = expedition

func _path(key: String) -> String:
	return REF.path(key) if key in ["previous", "next"] else owner.art._art_path(key)

func prepare(epoch: int, current: Callable) -> bool:
	if not current.call():
		return false
	if is_instance_valid(owner.art.routed_shop):
		return true
	_epoch = epoch
	var keys := VIEW.ART_KEYS + VIEW.SCENERY_KEYS + SHARED_KEYS
	var paths := [SCREEN_PATH, SCENERY_PATH]
	for key in keys:
		paths.append(_path(key))
	if not await AssetStream.prepare(paths, SCOPE) or not current.call():
		return false
	var screen = await AssetStream.instantiate_path(SCREEN_PATH, SCOPE)
	if not current.call() or not screen is VIEW:
		if is_instance_valid(screen): screen.free()
		return false
	_screen = screen
	var scenery = await AssetStream.instantiate_path(SCENERY_PATH, SCOPE)
	if not current.call() or not scenery is Node2D:
		if is_instance_valid(scenery): scenery.free()
		return false
	_scenery = scenery
	var art: Dictionary = {}
	for key in keys:
		art[key] = AssetStream.resources.get(_path(key))
	var model := MODEL.new(owner.flow, _read_controls, _dispatch)
	_screen.menu_requested.connect(_open_menu)
	return _screen.bind(model, art, owner.ui_font, _read_display) == OK and VIEW.apply_scenery(_scenery, art) == OK

func activate(epoch: int) -> void:
	if epoch != _epoch or not is_instance_valid(_screen) or not is_instance_valid(_scenery):
		return
	var screen := _screen
	var scenery := _scenery
	_screen = null
	_scenery = null
	_epoch = -1
	owner.art.use_routed_shop(screen, scenery)

func cancel(epoch: int) -> void:
	if epoch != _epoch:
		return
	_epoch = -1
	if is_instance_valid(_screen): _screen.free()
	if is_instance_valid(_scenery): _scenery.free()
	_screen = null
	_scenery = null
	AssetStream.release(SCOPE)

func release() -> void:
	if is_instance_valid(owner) and is_instance_valid(owner.art):
		owner.art.release_routed_shop()
	AssetStream.release(SCOPE)

func _read_controls() -> Dictionary:
	var held = Game.draggedItem
	var dragging := is_instance_valid(held)
	return {
		"dragging": dragging,
		"held": owner.bridge.item_entry(held) if dragging else {},
		"syncing": owner.syncing,
		"modal_open": owner.panel.visible,
		"transition_busy": owner.art.curtain.busy,
		"render_pending": owner.render_pending,
		"combat_loading": owner.combat_loading,
	}

func _read_display() -> Dictionary:
	var actor = Game.PLAYER
	var offers: Array[Dictionary] = []
	for slot in Game.shopSceneNode.slots:
		var item = slot.item
		offers.append({
			"definition_id": item.get_meta("pve_definition_id", ""),
			"generation": item.get_meta("pve_shop_generation", -1),
		} if is_instance_valid(item) else {})
	var role = owner.db.get_row("characters", str(owner.flow.run.get("character_id", "")))
	return {
		"locale": TranslationServer.get_locale(),
		"ui_scale": owner.preferences.values.get("ui_scale", 1.0),
		"name": owner.t(str(role.get("name_key", ""))),
		"health": actor.getCurrentHealth(), "max_health": actor.getMaxHealth(),
		"stamina": actor.curStamina, "max_stamina": actor.maxStamina,
		"offers": offers,
	}

func _dispatch(action: StringName, args: Array) -> Dictionary:
	if Game.state != Game.State.Shop or SceneRouter.current_screen_id != &"shop" or AssetStream.stopping:
		return {"ok": false, "error": "wrong_view"}
	match action:
		&"refresh_shop":
			return owner.bridge.refresh_shop()
		&"set_lock":
			var slot = Game.shopSceneNode.slots[int(args[0])]
			slot.setReserved(bool(args[1]))
			return {"ok": slot.reserved == bool(args[1])}
		&"start_or_choose_route":
			Game.shopSceneNode.get_node("StartCombatButton").activateButton()
		&"rotate_held":
			if bool(args[0]): Game.draggedItem.rotateRight()
			else: Game.draggedItem.rotateLeft()
		_:
			return {"ok": false, "error": "unknown_action"}
	return {"ok": true}

func _open_menu(action: StringName) -> void:
	if Game.state != Game.State.Shop or owner.panel.visible or owner.art.curtain.busy or AssetStream.stopping:
		return
	match action:
		&"codex": owner.art.open_book()
		&"journey": owner.art.open_intel()
		&"settings": owner.show_settings()
