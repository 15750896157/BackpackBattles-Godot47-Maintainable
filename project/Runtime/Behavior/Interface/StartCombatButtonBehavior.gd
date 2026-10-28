extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/StartCombatButton.gd")

static func finishSwitchingToCombat(subject: Receiver):
	subject.pathParticles.deactivate()

	if subject.willFaceNoConnectionDarkReflection:
		RunDatabase.facedNoConnectionDarkReflection += 1

	if OS.has_feature("crazygames"):
		CrazySDK.connect("ad_done", Callable(subject, "onAdFinished").bind(), subject.CONNECT_ONE_SHOT)
		InputBlocker.activate(InputBlocker.Source.SceneSwitch)
		Game.pause(Game.PauseSource.Ad)
		CrazySDK.midgameAd()
	else:
		Game.finishSwitchingToCombat()

static func showStorageHint(subject: Receiver):
	subject.storageHint.text = "[center]"
	var itemsInStorage = Game.STORAGEBOX.getItems().size()
	if itemsInStorage > 0:
		var key = "HINT_Storage"
		if itemsInStorage == 1:
			key = "HINT_Storage_Single"

		subject.storageHint.text += Util.tra(key).format({
			"num": "[b]" + Util.wrapInColor(str(itemsInStorage), Util.paramColor) + "[/b]"
		})
		subject.storageHintAni.play("Show")

	if CustomRules.isSwitchMode():
		if itemsInStorage > 0:
			var switchModeHint1 = Util.tra("HINT_SwitchModeStorage")
			subject.storageHint.text += "\n" + Util.wrapInColor(switchModeHint1, Util.red)

		if Game.getGold() > 0:
			var switchModeHint2 = Util.tra("HINT_SwitchModeGold").replace("$gold", Util.getIcon("gold"))
			subject.storageHint.text += "\n" + Util.wrapInColor(switchModeHint2, Util.red)
			subject.storageHintAni.play("Show")

static func disable(subject: Receiver):
	subject.onHoverEnd()

	if Game.canCancelSwitch:
		Game.cancelSwitch()
	subject.enabled = false
	InputBlocker.setMouseFilter(subject, Control.MOUSE_FILTER_IGNORE)
	InputBlocker.setMouseFilter(subject.lampButton, Control.MOUSE_FILTER_IGNORE)
