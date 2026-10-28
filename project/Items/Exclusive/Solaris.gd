extends Item

@onready var sunShieldDescriptor = ItemBook.getDescriptor("Sun Shield")
@onready var sunArmorDescriptor = ItemBook.getDescriptor("Sun Armor")
@onready var holyArmorDescriptor = ItemBook.getDescriptor("Holy Armor")
@onready var shieldOfValorDescriptor = ItemBook.getDescriptor("Shield of Valor")
@onready var heatPerShieldBlock = int(getP("heat"))

var boosted = 0

func canAffect(item):
	return item.isA(sunShieldDescriptor) or item.isA(sunArmorDescriptor)

func onBought():
	boosted = 1

func getData():
	return boosted

func setData(data):
	if data != null:
		boosted = data

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSolaris.onPrepare(self)

func onArmorUsedHeat(event):
	giveBlock(getBlock(), true, event)
	miniActivate()

func onShieldBlocked(blockedDamageRes):
	if rollChance():
		giveHeat(heatPerShieldBlock)
		activate()

func onItemRoll(descr):
	if (boosted > 0 and
		(descr == shieldOfValorDescriptor or
		descr == holyArmorDescriptor)):
		ItemBook.multiplyWeight(1.5)

func onItemRolled(descr):
	if (descr == shieldOfValorDescriptor or
		descr == holyArmorDescriptor):
		boosted -= 1
