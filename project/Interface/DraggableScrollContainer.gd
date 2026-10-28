extends ScrollContainer

signal zoomed

const SCROLL_SPEED = 10.0

@export var margin = 2
@export var detectZoom = false
@export var scrollEnabled = true

var scrollbarHovered = false

@onready var scrollBar = get_v_scroll_bar()

func _ready():
	return load("res://Runtime/Behavior/Features/Interface/DraggableScrollContainerBehavior.gd")._ready(self)

func onScrollbarHover():
	scrollbarHovered = true

	set_process(true)

func onScrollbarHoverEnd():
	scrollbarHovered = false

	set_process(false)

func _process(delta):
	return load("res://Runtime/Behavior/Features/Interface/DraggableScrollContainerBehavior.gd")._process(self, delta)

func onOpen():
	set_physics_process(true)
	if detectZoom:
		set_process_input(true)

func onClose():
	set_physics_process(false)
	set_process_input(false)

func _input(event):
	return load("res://Runtime/Behavior/Features/Interface/DraggableScrollContainerBehavior.gd")._input(self, event)

func _physics_process(delta):
	if is_visible_in_tree() and scrollEnabled:
		var scroll = Input.get_axis("shift_up_controller", "shift_down_controller")
		scrollBar.value += scroll * SCROLL_SPEED
