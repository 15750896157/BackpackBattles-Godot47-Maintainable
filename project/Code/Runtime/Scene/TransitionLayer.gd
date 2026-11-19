extends CanvasLayer
## One persistent visual barrier, driven only through its injected context.
const Context = preload("res://Code/Runtime/Scene/TransitionContext.gd")
var busy = false
var covered = false
var revealing = false
var generation = 0
var loading_ticket = -1
var faded: Array = []
var history: Array = []
var _context: Context
var _input_held = false
var _stopped = false
@onready var overlay: TextureRect = $Cloud
@onready var veil: ColorRect = $Veil

func configure(context: Context) -> Error:
	if busy: return ERR_BUSY
	_context = context
	return OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	veil.hide()

func _available() -> bool:
	return is_inside_tree() and not _stopped and _context != null and not _context.is_stopping()

func _owns(ticket: int) -> bool:
	return is_inside_tree() and not _stopped and busy and ticket == generation

func _running(ticket: int) -> bool:
	if not _owns(ticket): return false
	if _context.is_stopping():
		shutdown()
		return false
	return true

func cover(reason: String = "scene") -> int:
	# Coalesce a cover; wait for an ongoing reveal without recursive retry.
	while busy:
		if not _available():
			shutdown()
			return -1
		if covered: return generation
		await get_tree().process_frame
	if not _available(): return -1
	generation += 1
	var ticket = generation
	busy = true
	covered = false
	_context.before_cover()
	_input_held = true
	_context.acquire_input()
	overlay.material.set_shader_parameter("uncover", false)
	overlay.material.set_shader_parameter("coverage", 0.0)
	overlay.show()
	veil.show()
	var started_loading = await _context.begin_loading(reason, _running.bind(ticket))
	if not _running(ticket):
		_context.cancel_loading(started_loading)
		return -1
	loading_ticket = started_loading
	if loading_ticket < 0:
		cancel(ticket)
		return -1
	var options = _context.appearance()
	var reduced = bool(options.get("reduce_motion", false))
	overlay.material.set_shader_parameter("reduced_motion", reduced)
	overlay.material.set_shader_parameter("reduced_flash", bool(options.get("reduce_flash", false)))
	_remember_targets(false)
	var duration = 0.13 if reduced else 0.40
	if not await _advance(duration, false, ticket): return -1
	covered = true
	history.append({"phase": "covered", "reason": reason, "ticket": ticket, "duration": duration, "time_ms": Time.get_ticks_msec()})
	return ticket

func reveal(ticket: int):
	if not _running(ticket) or revealing: return
	revealing = true
	covered = false
	_restore_targets()
	_remember_targets(true)
	var reduced = bool(_context.appearance().get("reduce_motion", false))
	var duration = 0.16 if reduced else 0.52
	overlay.material.set_shader_parameter("uncover", true)
	overlay.material.set_shader_parameter("coverage", 0.0)
	if not await _advance(duration, true, ticket): return
	overlay.hide()
	veil.hide()
	await _context.finish_loading(loading_ticket)
	if not _running(ticket): return
	busy = false
	covered = false
	revealing = false
	loading_ticket = -1
	_release_input()
	history.append({"phase": "revealed", "ticket": ticket, "duration": duration, "time_ms": Time.get_ticks_msec()})
	faded.clear()

func _remember_targets(entering: bool) -> void:
	faded.clear()
	for node in _context.fade_targets():
		if not is_instance_valid(node) or not node is CanvasItem: continue
		faded.append([weakref(node), node.modulate])
		if entering: node.modulate.a = 0.0

func _restore_targets() -> void:
	for record in faded:
		var node = record[0].get_ref()
		if is_instance_valid(node): node.modulate = record[1]
	faded.clear()

func _advance(duration: float, entering: bool, ticket: int) -> bool:
	var elapsed = 0.0
	var previous = Time.get_ticks_usec()
	while elapsed < duration:
		if not _running(ticket): return false
		await get_tree().process_frame
		if not _running(ticket): return false
		var now = Time.get_ticks_usec()
		# Preserve the existing clamp: a loading stall cannot skip the wipe.
		elapsed += clampf(float(now - previous) / 1000000.0, 0.001, 1.0 / 40.0)
		previous = now
		var value = clampf(elapsed / duration, 0.0, 1.0)
		overlay.material.set_shader_parameter("coverage", value)
		veil.color.a = (1.0 - value) * 0.25 if entering else value * 0.25
		for record in faded:
			var node = record[0].get_ref()
			if is_instance_valid(node): node.modulate.a = value if entering else 1.0 - value
	return true

func _release_input() -> void:
	if not _input_held: return
	_input_held = false
	_context.release_input()

func cancel(ticket: int) -> bool:
	if not busy or ticket != generation: return false
	# Invalidate suspended work before invoking cleanup callbacks.
	generation += 1
	_restore_targets()
	if is_instance_valid(overlay): overlay.hide()
	if is_instance_valid(veil): veil.hide()
	_context.cancel_loading(loading_ticket)
	loading_ticket = -1
	busy = false
	covered = false
	revealing = false
	_release_input()
	history.append({"phase": "cancelled", "ticket": ticket, "time_ms": Time.get_ticks_msec()})
	return true

func shutdown() -> void:
	if _stopped: return
	_stopped = true
	cancel(generation)
	_release_input()

func _exit_tree() -> void:
	shutdown()
