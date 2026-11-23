extends Node
## Asynchronous transactions with synchronous admission. Production wiring is separate.
signal screen_changed(screen_id: StringName)
signal request_finished(request_id: int, screen_id: StringName, error: int)
signal phase_changed(request_id: int, phase: StringName)

class Lease extends RefCounted:
	var node: Node
	var spec: Dictionary
	var scope = ""
	var owned = false
	var released = false
	var was_visible = false
	var was_process_mode = Node.PROCESS_MODE_INHERIT

class Request extends RefCounted:
	var id: int
	var screen: StringName
	var spec: Dictionary
	var options: Dictionary
	var scope = ""
	var cover_ticket = -1
	var lease: Lease
	var initial = false
	var committed = false
	var cancelled = false
	var done = false
	var scope_released = false
	var cancel_hook_called = false
	var prepare_started = false
	var phase: StringName = &"queued"

const MAX_RESULTS = 64
var current_screen_id: StringName = &""
var last_request_id = 0
var _enabled = false
var _stopped = false
var _registry: Dictionary = {}
var _stream: Node
var _layer: CanvasLayer
var _root: Node
var _tree: SceneTree
var _prefix = ""
var _pending: Request
var _active: Request
var _current_lease: Lease
var _current_options: Dictionary = {}
var _worker_running = false
var _pump_queued = false
var _committing = false
var _results: Dictionary = {}
var _result_order: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tree = get_tree()

func configure(stream: Node, layer: CanvasLayer, scene_root: Node) -> Error:
	if _stopped: return ERR_UNAVAILABLE
	if is_busy() or _current_lease != null: return ERR_BUSY
	if not is_instance_valid(stream) or not is_instance_valid(layer) or not is_instance_valid(scene_root): return ERR_INVALID_PARAMETER
	_stream = stream; _layer = layer; _root = scene_root
	_prefix = "router:" + str(get_instance_id()) + ":"
	return OK

## Scene preparation receives the unmounted node, options and ownership check.
## Release and cancel are synchronous hooks for state hosted outside that node.
func register_screen(screen_id: StringName, scene_path: String, dependencies: Array = [], prepare: Callable = Callable(), activate: Callable = Callable(), settle: Callable = Callable(), release: Callable = Callable(), cancel: Callable = Callable()) -> void:
	_registry[screen_id] = {"kind": "scene", "path": scene_path, "dependencies": dependencies.duplicate(),
		"prepare": prepare, "activate": activate, "settle": settle, "release": release, "cancel": cancel}

## prepare and settle may await and must honor the current predicate.
## Activation, release and cancellation are synchronous.
func register_branch(screen_id: StringName, carrier: Node, prepare: Callable = Callable(), activate: Callable = Callable(), release: Callable = Callable(), cancel: Callable = Callable(), settle: Callable = Callable()) -> void:
	_registry[screen_id] = {"kind": "branch", "carrier": weakref(carrier), "prepare": prepare, "activate": activate, "release": release, "cancel": cancel, "settle": settle}

## A native shell can register the branch already presented by its startup.
func adopt_initial_branch(screen_id: StringName) -> Error:
	if not _enabled or _stopped: return ERR_UNAVAILABLE
	if not _configured(): return ERR_UNCONFIGURED
	if is_busy() or _current_lease != null: return ERR_BUSY
	var spec: Dictionary = _registry.get(screen_id, {})
	if spec.get("kind") != "branch": return ERR_DOES_NOT_EXIST
	var carrier = spec.carrier.get_ref()
	if not is_instance_valid(carrier) or not carrier.is_inside_tree(): return ERR_DOES_NOT_EXIST
	_current_lease = Lease.new()
	_current_lease.node = carrier
	_current_lease.spec = spec.duplicate()
	current_screen_id = screen_id
	return OK

func is_registered(screen_id: StringName) -> bool:
	return _registry.has(screen_id)

func set_enabled(value: bool) -> Error:
	if _stopped: return ERR_UNAVAILABLE
	if _enabled == value: return OK
	_enabled = value
	if not value: cancel_current()
	return OK

