extends Item

@onready var speed = getP("speed") / 100.0

func onPrepare():
	var chessboards = getAllInInventoryOfType(ItemBook.chessboardDescriptor)
	if not chessboards.is_empty():
		chessboards[0].addSpeed(speed)

const firstKnightRound = 1
const firstRookRound = 6
const firstQueenRound = 14

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForChessMaster.onShopEntered(self)

