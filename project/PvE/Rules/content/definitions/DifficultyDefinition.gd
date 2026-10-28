class_name DifficultyDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var sort_order: int:
	get: return int(get_value("sort_order", 0))
	set(_unused): push_error("只读内容定义不能修改 sort_order")
var gold_reward_scalar: float:
	get: return float(get_value("gold_reward_scalar", 0))
	set(_unused): push_error("只读内容定义不能修改 gold_reward_scalar")
var enemy_status_scalar: float:
	get: return float(get_value("enemy_status_scalar", 0))
	set(_unused): push_error("只读内容定义不能修改 enemy_status_scalar")
var enemy_health_scalar: float:
	get: return float(get_value("enemy_health_scalar", 0))
	set(_unused): push_error("只读内容定义不能修改 enemy_health_scalar")
var enemy_damage_scalar: float:
	get: return float(get_value("enemy_damage_scalar", 0))
	set(_unused): push_error("只读内容定义不能修改 enemy_damage_scalar")
