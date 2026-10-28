extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForMemberCounter:
	const Receiver = preload("res://Interface/Lobbies/MemberCounter.gd")

	static func _ready(subject: Receiver):
		RunDatabase.lobbies.connect("config_changed", Callable(subject, "updateMemberCounter"))
		RunDatabase.lobbies.connect("member_added", Callable(subject, "updateMemberCounter"))
		RunDatabase.lobbies.connect("member_removed", Callable(subject, "updateMemberCounter"))
		RunDatabase.lobbies.connect("lobby_joined", Callable(subject, "show"))
		RunDatabase.lobbies.connect("lobby_left", Callable(subject, "hide"))
		subject.hide()
