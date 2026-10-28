extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCrazySDK:
	const Receiver = preload("res://Utility/CrazySDK.gd")

	static func _record(subject: Receiver, event: String) -> void:
		var events: Array = LocalServices.profile.get("local_game_events", [])
		events.append({"event": event, "time": Time.get_unix_time_from_system()})
		if events.size() > 500: events.pop_front()
		LocalServices.profile["local_game_events"] = events
		LocalServices.commit("profile")
