extends "res://Code/Runtime/ViewModel/ViewModel.gd"
## Projects the existing CombatEngine result. The owner replaces the result as
## a whole and advances the authoritative GameFlow clock.

signal screen_action_requested(action: StringName)

var _frames: Array = []
var _events: Array = []
var _activation_times: Dictionary = {}
var _duration := 0.0
var _playback_time := 0.0
var _next_event := 0
var _screen_state: Dictionary = {}
var _screen_revision := 0

func load_result(result: Dictionary) -> void:
	_frames = result.get("timeline", [])
	_events = result.get("full_events", [])
	_duration = float(result.get("elapsed_time", 0.0))
	_playback_time = 0.0
	_next_event = 0
	if not _screen_state.is_empty():
		_screen_state.clear()
		_screen_revision += 1
	_activation_times.clear()
	for event: Dictionary in _events:
		if event.type != "ITEM_ACTIVATED":
			continue
		var key := _item_key(int(event.source_side), str(event.source))
		if not _activation_times.has(key):
			_activation_times[key] = []
		_activation_times[key].append(float(event.time))
	changed.emit()

func set_playback_time(time: float) -> void:
	if time == _playback_time:
		return
	_playback_time = time
	changed.emit()

func snapshot() -> Dictionary:
	return {
		"playback_time": _playback_time,
		"elapsed_time": _duration,
		"frame": frame_at(_playback_time),
	}

func set_screen_state(state: Dictionary) -> void:
	if _screen_state == state:
		return
	_screen_state = state.duplicate(true)
	_screen_revision += 1
	changed.emit()

func screen_revision() -> int:
	return _screen_revision

func screen_state() -> Dictionary:
	return _screen_state.duplicate(true)

func request_screen_action(action: StringName) -> void:
	if not _screen_state.is_empty() and action in [&"pause_play", &"speed", &"settings"]:
		screen_action_requested.emit(action)

func frame_at(time: float) -> Dictionary:
	if _frames.is_empty():
		return {}
	var frame: Dictionary = _frames[maxi(0, _after_time(_frames, time) - 1)]
	return frame.duplicate(true)

func next_event_index() -> int:
	return _next_event

func reset_event_cursor(index: int = 0) -> void:
	_next_event = clampi(index, 0, _events.size())

func sync_event_cursor(time: float) -> void:
	_next_event = _after_time(_events, time)

func consume_events_through(time: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	while _next_event < _events.size() and float(_events[_next_event].time) <= time:
		var event: Dictionary = _events[_next_event]
		_next_event += 1
		due.append(event.duplicate(true))
	return due

func cooldown_fraction(side: int, item_uid: String, time: float) -> float:
	var times: Array = _activation_times.get(_item_key(side, item_uid), [])
	var index := times.bsearch(time, false)
	if index >= times.size():
		return 0.0
	var previous := float(times[index - 1]) if index > 0 else 0.0
	var next := float(times[index])
	return clampf((next - time) / maxf(0.05, next - previous), 0.0, 1.0)

static func _item_key(side: int, uid: String) -> String:
	return str(side) + ":" + uid

## Upper bound retains engine order among samples and events with equal times.
static func _after_time(rows: Array, time: float) -> int:
	var low := 0
	var high := rows.size()
	while low < high:
		var middle := low + ((high - low) >> 1)
		if float(rows[middle].time) <= time:
			low = middle + 1
		else:
			high = middle
	return low
