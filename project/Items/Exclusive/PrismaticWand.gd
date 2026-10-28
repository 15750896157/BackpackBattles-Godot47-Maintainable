extends Item

@onready var buffs = [Game.EventType.Mana, Game.EventType.Lucky, Game.EventType.Regeneration]

@onready var manaNeeded = int(getP("manat"))
@onready var luckNeeded = int(getP("luckt"))
@onready var regenNeeded = int(getP("regent"))
@onready var empower = int(getP("empower"))
@onready var buffsToUse = int(getP("use"))

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPrismaticWand.doCooldownEffect(self)

