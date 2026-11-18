extends "res://Runtime/ViewModel/ViewModel.gd"
## Project only the title data. The host supplies the locale, input policy and actions.

var _saves: SaveService
var _content: ContentDB
var _read_locale: Callable
var _can_interact: Callable
var _dispatch: Callable
var _state: Dictionary = {}
var _dispatching := false
var _save_refresh_pending := false

func _init(saves: SaveService, content: ContentDB, read_locale: Callable, can_interact: Callable, dispatch: Callable) -> void:
	_saves = saves
	_content = content
	_read_locale = read_locale
	_can_interact = can_interact
	_dispatch = dispatch
	refresh()

func snapshot() -> Dictionary:
	return _state.duplicate()

func observe_run_saves() -> void:
	if not _saves.run_saved.is_connected(_schedule_save_refresh):
		_saves.run_saved.connect(_schedule_save_refresh)
	refresh()

func stop_observing_run_saves() -> void:
	if _saves.run_saved.is_connected(_schedule_save_refresh):
		_saves.run_saved.disconnect(_schedule_save_refresh)
	_save_refresh_pending = false

func _schedule_save_refresh() -> void:
	if _save_refresh_pending:
		return
	_save_refresh_pending = true
	_apply_saved_run.call_deferred()

func _apply_saved_run() -> void:
	if not _save_refresh_pending:
		return
	_save_refresh_pending = false
	refresh()

func refresh() -> void:
	var saved := _saves.load_save("run")
	var character_id := ""
	if saved.ok:
		var run: Dictionary = saved.data
		if run.get("last_safe_state", run.get("state", "")) != "RUN_RESULT" and _saves.validate_run(run, _content).ok:
			character_id = str(run.character_id)
	var next := {
		"can_continue": not character_id.is_empty(),
		"character_id": character_id,
		"locale": str(_read_locale.call()),
	}
	if next != _state:
		_state = next
		changed.emit()

func start_or_continue() -> bool:
	return _activate(&"primary")

func start_new_run() -> bool:
	return _activate(&"new_run")

func open_settings() -> bool:
	return _activate(&"settings")

func open_codex() -> bool:
	return _activate(&"codex")

func quit_game() -> bool:
	return _activate(&"quit")

func _activate(action: StringName) -> bool:
	if _dispatching or not bool(_can_interact.call()):
		return false
	_dispatching = true
	if action == &"primary":
		refresh()
		action = &"continue_run" if _state.can_continue else &"new_run"
		# A changed subscriber may have started a transition during refresh.
		if not bool(_can_interact.call()):
			_dispatching = false
			return false
	_dispatch.call(action)
	_dispatching = false
	return true
