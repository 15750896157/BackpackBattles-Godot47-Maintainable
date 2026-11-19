extends "res://Code/Runtime/Compatibility/GameInteractionCompatibility.gd"

## Application lifecycle, native route entry points and coordination across game services.

func pause(pauseSource: int):
	return load("res://Code/Runtime/Behavior/Game/Session.gd").pause(self, pauseSource)

func unpause(pauseSource: int):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").unpause(self, pauseSource)

func openMenu():
	cancelSwitch()
	emit_signal("menu_open")

func saveRunState():
	return Expedition.save_run()

func actuallySaveRunState():
	runSaveQueued = false
	return Expedition.save_run()

func continueLastRun(mode):
	setMode(mode)
	Expedition.continue_run(mode)
	return

func _enter_tree():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd")._enter_tree(self)

func _ready() -> void :
	load("res://Code/Runtime/Behavior/Game/RunFlow.gd")._ready(self)

func ready_deferred():
	return await load("res://Code/Runtime/Behavior/Game/RunFlow.gd").ready_deferred(self)

func leaveLobbyFromShop():
	leavingLobby = true

	returnToTitle_midRun()
	playerNodeAnimation.play("ReturnToTitle")
	RunDatabase.lobbies.leaveLobby()

func startFreshRun(mode):
	setMode(mode)
	Expedition.begin_setup(mode)
	return

func startLobbyRun():
	if randomCharacter:
		deleteDraggedItem()
	closeAllMenus()
	startFreshRun(Game.Mode.Lobbies)
	SteamHelper.unlockAchievement("LobbyStarted", true)

func startRun():
	runStarted = true
	call_deferred("titleToShop")
	call_deferred("emit_signal", "run_started")
	return

func titleToShop():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").titleToShop(self)

func isShopActive() -> bool:
	return state == State.Shop and canSwitchToCombat and Expedition.active and Expedition.flow.screen_state == "SHOP_PREPARE"

func isSwitchToCombatPossible() -> bool:
	return isShopActive() and draggedItem == null

func switchToCombat():
	return await load("res://Code/Runtime/Behavior/Game/Presentation.gd").switchToCombat(self)

func finishSwitchingToCombat():
	Expedition.finish_switch_to_combat()
	for actor in [PLAYER, OPPONENT]:
		if is_instance_valid(actor): actor.pve_set_combat_anchor()
	return

func closeAllMenus():
	pve_close_legacy_menus(false)
	return

func forceSwitchToCombat():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").forceSwitchToCombat(self)

func finishForceSwitchToCombat():
	sceneAnimation.advance(COMBAT_DELAY)
	sceneAnimation.play()

	RunDatabase.lobbies.startCombat()

func initOpponent(roundReduction, droppedItems):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").initOpponent(self, roundReduction, droppedItems)

func endCombat():
	return

func combatEndDeferred():
	return

func _input(event: InputEvent) -> void :
	load("res://Code/Runtime/Behavior/Game/Presentation.gd")._input(self, event)

func addTranslation():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").addTranslation(self)

func tagAllNodes():
	print("CHECKING FOR NEW NODES #", checkI)
	printNewNodes(get_tree().get_root())
	checkI += 1

func printNewNodes(node):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").printNewNodes(self, node)

func _unhandled_input(event: InputEvent) -> void :
	load("res://Code/Runtime/Behavior/Game/Presentation.gd")._unhandled_input(self, event)

func switchToShop():
	Expedition.enter_shop()
	return

func becomeOpponent():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").becomeOpponent(self)

func addSwitchAniTween(tween, character, xMovement: float, yOffset: float, dur):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").addSwitchAniTween(self, tween, character, xMovement, yOffset, dur)

func finishBecomeOpponent(offset):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").finishBecomeOpponent(self, offset)

func becomeOpponent_old():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").becomeOpponent_old(self)

func playShopBGM():
	lastShopBGM = ShopBGM.Default
	return

func _pve_initialize_role_stats():
	return await load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd")._pve_initialize_role_stats(self)

