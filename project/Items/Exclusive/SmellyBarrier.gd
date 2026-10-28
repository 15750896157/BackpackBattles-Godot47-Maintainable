extends Item

@onready var garlicDescriptor = ItemBook.getDescriptor("Garlic")
@onready var garlicBlockBonus = int(getP("blockbonus"))
@onready var blockForPoison = int(getP("blockt"))
@onready var poisonForBlock = int(getP("poison"))

var blockAcc: int
var boostedGarlic = 0

func canAffect(item):
	return item.isA(garlicDescriptor) or item.canBlock()

func onBought():
	boostedGarlic = 3

func getData():
	return boostedGarlic

func setData(data):
	if data != null:
		boostedGarlic = data

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSmellyBarrier.onPrepare(self)

func onItemGaveBlock(amount, event):
	blockAcc += amount
	var poison = blockAcc / blockForPoison
	blockAcc %= blockForPoison
	if poison > 0:
		inflictPoison(poison * poisonForBlock, event)
		activate()

func onItemRoll(descr):
	if descr == garlicDescriptor and boostedGarlic > 0:
		ItemBook.multiplyWeight(1.5)

func onItemRolled(descr):
	if descr == garlicDescriptor:
		boostedGarlic -= 1
