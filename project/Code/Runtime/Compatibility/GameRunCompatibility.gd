extends "res://Code/Runtime/Compatibility/GameProfileCompatibility.gd"

## Original run, lobby and history entry points used by compatibility scenes.

func cancelSurviveMode():
	endRun()

func suspendRunState(instanceLoadout = true):
	if hasArenaRunState():
		instanceCharacter(getSelectedClass())
		if instanceLoadout:
			setLoadout(getConfiguredLoadout())
		CustomRules.reset()
		emit_signal("runstate_suspended")

func initPlayerFromRunstate(mode: int = curMode):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").initPlayerFromRunstate(self, mode)

func readRoundResultsFromRunState(mode: int):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").readRoundResultsFromRunState(self, mode)

func concedeLastRun():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").concedeLastRun(self)

func setMode(newMode):
	curMode = newMode

func initPlayer():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").initPlayer(self)

func onReconnectedToLobby():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").onReconnectedToLobby(self)

func onReconnectedToLobby_deferred():
	sceneAnimation.advance(100)
	playerNodeAnimation.advance(100)

func onReconnectTimeout():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").onReconnectTimeout(self)

func loadArenaRunAndStartOnTitle():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").loadArenaRunAndStartOnTitle(self)

func instanceCharacter(characterClass: int):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").instanceCharacter(self, characterClass)

func setRandomCharacter(_randomCharacter: bool):
	randomCharacter = _randomCharacter
	emit_signal("random_character_changed")

func initStartInventory(loadout = 0):
	Expedition.setup_loadout = clampi(int(loadout), 0, 1)
	return

func addLoadoutAni_jump(bag):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").addLoadoutAni_jump(self, bag)

func addLoadoutAni(node, isBag):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").addLoadoutAni(self, node, isBag)

func startHistoryRun(runData, roundNum: int, opponentData = null, opponentRoundNum = - 1):
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").startHistoryRun(self, runData, roundNum, opponentData, opponentRoundNum)

func endHistoryRun():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").endHistoryRun(self)

func addStarOfCourage():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").addStarOfCourage(self)

func initRoundResults():
	roundResults.resize(getMaxNumberOfRounds())
	roundResults.fill(RoundResult.RunOver)

func isSoftballRound():
	return load("res://Code/Runtime/Behavior/Game/RunFlow.gd").isSoftballRound(self)

func isSoftballStats():
	return ((wins == 0 and losses == 3) or
			(wins <= 1 and losses == 4))

func isItemHandicapStats():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").isItemHandicapStats(self)

func onWaitingForMembersTimeout():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").onWaitingForMembersTimeout(self)

func forceLeaveLobby():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").forceLeaveLobby(self)

func initHistoryOpponent():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").initHistoryOpponent(self)

func addOpponentItem(tuple, item, checkValidity: bool):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").addOpponentItem(self, tuple, item, checkValidity)

func forceLoseCombat():
	return

func runOver():
	return Expedition.flow != null and Expedition.flow.screen_state == "RUN_RESULT"

func endRun(commit = true, showAchievements = true):
	Expedition.render_state()
	return

func endRun_lobby():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").endRun_lobby(self)

func onRunEnded():
	deleteRunStateAndRules()
	numTimesOutOfStamina = 0
	continueState = ContinueState.NotContinued
	saveGame()
	runStarted = false
	emit_signal("run_over")
