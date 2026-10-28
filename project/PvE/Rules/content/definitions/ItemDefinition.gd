class_name ItemDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var base_price: int:
	get: return int(get_value("base_price", 0))
	set(_unused): push_error("只读内容定义不能修改 base_price")
var owner_pool: String:
	get: return String(get_value("owner_pool", ""))
	set(_unused): push_error("只读内容定义不能修改 owner_pool")
var icon_ref: String:
	get: return String(get_value("icon_ref", ""))
	set(_unused): push_error("只读内容定义不能修改 icon_ref")
var cooldown: float:
	get: return float(get_value("cooldown", 0))
	set(_unused): push_error("只读内容定义不能修改 cooldown")
var vfx_ref: String:
	get: return String(get_value("vfx_ref", ""))
	set(_unused): push_error("只读内容定义不能修改 vfx_ref")
var shape_id: String:
	get: return String(get_value("shape_id", ""))
	set(_unused): push_error("只读内容定义不能修改 shape_id")
var rarity: String:
	get: return String(get_value("rarity", ""))
	set(_unused): push_error("只读内容定义不能修改 rarity")
var stamina_cost: float:
	get: return float(get_value("stamina_cost", 0))
	set(_unused): push_error("只读内容定义不能修改 stamina_cost")
