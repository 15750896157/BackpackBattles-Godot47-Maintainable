extends ViewModel
## Projects the shared battle result and reward selection. GameFlow owns all mutations.
var _flow: GameFlow
var _words: Callable
var _translate: Callable
var _enemy_name: Callable
var _effect_text: Callable
var _run_id: String
var _node: Dictionary

func _init(flow: GameFlow, words: Callable, translate: Callable, enemy_name: Callable,
		effect_text: Callable) -> void:
	_flow = flow
	_words = words
	_translate = translate
	_enemy_name = enemy_name
	_effect_text = effect_text
	_run_id = str(flow.run.get("run_id", ""))
	_node = flow.run.get("current_node", {}).duplicate(true)

func snapshot() -> Dictionary:
	var result: Dictionary = _flow.combat_result if not _flow.combat_result.is_empty() else _flow.run.get("last_combat_result", {})
	var won := int(result.get("winner_side", 0)) == 0
	var cards: Array[Dictionary] = []
	if won:
		for reward: Dictionary in _flow.loot_choices():
			var id := str(reward.get("definition_id", ""))
			var definition: Dictionary = _flow.placement.definition(id)
			cards.append({
				"reward": reward,
				"icon_id": id,
				"icon_key": "coin" if str(reward.type).contains("gold") else "heart",
				"title": _effect_text.call(reward.type, reward.params) if definition.is_empty() else _translate.call(definition.name_key),
				"rarity": "" if definition.is_empty() else _translate.call("rarity." + str(definition.get("rarity", "common")) + ".name"),
			})
	var table: Dictionary = _flow.db.get_row("reward_tables", str(_node.get("reward_table_id", "reward_none")))
	var footer := {}
	if not won:
		footer = {"name": "LootReturnHome", "caption": _words.call("返回主页", "Return home")}
	elif bool(_flow.run.get("reward_selected", false)):
		footer = {"name": "LootResume", "caption": _words.call("收好战利品，返回商店", "Return to shop")}
	elif bool(table.get("allow_skip", false)):
		footer = {"name": "LootSkipGold", "caption": _words.call("放弃奖励，领取 %d 金币", "Skip loot, take %d gold") % int(table.get("skip_gold", 0))}
	return {
		"won": won,
		"title": _words.call("战斗胜利", "Victory") if won else _words.call("战斗失利", "Defeat"),
		"subtitle": "%s  ·  %.1fs" % [_enemy_name.call(_node), float(result.get("elapsed_time", 0))],
		"cards": cards,
		"choose": _words.call("选这个", "Choose"),
		"footer": footer,
		"ended": _words.call("本次冒险结束", "This expedition has ended"),
		"carry_hint": _words.call("生命与背包带入下一站 · 选择后直接返回商店", "Health and gear carry forward · Choose to return to the shop"),
	}

func claim(index: int, displayed: Dictionary = {}) -> Dictionary:
	if not _same_settlement() or _flow.screen_state not in ["COMBAT_RESULT", "REWARD_SELECT"]:
		return {"ok": false, "error": "wrong_state"}
	if index >= 0:
		var choices := _flow.loot_choices()
		if index >= choices.size() or choices[index] != displayed:
			return {"ok": false, "error": "invalid_reward"}
	return _flow.claim_loot(index)

func confirm_defeat() -> Dictionary:
	if not _same_settlement() or _flow.screen_state != "COMBAT_RESULT" or int(_flow.combat_result.get("winner_side", 0)) == 0:
		return {"ok": false, "error": "wrong_state"}
	return _flow.confirm_combat()

func _same_settlement() -> bool:
	return _run_id == str(_flow.run.get("run_id", "")) and _node == _flow.run.get("current_node", {})
