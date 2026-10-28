class_name EventDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var act_min: int:
	get: return int(get_value("act_min", 0))
	set(_unused): push_error("只读内容定义不能修改 act_min")
var act_max: int:
	get: return int(get_value("act_max", 0))
	set(_unused): push_error("只读内容定义不能修改 act_max")
var weight: float:
	get: return float(get_value("weight", 0))
	set(_unused): push_error("只读内容定义不能修改 weight")
