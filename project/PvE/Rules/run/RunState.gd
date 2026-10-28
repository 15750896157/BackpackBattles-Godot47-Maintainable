class_name RunState
extends RefCounted

var data: Dictionary = {}

func _init(initial: Dictionary = {}):
	data = initial.duplicate(true)

func to_dto() -> Dictionary:
	return data.duplicate(true)

func fingerprint() -> String:
	return JSON.stringify(data, "", true).sha256_text()
