extends Label

func _ready():
	Game.connect("trophies_changed", Callable(self, "updateValue"))
	updateValue()

func updateValue():
	text = str(Game.getTrophies())
