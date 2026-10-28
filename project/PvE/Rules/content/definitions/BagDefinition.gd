class_name BagDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var shape_id: String:
	get: return String(get_value("shape_id", ""))
	set(_unused): push_error("只读内容定义不能修改 shape_id")
var special_cell_type: String:
	get: return String(get_value("special_cell_type", ""))
	set(_unused): push_error("只读内容定义不能修改 special_cell_type")
var base_price: int:
	get: return int(get_value("base_price", 0))
	set(_unused): push_error("只读内容定义不能修改 base_price")
var special_effect: String:
	get: return String(get_value("special_effect", ""))
	set(_unused): push_error("只读内容定义不能修改 special_effect")
var icon_ref: String:
	get: return String(get_value("icon_ref", ""))
	set(_unused): push_error("只读内容定义不能修改 icon_ref")