func is_busy() -> bool:
	return _worker_running or _pump_queued or _pending != null

func get_current_node() -> Node:
	return _current_lease.node if _current_lease != null and is_instance_valid(_current_lease.node) else null

func _configured() -> bool:
	return is_inside_tree() and is_instance_valid(_stream) and is_instance_valid(_layer) and is_instance_valid(_root) and _root.is_inside_tree()

func change_scene(screen_id: StringName, options: Dictionary = {}) -> Error:
	return request_scene(screen_id, options).error

func _same_request(request: Request, screen: StringName, options: Dictionary) -> bool:
	return request != null and not request.done and request.screen == screen and request.options == options and not bool(options.get("force", false))

## OK means admitted, not completed. The returned id stays stable under reentrant signals.
func request_scene(screen_id: StringName, options: Dictionary = {}) -> Dictionary:
	if not _enabled or _stopped: return {"error": ERR_UNAVAILABLE, "id": 0}
	if not _registry.has(screen_id): return {"error": ERR_DOES_NOT_EXIST, "id": 0}
	if not _configured(): return {"error": ERR_UNCONFIGURED, "id": 0}
	if bool(_stream.get("stopping")): return {"error": ERR_UNAVAILABLE, "id": 0}
	var initial := bool(options.get("initial", false))
	if initial and (_current_lease != null or is_busy() or _registry[screen_id].kind != "scene"):
		return {"error": ERR_BUSY, "id": 0}
	if not is_busy() and _layer.busy: return {"error": ERR_BUSY, "id": 0}
	if _same_request(_pending, screen_id, options): return {"error": OK, "id": _pending.id}
	if _same_request(_active, screen_id, options): return {"error": OK, "id": _active.id}
	last_request_id += 1
	var request = Request.new()
	request.id = last_request_id; request.screen = screen_id; request.initial = initial
	request.spec = _registry[screen_id].duplicate(); request.options = options.duplicate(true)
	if not is_busy() and current_screen_id == screen_id and _current_options == options and not bool(options.get("force", false)):
		_complete(request, OK, false)
		return {"error": OK, "id": request.id}
	var replaced = _pending
	_pending = request
	if bool(request.options.get("keep_cover", false)):
		var previous = replaced if replaced != null and replaced.cover_ticket >= 0 else _active
		_transfer_cover(previous, request)
	if replaced != null: _cancel_request(replaced)
	if _active != null: _cancel_request(_active)
	_schedule_pump()
	return {"error": OK, "id": request.id}

func _schedule_pump():
	if _worker_running or _pump_queued: return
	_pump_queued = true
	call_deferred("_pump")

func _current(request: Request) -> bool:
	return _enabled and not _stopped and not request.cancelled and not request.done and request.id == last_request_id

func _phase(request: Request, value: StringName):
	request.phase = value
	phase_changed.emit(request.id, value)

func diagnostics() -> Dictionary:
	return {"current": current_screen_id, "busy": is_busy(), "active_id": _active.id if _active != null else 0,
		"pending_id": _pending.id if _pending != null else 0, "phase": _active.phase if _active != null else &"idle",
		"current_scope": _current_lease.scope if _current_lease != null else "", "resource_slots": [_prefix + "0", _prefix + "1"]}

func result(request_id: int) -> Dictionary:
	return _results.get(request_id, {}).duplicate()

func wait_for_request(request_id: int) -> int:
	while not _results.has(request_id):
		var known = (_active != null and _active.id == request_id) or (_pending != null and _pending.id == request_id)
		if not known: return ERR_DOES_NOT_EXIST
		await _tree.process_frame
	return int(_results[request_id].error)

func _complete(request: Request, error: int, notify_screen: bool = true):
	if request.done: return
	request.done = true
	_results[request.id] = {"id": request.id, "screen": request.screen, "error": error, "committed": request.committed}
	_result_order.append(request.id)
	while _result_order.size() > MAX_RESULTS: _results.erase(_result_order.pop_front())
	# Finalize before signals: a listener can immediately request the next screen.
	if error == OK and notify_screen: screen_changed.emit(request.screen)
	request_finished.emit(request.id, request.screen, error)

