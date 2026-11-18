extends ViewModel
## Values and persistence belong to the native preferences service.
var _service

func _init(service) -> void:
	_service = service

func snapshot() -> Dictionary:
	return _service.values.duplicate(true)

func set_option(key: String, value: Variant) -> void:
	if _service.set_option(key, value):
		changed.emit()

func set_volume(key: String, ratio: float) -> void:
	if _service.set_volume(key, ratio):
		changed.emit()
