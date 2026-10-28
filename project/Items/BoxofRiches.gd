extends Item

var numGems = 1

const gemOdds = [
	16,
	8,
	2,
	1,
	0.5
]

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBoxofRiches.onShopEntered(self)

func getGatedDescriptor(rarityOdds, numHighRolls = 0) -> ItemDescriptor:
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBoxofRiches.getGatedDescriptor(self, rarityOdds, numHighRolls)

func getRelatedItemHeight() -> int:
	return 50

func onGateItemRoll():
	if rollShopChance():
		for item in Game.shopSceneNode.gateItemCandidates:
			if item.isA(descriptor): return
		Game.shopSceneNode.addGateItem(self)
