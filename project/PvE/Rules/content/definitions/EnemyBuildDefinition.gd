class_name EnemyBuildDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var stamina_max: float:
	get: return float(get_value("stamina_max", 0))
	set(_unused): push_error("只读内容定义不能修改 stamina_max")
var node_type: String:
	get: return String(get_value("node_type", ""))
	set(_unused): push_error("只读内容定义不能修改 node_type")
var stamina_regen: float:
	get: return float(get_value("stamina_regen", 0))
	set(_unused): push_error("只读内容定义不能修改 stamina_regen")
var max_health: float:
	get: return float(get_value("max_health", 0))
	set(_unused): push_error("只读内容定义不能修改 max_health")
var act_id: String:
	get: return String(get_value("act_id", ""))
	set(_unused): push_error("只读内容定义不能修改 act_id")
