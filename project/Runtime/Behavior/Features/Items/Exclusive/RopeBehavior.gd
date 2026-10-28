extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/Rope.gd")

static func onPrepare(subject: Receiver):
	for item in subject.getAffectedItems(subject.Affected.Secondary):
		subject.speedUpItem = item

	if subject.speedUpItem != null:
		for triggerItem in subject.getAffectedItems():
			subject.connectForCombat(triggerItem, "activated", "onTriggerItemActivated")

static func onTriggerItemActivated(subject: Receiver, event):
	var curSpeed = Game.ropeSpeedups.get(subject.speedUpItem, 0.0)
	var speedLeft = subject.maxSpeed - curSpeed
	if speedLeft > 0:
		subject.speedUpItem.addSpeed(min(speedLeft, subject.speedPerTrigger))

	Util.dictAdd(Game.ropeSpeedups, subject.speedUpItem, subject.speedPerTrigger)
	subject.speedTimer.start(subject.getP_m("dur"))
	subject.miniActivate()

static func onSpeedTimeout(subject: Receiver):
	Util.dictSub(Game.ropeSpeedups, subject.speedUpItem, subject.speedPerTrigger)
	var curSpeed = Game.ropeSpeedups.get(subject.speedUpItem, 0.0)
	var speedLeft = subject.maxSpeed - curSpeed
	if speedLeft > 0:
		subject.speedUpItem.reduceSpeed(min(speedLeft, subject.speedPerTrigger))
