extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/RunAchievement.gd")

static func updateRecord(subject: Receiver):
	for oldItem in subject.itemRect.get_children():
		oldItem.discard()

	var recordData = subject.recordQueue[subject.curRecord]
	var itemIndex = recordData[0]
	var statistic = recordData[1]
	var value = recordData[2]
	var item = ItemBook.getDescriptorFromIndex(itemIndex).instantiate_pooled()
	item.ownerType = Item.Owner.Tooltip

	subject.itemNameLabel.text = item.getTranslatedName()
	var key = ""
	if value == 1 and statistic in subject.firstTimeKeys:
		key = subject.firstTimeKeys[statistic]
	else:
		key = subject.statisticKeys[statistic]

	subject.categoryLabel.text = Util.tra(key).format({"num": str(value)})

	subject.itemRect.add_child(item)
	item.initTooltip()
	item.scaleToFit(subject.rectSize, 0.8)
	item.position = subject.rectSize * 0.5
	item.position += item.getSpriteOffset()

	subject.counterLabel.text = str(subject.curRecord + 1) + " / " + str(subject.recordQueue.size())

	subject.recordStar.show()
	if statistic == Game.ItemStatistic.MostWins:
		if value == Game.MAX_ROUNDS:
			subject.recordStar.setStarType(Game.ItemRecordStar.Diamond)
		elif value == Game.MAX_ROUNDS - 1:
			subject.recordStar.setStarType(Game.ItemRecordStar.Gold)
		elif value >= Game.MAX_WINS:
			subject.recordStar.setStarType(Game.ItemRecordStar.Bronze)
	elif statistic == Game.ItemStatistic.Survivals:
		if value == 1:
			subject.recordStar.setStarType(Game.ItemRecordStar.Silver)

static func _ready(subject: Receiver):
	subject.hide()
	Game.connect("records_updated", Callable(subject, "open"))
	Game.connect("warp_cursor_combat", Callable(subject, "onCursorWarp"))
	Util.localizeFonts(subject)

static func open(subject: Receiver):
	subject.recordQueue = Game.getRecordQueue()
	if subject.recordQueue.size() > 0:
		subject.show()
		subject.animation.play("Appear")
		subject.curRecord = 0
		subject.updateRecord()
		subject.timer.start(2)
		var particles = ObjectPool.particleOneShot(subject.particlesScene, subject.get_parent())
		particles.global_position = subject.global_position
