extends RefCounted
## Shell boundary. Cancellation and input release are synchronous and ticket-scoped.
func is_stopping() -> bool:
	return false
func appearance() -> Dictionary:
	return {"reduce_motion": false, "reduce_flash": false}
func fade_targets() -> Array:
	return []
func before_cover() -> void:
	pass
func acquire_input() -> void:
	pass
func release_input() -> void:
	pass
func begin_loading(_reason: String, _current: Callable) -> int:
	return -1
func finish_loading(_ticket: int) -> void:
	pass
func cancel_loading(_ticket: int) -> void:
	pass
