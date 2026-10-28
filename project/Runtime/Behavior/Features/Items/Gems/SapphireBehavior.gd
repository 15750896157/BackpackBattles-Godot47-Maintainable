extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Gems/Sapphire.gd")

static func prepareWeapon(subject: Receiver):
	subject.spectral = false
	subject.connectForCombat(subject.socket.getItem(), "pre_deal_damage_late", "preAttack")
	subject.connectForCombat(subject.socket.getItem(), "attacked", "onAttack")

static func onAttack(subject: Receiver, damageRes: DamageResult):
	if subject.spectral and damageRes.hasHit():
		subject.giveMana(subject.getP1(), damageRes.event)
		subject.inflictCold(subject.getP4(), damageRes.event)
		subject.miniActivate()

static func onManaChanged(subject: Receiver, amount, event):
	if amount > 0:
		subject.manaCounter += amount
		var relMana = subject.manaCounter / subject.manaNeeded
		var block = relMana * subject.getP3()
		subject.manaCounter %= subject.manaNeeded
		if block > 0:
			subject.giveBlock(subject.getGemPower() * block, event)
			subject.miniActivate()
			subject.showCooldownSmooth(relMana, true)
		else:
			subject.showCooldownSmooth(relMana, false)