func _cancel_visual(request: Request):
	if request.cover_ticket >= 0 and is_instance_valid(_layer): _layer.cancel(request.cover_ticket)

func _transfer_cover(previous: Request, request: Request):
	if previous == null or previous.cover_ticket < 0: return
	if not _layer.covered or _layer.generation != previous.cover_ticket: return
	request.cover_ticket = previous.cover_ticket
	previous.cover_ticket = -1

func _abort_prepare(request: Request):
	if not request.prepare_started or request.committed or request.cancel_hook_called: return
	request.cancel_hook_called = true
	var callback: Callable = request.spec.cancel
	if callback.is_valid(): callback.call(request.options)

func _discard(request: Request):
	if request.committed or request.scope_released: return
	request.scope_released = true
	_abort_prepare(request)
	if request.lease != null:
		var lease = request.lease
		if is_instance_valid(lease.node):
			if lease.owned:
				if lease.node.get_parent() != null: lease.node.get_parent().remove_child(lease.node)
				lease.node.queue_free()
			else:
				lease.node.process_mode = lease.was_process_mode
				if lease.node is CanvasItem: lease.node.visible = lease.was_visible
		lease.released = true
		request.lease = null
	if not request.scope.is_empty(): _stream.release(request.scope)

func _cancel_request(request: Request):
	if request.done: return
	request.cancelled = true
	if not _committing or request != _active:
		_cancel_visual(request)
		_discard(request)
	_complete(request, ERR_SKIP)

func cancel_current():
	if _pending != null:
		var pending = _pending; _pending = null
		_cancel_request(pending)
	if _active != null: _cancel_request(_active)

func _cover_call(request: Request, state: Dictionary):
	state.ticket = await _layer.cover(str(request.options.get("reason", "route:" + str(request.screen))))
	state.done = true

func _prepare(request: Request) -> int:
	request.prepare_started = true
	var lease = Lease.new(); lease.spec = request.spec
	if request.spec.kind == "scene":
		# Two slots suffice: one committed lease and one prepared candidate.
		request.scope = _prefix + ("1" if _current_lease != null and _current_lease.scope == _prefix + "0" else "0")
		var paths: Array = [request.spec.path]
		paths.append_array(request.spec.dependencies)
		if not await _stream.prepare(paths, request.scope): return ERR_CANT_OPEN
		if not _current(request): return ERR_SKIP
		if not _stream.resources.get(request.spec.path) is PackedScene: return ERR_INVALID_DATA
		var node = await _stream.instantiate_path(request.spec.path, request.scope)
		if not _current(request):
			if is_instance_valid(node): node.free()
			return ERR_SKIP
		if node == null: return ERR_CANT_CREATE
		lease.node = node; lease.owned = true; lease.scope = request.scope
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem: node.hide()
		request.lease = lease
		var prepare_scene: Callable = request.spec.prepare
		if prepare_scene.is_valid() and not bool(await prepare_scene.call(node, request.options, _current.bind(request))):
			return ERR_CANT_CREATE
		if not _current(request): return ERR_SKIP
	else:
		lease.node = request.spec.carrier.get_ref()
		if not is_instance_valid(lease.node): return ERR_DOES_NOT_EXIST
		if _current_lease != null and _current_lease.owned and _current_lease.node == lease.node: return ERR_INVALID_PARAMETER
		lease.was_process_mode = lease.node.process_mode
		lease.was_visible = lease.node.visible if lease.node is CanvasItem else false
		request.lease = lease
		var callback: Callable = request.spec.prepare
		if callback.is_valid() and not bool(await callback.call(request.options, _current.bind(request))): return ERR_CANT_CREATE
		if not _current(request): return ERR_SKIP
	request.lease = lease
	return OK

func _retire(lease: Lease, keep_node: Node = null):
	if lease == null or lease.released: return
	lease.released = true
	if is_instance_valid(lease.node) and lease.node != keep_node:
		var callback: Callable = lease.spec.release
		if callback.is_valid(): callback.call(lease.node)
		if lease.owned:
			if lease.node.get_parent() != null: lease.node.get_parent().remove_child(lease.node)
			lease.node.queue_free()
		elif not callback.is_valid():
			lease.node.process_mode = Node.PROCESS_MODE_DISABLED
			if lease.node is CanvasItem: lease.node.hide()
	if not lease.scope.is_empty(): _stream.release(lease.scope)

