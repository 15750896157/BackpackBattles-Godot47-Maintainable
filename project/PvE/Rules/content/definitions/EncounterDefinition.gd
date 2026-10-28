class_name EncounterDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var enemy_build_pool: String:
	get: return String(get_value("enemy_build_pool", ""))
	set(_unused): push_error("只读内容定义不能修改 enemy_build_pool")
var reward_table_id: String:
	get: return String(get_value("reward_table_id", ""))
	set(_unused): push_error("只读内容定义不能修改 reward_table_id")
var node_type: String:
	get: return String(get_value("node_type", ""))
	set(_unused): push_error("只读内容定义不能修改 node_type")
var act_id: String:
	get: return String(get_value("act_id", ""))
	set(_unused): push_error("只读内容定义不能修改 act_id")
