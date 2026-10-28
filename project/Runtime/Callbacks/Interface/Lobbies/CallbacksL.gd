extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForLobbyMemberList:
	const Receiver = preload("res://Interface/Lobbies/LobbyMemberList.gd")

	static func _ready(subject: Receiver):
		subject.clear()
		RunDatabase.lobbies.connect("member_added", Callable(subject, "addMember"))
		RunDatabase.lobbies.connect("member_removed", Callable(subject, "removeMember"))
		RunDatabase.lobbies.connect("lobby_left", Callable(subject, "clear"))
		subject.get_v_scroll_bar().connect("visibility_changed", Callable(subject, "onScrollbarVisibilityChanged"))

class ForLobbyScoreboard:
	const Receiver = preload("res://Interface/Lobbies/LobbyScoreboard.gd")

	static func updateMember(subject: Receiver, memberId):
		if memberId == null:
			for member in subject.memberEntries:
				subject.memberEntries[member].onFightFinished()
		else:
			subject.memberEntries[memberId].onFightFinished()
		subject.updateRankings()

	static func onScrollbarVisibilityChanged(subject: Receiver):
		if subject.LOBBIES.isHost():
			if subject.scrollContainer.get_v_scroll_bar().visible:
				subject.custom_minimum_size.x = 568
			else:
				subject.custom_minimum_size.x = 496
		else:
			if subject.scrollContainer.get_v_scroll_bar().visible:
				subject.custom_minimum_size.x = 538
			else:
				subject.custom_minimum_size.x = 466

class ForLobbySpeed:
	const Receiver = preload("res://Interface/Lobbies/LobbySpeed.gd")

	static func onSpeedChanged(subject: Receiver):
		var minutes = subject.LOBBIES.getRunDuration_Minutes()
		var average = subject.LOBBIES.getAverageRoundDuration_seconds()

		subject.runDurationLabel.text = Util.tra("FORMAT_LobbyDuration").format({
			"avrRound": average, "totalDur": minutes})