func _commit(request: Request) -> int:
	if not _current(request): return ERR_SKIP
	_committing = true
	var lease = request.lease
	if lease.owned: _root.add_child(lease.node)
	# _ready may reenter the router. Defer disposal until add_child has returned.
	if not _current(request):
		_committing = false
		_discard(request); _cancel_visual(request)
		return ERR_SKIP
	var previous = _current_lease
	_current_lease = lease; current_screen_id = request.screen; _current_options = request.options.duplicate(true)
	request.committed = true
	var callback: Callable = request.spec.get("activate", Callable())
	if callback.is_valid(): callback.call(lease.node, request.options)
	else:
		lease.node.process_mode = Node.PROCESS_MODE_INHERIT
		if lease.node is CanvasItem: lease.node.show()
	_retire(previous, lease.node)
	_committing = false
	if not _current(request): _cancel_visual(request)
	return OK

func _fail(request: Request, error: int) -> int:
	_discard(request)
	if _current(request) and request.cover_ticket >= 0 and _layer.generation == request.cover_ticket:
		await _layer.reveal(request.cover_ticket)
	return error if _current(request) else ERR_SKIP

func _drive(request: Request) -> int:
	if not _current(request): return ERR_SKIP
	if request.initial:
		# The shell already covers initial loading with its startup overlay.
		pass
	elif request.cover_ticket < 0:
		if _layer.busy: return ERR_BUSY
		_phase(request, &"covering")
		if not _current(request): return ERR_SKIP
		var cover = {"done": false, "ticket": -1}
		_cover_call(request, cover)
		request.cover_ticket = _layer.generation if _layer.busy else -1
		if not _current(request): _cancel_visual(request)
		while not cover.done: await _tree.process_frame
		if not _current(request): return ERR_SKIP
		request.cover_ticket = int(cover.ticket)
		if request.cover_ticket < 0: return ERR_UNAVAILABLE
	elif not _layer.covered or _layer.generation != request.cover_ticket:
		return ERR_SKIP
	_phase(request, &"preparing")
	if not _current(request): return ERR_SKIP
	var error = await _prepare(request)
	if error != OK: return await _fail(request, error)
	_phase(request, &"prepared")
	await _tree.process_frame
	if not _current(request): return ERR_SKIP
	error = _commit(request)
	if error != OK: return await _fail(request, error)
	if not _current(request): return ERR_SKIP
	var settle: Callable = request.spec.get("settle", Callable())
	if settle.is_valid():
		_phase(request, &"settling")
		if not _current(request): return ERR_SKIP
		var ready = await settle.call(request.options, _current.bind(request))
		if not _current(request): return ERR_SKIP
		if not ready: return await _fail(request, ERR_CANT_CREATE)
	if request.initial: return OK
	_phase(request, &"revealing")
	if not _current(request): return ERR_SKIP
	await _layer.reveal(request.cover_ticket)
	if not _current(request): return ERR_SKIP
	if _layer.generation != request.cover_ticket or _layer.busy: return ERR_SKIP
	return OK

func _pump():
	_pump_queued = false
	if _worker_running: return
	_worker_running = true
	while _enabled and not _stopped and _pending != null:
		_active = _pending; _pending = null
		var error = await _drive(_active)
		if error != OK: _cancel_visual(_active)
		_discard(_active)
		_complete(_active, error)
		_active = null
	_worker_running = false
	if _stopped:
		_retire(_current_lease); _current_lease = null; current_screen_id = &""

func shutdown():
	if _stopped: return
	_stopped = true; _enabled = false
	cancel_current()
	if not _committing:
		_retire(_current_lease); _current_lease = null; current_screen_id = &""

func _process(_delta):
	if _enabled and is_instance_valid(_stream) and bool(_stream.get("stopping")): shutdown()

func _exit_tree():
	shutdown()
