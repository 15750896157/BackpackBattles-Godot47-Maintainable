class_name RewardDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var pick_count: int:
	get: return int(get_value("pick_count", 0))
	set(_unused): push_error("只读内容定义不能修改 pick_count")
var choice_count: int:
	get: return int(get_value("choice_count", 0))
	set(_unused): push_error("只读内容定义不能修改 choice_count")
var allow_skip: bool:
	get: return bool(get_value("allow_skip", false))
	set(_unused): push_error("只读内容定义不能修改 allow_skip")
