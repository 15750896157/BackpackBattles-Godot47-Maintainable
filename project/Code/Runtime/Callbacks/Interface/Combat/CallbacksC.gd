extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCombatTugBar:
	const Receiver = preload("res://PvE/UI/Combat/Hud/CombatTugBar.gd")

	static func _process(subject: Receiver, delta):
		var playerStrength = Game.PLAYER.getCurrentHealth() + Game.PLAYER.getBlock()
		var oppoStrength = Game.OPPONENT.getCurrentHealth() + Game.OPPONENT.getBlock()

		subject.max_value = playerStrength + oppoStrength
		subject.value = playerStrength
