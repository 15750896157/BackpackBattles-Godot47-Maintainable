extends "res://Code/Runtime/ViewModel/ViewModel.gd"
## Detached shop and journey state. The host owns transient input and dispatches
## commands through the existing native or GameFlow entry points.

var _flow: GameFlow
var _read_controls: Callable
var _dispatch: Callable
var _state: Dictionary = {}
var _refresh_queued := false
var _dispatching := false

func _init(flow: GameFlow, read_controls: Callable, dispatch: Callable) -> void:
	_flow = flow
	_read_controls = read_controls
	_dispatch = dispatch
	_flow.changed.connect(_queue_refresh)
	refresh()

func snapshot() -> Dictionary:
	return _state.duplicate(true)

## Call after host-only changes such as a drag, popup or loading barrier.
func refresh() -> void:
	var run: Dictionary = _flow.run
	var mode: String = _flow.screen_state
	var shop: Dictionary = {}
	var candidates: Array = []
	var page: Dictionary = {}
	var node: Dictionary = run.get("current_node", {})
	var pending := mode == "SHOP_PREPARE" and bool(run.get("route_pending", false))
	if mode == "SHOP_PREPARE":
		var stock: Dictionary = run.get("shop", {})
		shop = {
			"visit": int(run.get("visit", 0)),
			"refresh_count": int(stock.get("refresh_count", 0)),
			"generation": int(stock.get("generation", 0)),
			"slots": _offer_views(stock.get("slots", [])),
			"refresh_cost": int(_flow.economy.refresh_cost(run)),
			"controls": _shop_controls(),
		}
	if mode == "ROUTE_SELECT" or pending:
		candidates = run.get("route_candidates", [])
	if mode in ["EVENT", "REST"]:
		page = _choice_page(run, str(node.get("event_id", "")), mode == "REST")
	var next := {
		"mode": mode,
		"act": int(run.get("act", 0)),
		"step": int(run.get("step", 0)),
		"character_id": str(run.get("character_id", "")),
		"gold": int(run.get("gold", 0)),
		"health": int(run.get("health", 0)),
		"max_health": int(run.get("max_health", 0)),
		"node_type": str(node.get("type", "")),
		"route_pending": pending,
		"route_candidates": candidates,
		"shop": shop,
		"choice_page": page,
	}
	if next != _state:
		_state = next.duplicate(true)
		changed.emit()

func _offer_views(slots: Array) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for slot: Dictionary in slots:
		offers.append({
			"definition_id": str(slot.get("definition_id", "")),
			"kind": str(slot.get("kind", "")),
			"price": int(slot.get("price", 0)),
			"discount_pct": float(slot.get("discount_pct", 0.0)),
			"discounted": bool(slot.get("discounted", false)),
			"locked": bool(slot.get("locked", false)),
			"sold": bool(slot.get("sold", false)),
		})
	return offers

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_apply_queued_refresh.call_deferred()

func _apply_queued_refresh() -> void:
	_refresh_queued = false
	refresh()

func _shop_controls() -> Dictionary:
	var host: Dictionary = _read_controls.call()
	var dragging := bool(host.get("dragging", false))
	var modal := bool(host.get("modal_open", false))
	var syncing := bool(host.get("syncing", false))
	var covered := bool(host.get("transition_busy", false))
	var entry: Dictionary = host.get("held", {}) if dragging else {}
	var held: Dictionary = {}
	if not entry.is_empty():
		held = {
			"uid": str(entry.get("uid", "")),
			"definition_id": str(entry.get("definition_id", "")),
			"rotation": int(entry.get("rotation", 0)),
		}
	return {
		"dragging": dragging,
		"held": held,
		"can_rotate": dragging and not modal,
		"can_lock": not (dragging or syncing or modal),
		"can_refresh": not (dragging or syncing or covered or modal or bool(host.get("render_pending", false))),
		"can_start": not (dragging or syncing or covered or modal or bool(host.get("combat_loading", false))),
	}

func _choice_page(run: Dictionary, event_id: String, rest: bool) -> Dictionary:
	var event: Dictionary = {} if rest else _flow.db.get_row("events", event_id)
	var choices: Array[Dictionary] = []
	var parent_key := "rest_action_id" if rest else "choice_id"
	var effects: Array = _flow.db.rows("rest_action_effects" if rest else "event_choice_effects")
	for row in _flow.db.rows("rest_actions" if rest else "event_choices"):
		if not rest and str(row.get("event_id", "")) != event_id:
			continue
		var matching: Array = []
		for effect in effects:
			if effect.get(parent_key, "") == row.id:
				matching.append(effect)
		choices.append({
			"rule": row,
			"effects": matching,
			"requirements": _flow.effects.requirements(run, str(row.get("requirements", ""))),
		})
	return {"event": event, "choices": choices}

func refresh_shop() -> Dictionary:
	return _shop_command(&"refresh_shop", "can_refresh")

func set_lock(index: int, locked: bool) -> Dictionary:
	if _flow.screen_state == "SHOP_PREPARE":
		var stock: Dictionary = _flow.run.get("shop", {})
		var slots: Array = stock.get("slots", [])
		if index < 0 or index >= slots.size():
			return _rejected("invalid_slot")
	return _shop_command(&"set_lock", "can_lock", [index, locked])

func start_or_choose_route() -> Dictionary:
	return _shop_command(&"start_or_choose_route", "can_start")

func rotate_held(clockwise: bool) -> Dictionary:
	return _shop_command(&"rotate_held", "can_rotate", [clockwise])

func choose_route(index: int) -> Dictionary:
	if _flow.screen_state != "ROUTE_SELECT" and not (
		_flow.screen_state == "SHOP_PREPARE" and bool(_flow.run.get("route_pending", false))
	):
		return _rejected("wrong_state")
	return _activate(&"choose_route", [index])

func choose_event_action(id: String, options: Dictionary = {}) -> Dictionary:
	if _flow.screen_state not in ["EVENT", "REST"]:
		return _rejected("wrong_state")
	return _activate(&"choose_event_action", [id, options.duplicate(true)])

func _shop_command(action: StringName, gate: String, args: Array = []) -> Dictionary:
	if _flow.screen_state != "SHOP_PREPARE":
		return _rejected("wrong_state")
	if not _shop_controls()[gate]:
		return _rejected("shop_input_blocked")
	return _activate(action, args)

func _activate(action: StringName, args: Array) -> Dictionary:
	if _dispatching:
		return _rejected("shop_command_in_progress")
	_dispatching = true
	var result: Dictionary = _dispatch.call(action, args)
	_dispatching = false
	return result

func _rejected(error: String) -> Dictionary:
	return {"ok": false, "error": error}
