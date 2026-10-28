class_name RecipeDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var tier: int:
	get: return int(get_value("tier", 0))
	set(_unused): push_error("只读内容定义不能修改 tier")
var result_item_id: String:
	get: return String(get_value("result_item_id", ""))
	set(_unused): push_error("只读内容定义不能修改 result_item_id")
var manual_confirm: bool:
	get: return bool(get_value("manual_confirm", false))
	set(_unused): push_error("只读内容定义不能修改 manual_confirm")
var placement_rule: String:
	get: return String(get_value("placement_rule", ""))
	set(_unused): push_error("只读内容定义不能修改 placement_rule")
