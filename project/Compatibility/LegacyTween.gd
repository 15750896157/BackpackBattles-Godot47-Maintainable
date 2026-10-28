extends Node
class_name LegacyTween

signal tween_completed(object: Object, key: NodePath)
signal tween_all_completed
var _jobs: Array[Dictionary] = []
var _tween: Tween
var playback_speed: float = 1.0
func interpolate_property(object: Object, property: NodePath, initial_value, final_value, duration: float, transition: int = Tween.TRANS_LINEAR, ease: int = Tween.EASE_IN_OUT, delay: float = 0.0) -> bool:
	return load("res://Runtime/Behavior/Compatibility/LegacyTweenBehavior.gd").interpolate_property(self, object, property, initial_value, final_value, duration, transition, ease, delay)

func interpolate_method(object: Object, method: String, initial_value, final_value, duration: float, transition: int = Tween.TRANS_LINEAR, ease: int = Tween.EASE_IN_OUT, delay: float = 0.0) -> bool:
	return load("res://Runtime/Behavior/Compatibility/LegacyTweenBehavior.gd").interpolate_method(self, object, method, initial_value, final_value, duration, transition, ease, delay)

func start() -> bool:
	return load("res://Runtime/Behavior/Compatibility/LegacyTweenBehavior.gd").start(self)

func stop_all() -> bool:
	if _tween and _tween.is_valid(): _tween.kill()
	_tween = null
	return true
func remove_all() -> void:
	stop_all()
	_jobs.clear()
func is_active() -> bool: return _tween != null and _tween.is_running()
func set_speed_scale(value: float) -> void:
	playback_speed = value
	if _tween and _tween.is_valid(): _tween.set_speed_scale(value)
