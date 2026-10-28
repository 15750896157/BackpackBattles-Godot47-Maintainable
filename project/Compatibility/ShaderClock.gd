extends Node

var _elapsed: float = 0.0
var _scale: float = 1.0
var _last_tick: int = 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_tick = Time.get_ticks_usec()
func _process(_delta: float) -> void:
	load("res://Runtime/Callbacks/Compatibility/CallbacksS.gd").ForShaderClock._process(self, _delta)

func set_scale(value: float) -> void:
	_scale = maxf(value, 0.0)
func get_scale() -> float: return _scale
