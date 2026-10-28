extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Wardrobe/SkinSlotButton.gd")

static func onPressed(subject: Receiver):

	if subject.unlocked:
		subject.select()
		Game.wardrobe.onSlotSelected(subject)
	else:
		if Game.getTrophies() < subject.skin.prices[subject.slot]:
			if Util.time >= subject.notEnoughTrophiesReadyTime:
				var label = ObjectPool.instantiate(subject.notEnoughTrophiesLabel)
				Game.UINode.add_child(label)
				label.global_position = subject.lock.global_position - Vector2(0, 80)
				subject.notEnoughTrophiesReadyTime = Util.time + 1.0
				Sound.playSound(subject.notEnoughTrophiesSound, - 8)
		else:
			subject.unlock()

static func unlock(subject: Receiver):
	Game.loseTrophies(subject.skin.prices[subject.slot])
	Game.unlockSkin(subject.slot, subject.skin.id)
	var particles = ObjectPool.particleOneShot(subject.trophyParticles, Game.UINode)
	particles.global_position = subject.lock.global_position
	Sound.playSound(subject.buySound1)
	Sound.playSound(subject.buySound2)
	subject.unlocked = true
	subject.lock.hide()
	subject.select()
	Game.wardrobe.onSlotSelected(subject)

static func init(subject: Receiver, _skin: CharacterSkin, _slot: int):
	subject.skin = _skin
	subject.slot = _slot
	subject.icon.texture = subject.skin.icon
	subject.name = str(subject.slot)
	subject.icon.hide()

	if subject.skin.prices[subject.slot] == - 1:

		subject.button.hide()
		subject.lock.hide()
