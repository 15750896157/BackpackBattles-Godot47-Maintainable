extends ProgressBar

func _ready():

	set_process(false)

func _process(delta):
	load("res://Runtime/Callbacks/Interface/Combat/CallbacksC.gd").ForCombatTugBar._process(self, delta)

func onCombatStart():
	set_process(true)

func onCombatEnd(result):
	set_process(false)
