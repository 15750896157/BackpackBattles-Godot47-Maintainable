extends Gem

const gemColor = Color(3, 2.501563, 0.8)

@onready var vampChance = getP("chance_vamp")
@onready var vampirism = int(getP("vampirism"))
@onready var buffsNeeded = int(getP("buffs"))
@onready var blockForBuffs = int(getP("block"))
var buffCounter = 0

func canModifyChance() -> bool:
	return true

func prepareInventory():
	for item in inventory.getItemsAndGems():
		item.changeAmplificiationChancePercent_allBuffs(getChance())

func prepareWeapon():
	connectForCombat(socket.getItem(), "pre_deal_damage_late", "preAttack")

func preAttack(damageRes: DamageResult):
	if damageRes.hasHit() and rollChance(vampChance):
		giveVampirism(vampirism)
		miniActivate()

func prepareArmor():
	buffCounter = 0
	connectToCharacterBuffs("onBuffsChanged")

func onBuffsChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForTigerRune.onBuffsChanged(self, amount, event)

func onHotSwapHoverWithGemEnd():
	gemAnimation.play("RuneShine")
