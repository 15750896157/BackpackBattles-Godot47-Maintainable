extends Timer

signal multi_timeout

var timestamps = []

func _ready():
	one_shot = true
	process_callback = Timer.TIMER_PROCESS_PHYSICS
	connect("timeout", Callable(self, "onTimeout"))

func start(time: float = - 1):
	if is_stopped():
		super.start(time)
	else:
		timestamps.push_back(Util.time + time)

func stop():
	timestamps.clear()
	super.stop()

func isFinished() -> bool:
	return timestamps.is_empty()

func onTimeout():
	return load("res://Runtime/Callbacks/Utility/CallbacksM.gd").ForMultiTimer.onTimeout(self)

