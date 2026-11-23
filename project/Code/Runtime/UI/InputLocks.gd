extends Node2D
## Each control retains its initial filter until its last source releases it.

signal inputs_blocked
enum Source {
	Inactive = 0, SceneSwitch = 1, Popup = 2, Fusing = 4, Lobby = 8,
	CombatUI = 16, PopupAnimation = 32, Scoreboard = 64, BoxSelect = 128,
	ItemDragging = 256, LockedTooltip = 512, Expedition = 1024, Streaming = 2048,
	Cinematic = 4096
}
@onready var rect = $Rect
var curSources = Source.Inactive
var mouseFilters: Dictionary = {}
var disableSources: Dictionary = {}

func activate(source, disable_tree_controls = true):
	if curSources == Source.Inactive:
		rect.show()
		inputs_blocked.emit()
	curSources |= source
	if disable_tree_controls:
		disableAllControls(source, Game.mainNode)

func deactivate(source, restore_tree_controls = true):
	curSources &= ~source
	if curSources == Source.Inactive:
		rect.hide()
	if restore_tree_controls:
		restoreAllControls(source)

func isActive():
	return rect.visible

func isOnlySourceActive(source: int) -> bool:
	return curSources == source

func _reset_hover(node):
	if node.visible:
		node.hide()
		node.show()

func _walk(root: Node, operation: Callable):
	var pending = root.get_children()
	pending.reverse()
	while not pending.is_empty():
		var node = pending.pop_back()
		if node is Control:
			operation.call(node)
		var children = node.get_children()
		children.reverse()
		pending.append_array(children)

func disableAllControls(source, root):
	_reset_hover(root)
	disableAllControls_traverse(source, root)

func disableAllControls_traverse(source, root):
	_walk(root, func(control): disableControl(source, control))

func disableControl(source: int, control: Control):
	if not mouseFilters.has(control):
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		mouseFilters[control] = control.mouse_filter
		disableSources[control] = 0
	disableSources[control] |= source
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func disableSingleControl(source: int, control: Control):
	_reset_hover(control)
	disableControl(source, control)

func restoreControl(source, control: Control):
	if not is_instance_valid(control) or not disableSources.has(control):
		return
	disableSources[control] &= ~source
	if disableSources[control] == 0:
		control.mouse_filter = mouseFilters[control]
		disableSources.erase(control)
		mouseFilters.erase(control)

func restoreAllControls(source: int):
	for control in disableSources.keys():
		if is_instance_valid(control):
			restoreControl(source, control)
		else:
			disableSources.erase(control)
			mouseFilters.erase(control)

func enableControls(source, root):
	_walk(root, func(control): restoreControl(source, control))

func onMouseFilterChanged(control, filter):
	if mouseFilters.has(control):
		mouseFilters[control] = filter

func setMouseFilter(control, filter):
	control.mouse_filter = filter
	onMouseFilterChanged(control, filter)
