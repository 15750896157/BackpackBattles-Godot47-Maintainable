extends Node2D

var raritiesLabel
var fractionsLabel
var saleUniqueLabel
@onready var shopSign = Game.shopSceneNode.get_node("ShopSign")
@onready var tutorialAni = Game.shopSceneNode.get_node("ShopSign/AnimationPlayer")

func _ready():
	hide()
	Game.connect("shop_opened", Callable(self, "onShopOpened"))
	Game.connect("warp_cursor_shop", Callable(self, "onCursorWarp"))
	call_deferred("readyDeferred")

func readyDeferred():
	Util.localizeFonts(self)
	updateLocale()

func updateLocale():
	return load("res://Runtime/Behavior/Interface/RarityHintBehavior.gd").updateLocale(self)

func onShopOpened():
	return load("res://Runtime/Behavior/Interface/RarityHintBehavior.gd").onShopOpened(self)

func show():
	if Game.state != Game.State.Shop:
		return
	super.show()
	var uniqueColor = Game.rarityColors[Item.Rarity.Unique].lightened(0.2)
	var saleChance = snapped(Game.shopSceneNode.getSaleChance() * 100.0, 1)
	var uniqueChance = snapped(Game.shopSceneNode.getUniqueChance() * 100.0, 1)
	saleUniqueLabel.text = Util.tr("HINT_SaleUniqueChances").format({

		"Unique": Util.getIcon("treasure"),
		"saleChance": saleChance,
		"uniqueChance": uniqueChance,
		"maxUniques": ItemBook.getMaxUniques(),
		"curUniques": ItemBook.getNumUniques(false)
	})

	Game.setTutorialDone(Game.TutorialSteps.ShopSign)
	tutorialAni.stop()
	shopSign.modulate = Color(1.1, 1.1, 1.1)

func hide():
	super.hide()
	shopSign.modulate = Color.WHITE

func onCursorWarp():
	Game.addPointOfInterest(Vector2(1480, 70))
