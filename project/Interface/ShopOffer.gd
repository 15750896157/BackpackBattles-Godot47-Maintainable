extends Node2D

@onready var index = int(name) - 1
var item
var price: int
var free = false
var onSale = false
var wasOnSale = false
var bought = false
var reserved = false
var normalPrice
var salePrice
var saleMode = Game.SaleMode.Roll

const saleSound = preload("res://Assets/Sound/Sale.ogg")
const reserveSound = preload("res://Assets/Sound/Reserve.wav")
const treasureAnimation = preload("res://Items/Animations/TreasurePulse.tscn")

const treasureSound = preload("res://Assets/Sound/Glitter.wav")

const neutralBannerMaterial = preload("res://Shader/SkillBanner_Neutral.material")
const classBannerMaterial = preload("res://Shader/ClassBanner.material")
const craftingPulse = preload("res://Items/Animations/CraftingShopPulse.tscn")
const specialShopParticles = preload("res://Shader/SpecialShopParticles.tscn")

const tooPoorColor = Color(0.765625, 0.098694, 0.098694)
const throwOutDur = 0.6

@onready var priceLabel = $PriceLabel
@onready var salePriceLabel = $Sale/SalePrice
@onready var animation = $AnimationPlayer
@onready var light = $Light3D
@onready var reserveButton = $ReserveButton
@onready var reserveHint = $ReserveHint/ReserveHintLabel
@onready var reservedTag = $ReservedTag
@onready var reserveAnimation = $ReservedTag/AnimationPlayer
@onready var saleAnimation = $Sale/AnimationPlayer
@onready var uniqueParticles = $UniqueParticles
@onready var subclassLabel = $Subclass
@onready var banner = $Subclass/SubclassBanner
@onready var subclassAnimation = $Subclass/AnimationPlayer

@onready var bannerTexture_singleLine = banner.texture
const bannerTexture_doubleLine = preload("res://Interface/SkillBanner.png")
@onready var bannerMargins = [banner.offset_left, banner.offset_top, banner.offset_right, banner.offset_bottom]

func _input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd")._input(self, event)

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd")._ready(self)

func setItem(_item, _saleMode = Game.SaleMode.Roll):
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").setItem(self, _item, _saleMode)

func addSpecialShopParticles():
	var particles = ObjectPool.particleOneShot(specialShopParticles, self)
	particles.rotation = deg_to_rad( - 8)
	particles.speed_scale = Util.rng.randf_range(1.8, 2.2)

func checkCrafting():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").checkCrafting(self)

func updateLocale():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").updateLocale(self)

const BANNER_WIDTH = 230.0

func setBannerText(text: String):
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").setBannerText(self, text)

func shrinkBanner(textWidth):
	subclassLabel.set_end(subclassLabel.position + Vector2(textWidth, 55))

func calcPrice():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").calcPrice(self)

func updatePrice():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").updatePrice(self)

func playSaleSound():
	Sound.playSound(saleSound, - 16, Util.randPitch() - 0.1)

func checkMoney(_goldChange = 0):
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").checkMoney(self, _goldChange)

func dropped(result: int):
	if Item.wasBought(result):
		buy()

func buy():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").buy(self)

func reset():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").reset(self)

func resetFull():
	pve_reset()
	return

func canThrowOut():
	return item != null and not bought and not reserved

func throwOut():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").throwOut(self)

func onReserveButtonHover():
	if canPlayerReserve():
		reserveHint.show()

func onReserveButtonHoverEnd():
	reserveHint.hide()

func onReserveButtonPressed():
	if canPlayerReserve():
		setReserved( not reserved)
		if reserved:
			Game.onItemReserved()

func setReserved(state):
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").setReserved(self, state)

func setSaleMode(_mode):
	saleMode = _mode

func canChangeReserveState() -> bool:
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").canChangeReserveState(self)

func canPlayerReserve() -> bool:
	if not canChangeReserveState(): return false
	if Game.shopSceneNode.chooseOneShop: return false
	return true

func pve_sync(data: Dictionary):
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").pve_sync(self, data)

func pve_reset():
	return load("res://Runtime/Behavior/Interface/ShopOfferBehavior.gd").pve_reset(self)

func pve_mark_sold():
	pve_reset()
	bought = true
	priceLabel.self_modulate = Color.WHITE
	priceLabel.modulate = Color.WHITE
	priceLabel.add_theme_font_size_override("font_size", 22)
	priceLabel.text = Expedition.bilingual("售罄", "Sold")
