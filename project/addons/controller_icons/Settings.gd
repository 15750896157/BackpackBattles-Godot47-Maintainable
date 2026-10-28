@tool
extends Resource
class_name ControllerSettings

enum Devices{
	LUNA, 
	OUYA, 
	PS3, 
	PS4, 
	PS5, 
	STADIA, 
	STEAM, 
	SWITCH, 
	JOYCON, 
	XBOX360, 
	XBOXONE, 
	XBOXSERIES, 
	STEAM_DECK,
}



@export var joypad_fallback: Devices = Devices.XBOX360



@export var joypad_deadzone = 0.5 # (float, 0.0, 1.0)


@export var allow_mouse_remap = true



@export var mouse_min_movement = 200 # (int, 0, 10000)


@export var custom_asset_dir = "" # (String, DIR)


@export var custom_mapper: Script
