class_name StatusDefinition
extends "res://PvE/Rules/content/definitions/ContentDefinition.gd"

var stack_cap: int:
	get: return int(get_value("stack_cap", 0))
	set(_unused): push_error("只读内容定义不能修改 stack_cap")
var default_duration: float:
	get: return float(get_value("default_duration", 0))
	set(_unused): push_error("只读内容定义不能修改 default_duration")
var polarity: String:
	get: return String(get_value("polarity", ""))
	set(_unused): push_error("只读内容定义不能修改 polarity")
var tick_rule: String:
	get: return String(get_value("tick_rule", ""))
	set(_unused): push_error("只读内容定义不能修改 tick_rule")
var decay_rule: String:
	get: return String(get_value("decay_rule", ""))
	set(_unused): push_error("只读内容定义不能修改 decay_rule")
var tick_interval: float:
	get: return float(get_value("tick_interval", 0))
	set(_unused): push_error("只读内容定义不能修改 tick_interval")
var value_per_stack: float:
	get: return float(get_value("value_per_stack", 0))
	set(_unused): push_error("只读内容定义不能修改 value_per_stack")
