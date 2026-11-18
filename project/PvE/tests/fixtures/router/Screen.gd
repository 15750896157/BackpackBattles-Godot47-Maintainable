extends Node2D
@export var marker = ""
@export var redirect_on_ready = false
var created_on_main_thread = false
var created_frame = -1

func _init():
	created_on_main_thread = Thread.is_main_thread()
	created_frame = Engine.get_process_frames()

func _ready():
	if redirect_on_ready:
		var router = get_parent().get_meta("router_kernel")
		get_parent().set_meta("redirect_was_hidden", not visible)
		get_parent().set_meta("redirect_previous", router.current_screen_id)
		get_parent().set_meta("redirect_handle", router.request_scene(&"branch_b", {"ready_redirect": true}))
