extends SceneTree
class VM extends RefCounted:
	func snapshot()->Dictionary:
		push_error("EXPECTED_VM_BASE_SNAPSHOT")
		return {}
func _initialize():
	var value=VM.new().snapshot()
	print("RETURNED_EMPTY=",value.is_empty())
	quit(0)
