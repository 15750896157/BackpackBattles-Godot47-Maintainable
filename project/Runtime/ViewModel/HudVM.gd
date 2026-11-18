extends "res://Runtime/ViewModel/ViewModel.gd"
## Projects shared HUD text and owns the lifetime of transient notices.

var _translate: Callable
var _status := ""
var _notice := ""
var _remaining := 0.0

func _init(translate: Callable) -> void:
	_translate = translate

func snapshot() -> Dictionary:
	return {"status": _status, "notice": _notice}

func update_status(run: Dictionary, displayed_health: float) -> void:
	var value := str(_translate.call("ui.run_header", {
		"act": int(run.act), "step": int(run.step),
		"hp": ceili(displayed_health), "max_hp": ceili(float(run.max_health)),
		"gold": int(run.gold),
	}))
	if value == _status:
		return
	_status = value
	changed.emit()

func show_notice(text: String) -> void:
	_remaining = 5.0
	_notice = text
	changed.emit()

func clear_notice() -> void:
	_remaining = 0.0
	if not _notice.is_empty():
		_notice = ""
		changed.emit()

func advance(delta: float) -> void:
	if _remaining > 0.0:
		_remaining -= delta
		if _remaining <= 0.0:
			clear_notice()

func notice_time() -> float:
	return _remaining