func pve_close_legacy_menus(clear_transition: bool = true):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").pve_close_legacy_menus(self, clear_transition)

func _pve_restore_actor_parents():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd")._pve_restore_actor_parents(self)

func pve_prepare_title():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").pve_prepare_title(self)

func pve_prepare_shop():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").pve_prepare_shop(self)

func pve_prepare_combat():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").pve_prepare_combat(self)

func freeOpponent(notify: bool = true):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").freeOpponent(self, notify)

func onSceneAnimationFinished(aniName):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").onSceneAnimationFinished(self, aniName)

func _pve_restore_health():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd")._pve_restore_health(self)

func startRound():
	Expedition.start_round()
	call_deferred("_pve_restore_health")
	return

func gainRoundGold(curGoldGain, curHealthGain):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").gainRoundGold(self, curGoldGain, curHealthGain)

func winRun():
	endRun()

func loseRun():
	endRun()

func returnToTitle_afterRun():
	Expedition.return_to_title()
	return

func returnedToTitle_afterRun():
	state = State.Title
	InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
	emit_signal("returned_to_title")
	return

func returnToTitle_midRun():
	Expedition.return_to_title()
	return

func returnedToTitle_midRun():
	state = State.Title
	InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
	emit_signal("returned_to_title")
	return

func isOtherModesUIOpen():
	return otherModesUI != null and otherModesUI.isOpen

func isLobbyUIOpen():
	return otherModesUI != null and (
		otherModesUI.joinLobbyUI.isOpen or otherModesUI.hostLobbyUI.isOpen)

func _process(delta: float) -> void :
	load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd")._process(self, delta)

func _physics_process(delta):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd")._physics_process(self, delta)

func writeoutState():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").writeoutState(self)

var audioMutedBeforeFocusLost = false

func _notification(what: int) -> void :

	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		clearAffectedLines()
		itemLibrary.hideRecordIcons()

		if lockedTooltipItem == null:
			showHintsIsPressed = false

			var focusItem = getFocusItem()
			if focusItem != null:
				focusItem.hideBuildIntoRecipesTooltip()
				focusItem.clearCanAffectVisuals()

		if Settings.getVal(Settings.Setting.reduce_fps_unfocused):
			OS.low_processor_usage_mode = true
			Engine.max_fps = int(20)

		if Settings.getVal(Settings.Setting.mute_unfocused):
			audioMutedBeforeFocusLost = AudioServer.is_bus_mute(Sound.MASTER_BUS)
			AudioServer.set_bus_mute(Sound.MASTER_BUS, true)

		if useShell():
			processTimer.start(Util.rng.randf_range(10, 30))

	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		set_deferred("showHintsIsPressed", false)

		if Settings.getVal(Settings.Setting.reduce_fps_unfocused):
			OS.low_processor_usage_mode = false
			Engine.max_fps = int(Settings.getVal(Settings.Setting.fps_limit))

		if Settings.getVal(Settings.Setting.mute_unfocused):
			AudioServer.set_bus_mute(Sound.MASTER_BUS, audioMutedBeforeFocusLost)

		if useShell():
			processTimer.stop()
			checkProcesses_threaded()

	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Expedition.enabled:
			quit()
			return
		saveWindowSettings()

func useShell():
	return not EDITOR and not ProjectSettings.get_setting("application/config/local_services")

func saveWindowSettings():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").saveWindowSettings(self)

var quitting: bool = false

func quit():
	return await load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").quit(self)

func joinProcessThread():
	processThread.wait_to_finish()

func checkProcesses_cyclic():
	checkProcesses_threaded()
	processTimer.start(Util.rng.randf_range(10, 30))

func checkProcesses_threaded():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").checkProcesses_threaded(self)

func checkProcesses() -> bool:
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").checkProcesses(self)

func _exit_tree():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd")._exit_tree(self)

func _begin_shutdown():
	if is_instance_valid(SceneRouter): SceneRouter.shutdown()
	if is_instance_valid(Sound): Sound.shutdown()
	reactToHoverEnd = false
	hoveredItems.clear()
	itemsUnderMouse.clear()
	draggedItem = null
