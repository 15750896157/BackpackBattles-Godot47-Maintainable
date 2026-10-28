extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/SteamHelper.gd")

static func getAllStats(subject: Receiver):
	subject.SEQUENCE_NUM = Steam.getStatInt("sequence_num")
	subject.SEQUENCE_NUM_LOBBIES = Steam.getStatInt("sqn2")
	Util.eprint("sequence num: ", subject.SEQUENCE_NUM)
	subject.STATS_RECEIVED = true

static func incrementSequenceNumber(subject: Receiver, mode) -> void :
	if subject.STATS_RECEIVED:
		if mode == Game.Mode.Lobbies:
			subject.SEQUENCE_NUM_LOBBIES += 1
			Steam.setStatInt("sqn2", subject.SEQUENCE_NUM_LOBBIES)

		else:
			subject.SEQUENCE_NUM += 1
			Steam.setStatInt("sequence_num", subject.SEQUENCE_NUM)

		subject.storeStats()

static func canUnlock(subject: Receiver, allowInCustom) -> bool:
	return (allowInCustom or (
			not CustomRules.areCustomRulesActive() and
			Game.curMode != Game.Mode.Lobbies and
			Game.curMode != Game.Mode.History))

static func showNextAchievement(subject: Receiver):
	if subject.achievementQueue.is_empty(): return

	var achievementName = subject.achievementQueue.pop_front()
	var popup = ObjectPool.instantiate(subject.achievementPopupScene)
	Game.UINode.add_child(popup)
	popup.showPopup(10)
	subject.achievementTimer.start(3)
	Game.giveTrophies(10)

static func changeStat(subject: Receiver, statName: String, amount: int):
	if subject.STATS_RECEIVED and Game.ACHIEVEMENTS_ENABLED and subject.canUnlock():
		var cur = Steam.getStatInt(statName)
		var new = cur + amount
		Steam.setStatInt(statName, new)
		return new
	return - 1

static func dropItem(subject: Receiver):
	var grantedItem = Steam.triggerItemDrop(10000)
	if grantedItem != 0:
		Util.eprint("inventory handle: ", grantedItem)
		Steam.destroyResult(grantedItem)
