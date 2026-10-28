extends Control
class_name ResizableControl

signal drag_start
signal drag_end

@onready var vResizeButton: Button = get_node_or_null("VerticalResizeButton")
@onready var hResizeButton: Button = get_node_or_null("HorizontalResizeButton")
@export var draggable = false

var dragPosition = null
var verticalResizing = false
var horizontalResizing = false
var resizeOffset = null
var dragging = false
var movedDuringDrag = false
var globalDragStartPosition: Vector2

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/ResizableControlBehavior.gd")._ready(self)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(visible)

func _process(delta):
	return load("res://Runtime/Behavior/Interface/ResizableControlBehavior.gd")._process(self, delta)

func startDragging():

	movedDuringDrag = false
	globalDragStartPosition = global_position
	dragPosition = get_global_mouse_position() - global_position
	set_process(true)

func endDragging():
	dragPosition = null
	set_process(false)

func canDrag():
	return true

func _input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Interface/ResizableControlBehavior.gd")._input(self, event)

func onVerticalResizeButtonDown():
	if dragging: return
	verticalResizing = true
	resizeOffset = (global_position + size) - (get_global_mouse_position())
	set_process(true)

func onVerticalResizeButtonUp():
	if not verticalResizing: return
	verticalResizing = false
	set_process(false)

func onHorizontalResizeButtonDown() -> void :
	if dragging: return
	horizontalResizing = true
	resizeOffset = (global_position + size) - (get_global_mouse_position())
	set_process(true)

func onHorizontalResizeButtonUp() -> void :
	if not horizontalResizing: return
	horizontalResizing = false
	set_process(false)
