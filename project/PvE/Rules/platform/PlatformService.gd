class_name PlatformService
extends RefCounted

# The offline implementation is always available. An actual Steam adapter can
# be injected without introducing Steam objects into gameplay rules.
var adapter
var profile: Dictionary

func _init(profile_data: Dictionary = {}, steam_adapter = null):
	profile = profile_data
	adapter = steam_adapter

func unlock(api_name: String):
	if api_name not in profile.get("pending_platform_achievements", []):
		profile.pending_platform_achievements.append(api_name)
	synchronize()

func synchronize():
	if adapter == null or not adapter.is_available(): return
	var remaining: Array = []
	for id in profile.get("pending_platform_achievements", []):
		if not adapter.unlock_achievement(id): remaining.append(id)
	profile.pending_platform_achievements = remaining

func cloud_files() -> Array:
	return ["profile.save", "run.save", "settings.save", "run_backup.save"]

func is_online() -> bool:
	return adapter != null and adapter.is_available()
