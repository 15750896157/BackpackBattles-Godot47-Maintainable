extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/TitleScreen.gd")

static func spawnItem(subject: Receiver):
	if Expedition.enabled: return
	if subject.itemNode.get_child_count() < subject.MAX_ITEMS:
		subject.dropItem()

	if Game.state == Game.State.Title:
		subject.itemDropTimer.start(Util.rng.randf_range(0.4, 1.0))

static func onLoadoutButtonToggled(subject: Receiver, pressed, index):
	if pressed and Game.draggedItem == null:

		Game.setConfigValue("Options", "Loadout_" + Game.getClassInternalName(), index)
		Game.setLoadout(index)

static func updateLoadoutButtons(subject: Receiver, disabled: bool, loadout: int):
	if loadout < 0:
		loadout = Game.getConfiguredLoadout()
	for i in subject.loadoutButtons.size():
		subject.loadoutButtons[i].disabled = disabled
		subject.loadoutButtons[i].setPressed(i == loadout)

	subject.randomClassButton.disabled = disabled

static func clearItems(subject: Receiver):
	AssetStream.release("title-decoration")
	AssetStream.release_metadata()
	subject.itemDropTimer.stop()
	subject.itemDropTimer2.stop()
	Util.callDelayed(subject, "discardAllItems", 1)

	subject.onRankedHoverEnd()
	subject.onContinueHoverEnd()
	subject.onUnrankedHoverEnd()
	subject.smokeParticles.emitting = false

static func _on_SteamButton_pressed(subject: Receiver) -> void :
	var res = Util.openLocalLink("steam://advertise/2427700")

	if res != OK:
		Util.openLocalLink("https://store.steampowered.com/app/2427700")

static func _on_QQButton_pressed(subject: Receiver):

	Util.openLocalLink("http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=6zssjoGDmapnJG6q3CkXuwrg2S1JzG2n&authKey=bonULiTLCoSD3jcuZ1NVDLtjqXoeWj0JrZOxxbkMkFH3mMzSDVtX3zyFNp%2B%2F5WZN&noverify=0&group_code=490799286")
