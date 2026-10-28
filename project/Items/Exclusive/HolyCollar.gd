extends RangerCollar

@onready var luck = int(getP("luck"))
@onready var regen = int(getP("regen"))

func canAffect(item):
	return item.canActivate()

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksH.gd").ForHolyCollar.onPrepare(self)

func onLuckyOrRegenChanged(amount, _event):
	for item in affectedItems:
		item.changeCritChancePercent(amount * getChance2())

func onItemActivated(event):
	if rollChance():
		giveLucky(luck, event)
		giveRegeneration(regen, event)
		miniActivate()
