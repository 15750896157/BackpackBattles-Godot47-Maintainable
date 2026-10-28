extends Area2D

func _ready():
	onTitleEntered()
	Game.connect("title_to_shop", Callable(self, "onTitleLeft"))
	Game.connect("returned_to_title", Callable(self, "onTitleEntered"))

func onTitleEntered():
	Util.tryConnect(self, "body_entered", self, "onBodyEntered")
	set_physics_process(true)

func onTitleLeft():
	Util.tryDisconnect(self, "body_entered", self, "onBodyEntered")
	set_physics_process(false)

func _physics_process(delta):
	global_position = Util.getMousePosInWindow() + Vector2(8, 15)

func onBodyEntered(body):
	return load("res://Runtime/Callbacks/Items/CallbacksI.gd").ForItemPushZone.onBodyEntered(self, body)

