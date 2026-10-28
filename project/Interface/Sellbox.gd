extends Area2D

signal calc_trade_chance

const openSound = preload("res://Assets/Sound/ChestOpening1.wav")
const burpSound = preload("res://Assets/Sound/ChestOpening2.wav")
const closeSound = preload("res://Assets/Sound/ChestClosing2.wav")
const chompSound = preload("res://Assets/Sound/ChestClosing1.wav")
const coinEatSound_single = preload("res://Assets/Sound/Coins3.wav")
const coinEatSound_many = preload("res://Assets/Sound/Coins1.wav")
const coinSpitSound = preload("res://Assets/Sound/Coins2.wav")
const jumpSound = preload("res://Assets/Sound/Thud3.wav")

const angleCurve = preload("res://Assets/Chestnut/ChestnutOpenCurve.tres")
const closedDist = 1000.0
const maxAnglePerSecond = 180.0
const closedAngle = 0.0
const coinSpritePath = "res://Assets/GoldCoin2.png"

@onready var box = $CollisionShape2D
@onready var shape = $CollisionShape2D.shape
@onready var chestnut = $Chestnut
@onready var label = $Chestnut/RichTextLabel
@onready var rect = Rect2(box.global_position - shape.size * 0.5, shape.size)
@onready var chestnutTop = $Chestnut/Top
@onready var animation = $AnimationPlayer
@onready var goldPos = $GoldPos
@onready var hintArea = $HintArea
@onready var hint = $Chestnut/SellHint
@onready var chompParticles = $ChompDust
@onready var tradeNode = $Trade
@onready var tradeAnimation = $TradeAnimation
@onready var bottomPos = $Chestnut/BottomPos
@onready var light = $Chestnut/Light3D
@onready var hoverParticles = $Chestnut/Particles
@onready var pupil = $Chestnut/Top/Eye/Pupil
@onready var tongueAnimation = $Chestnut/Tongue/TongueAnimation

@onready var littleMimicDescriptor = ItemBook.getDescriptor("Little Mimic")
@onready var scaleDescriptor = ItemBook.getDescriptor("Scale")
@onready var employeeUniformDescriptor = ItemBook.getDescriptor("Employee Uniform")

var hovered = false
var angleTween
var lightTween
var hoveredLastFrame = false
var tradeChance = 0.0
var tradeBonusValue = 0
var soldRoll: Dictionary

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/SellboxBehavior.gd")._ready(self)

func onRunOver():
	soldRoll.clear()

func getGoldPos():
	return goldPos.global_position

func onItemPickedUp():
	return load("res://Runtime/Behavior/Features/Interface/SellboxBehavior.gd").onItemPickedUp(self)

func onItemDropped(item, dropResult):
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd").onItemDropped(self, item, dropResult)

func getLastSellRoll(item: ItemDescriptor):
	return soldRoll.get(item, ItemBook.NOT_SOLD)

func onHoverHintArea():
	hint.show()

func onHoverHintAreaEnd():
	hint.hide()

func isHovered():
	return hovered

func eatGold(amount):
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd").eatGold(self, amount)

func burp():
	Sound.playSound(burpSound, Util.randRange( - 5, 0), Util.randPitch(0.3) - 0.2)

func chomp():
	return load("res://Runtime/Behavior/Features/Interface/SellboxBehavior.gd").chomp(self)

func close(volume = - 10):
	Sound.playSound(closeSound, volume + Util.randRange( - 1, 1), Util.randPitch(0.2) - 0.1)

func _process(delta: float) -> void :
	load("res://Runtime/Behavior/Interface/SellboxBehavior.gd")._process(self, delta)

func updateText():
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd").updateText(self)

func sellItem(item):
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd").sellItem(self, item)

func getTradeChance() -> float:
	return load("res://Runtime/Behavior/Features/Interface/SellboxBehavior.gd").getTradeChance(self)

func onShopRefreshed():
	return load("res://Runtime/Behavior/Features/Interface/SellboxBehavior.gd").onShopRefreshed(self)

func rollTrades():
	return

func onSwitchingToShop():
	pupil.activate()
	tongueAnimation.play("Idle")

func onShopLeft():
	pupil.deactivate()
	tongueAnimation.stop()

const dustParticlesScene = preload("res://Shader/ChestnutLandParticles.tscn")
var clickTween: Tween
@onready var defaultPos = chestnut.position

func _gui_input(event):
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd")._gui_input(self, event)

func spawnDust(strength):
	return load("res://Runtime/Behavior/Interface/SellboxBehavior.gd").spawnDust(self, strength)

