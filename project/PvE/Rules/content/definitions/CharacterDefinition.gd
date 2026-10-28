class_name CharacterDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var max_health: float:
	get: return float(get_value("max_health", 0))
	set(_unused): push_error("只读内容定义不能修改 max_health")
var starting_health: float:
	get: return float(get_value("starting_health", 0))
	set(_unused): push_error("只读内容定义不能修改 starting_health")
var stamina_max: float:
	get: return float(get_value("stamina_max", 0))
	set(_unused): push_error("只读内容定义不能修改 stamina_max")
var passive_id: String:
	get: return String(get_value("passive_id", ""))
	set(_unused): push_error("只读内容定义不能修改 passive_id")
var stamina_regen_per_sec: float:
	get: return float(get_value("stamina_regen_per_sec", 0))
	set(_unused): push_error("只读内容定义不能修改 stamina_regen_per_sec")
