class_name RewardService
extends RefCounted

var db

func _init(content = null):
	db = content

func generate(run: Dictionary, table_id: String) -> Array:
	var table = db.get_row("reward_tables", table_id)
	if table.is_empty() or table_id == "reward_none": return []
	var rng = DeterministicRNG.new(int(run.rng.reward))
	var available: Array = []
	for row in db.rows("reward_entries"):
		if row.reward_table_id == table_id and int(row.act_min) <= int(run.act) and int(row.act_max) >= int(run.act): available.append(row)
	var rewards: Array = []
	for index in int(table.choice_count):
		if available.is_empty(): break
		var weights: Array = []
		for row in available: weights.append(float(row.weight))
		var chosen: Dictionary = rng.weighted(available, weights)
		available.erase(chosen)
		var reward = {"id": chosen.id, "type": chosen.reward_type, "params": db.parse_params(chosen.params), "definition_id": chosen.get("content_id", ""), "table_id": table_id}
		if chosen.reward_type in ["item_pool", "bag_pool"]:
			var pool = content_pool(run, chosen.reward_type, reward.params)
			if pool.is_empty():
				reward = {"id": chosen.id, "type": "gold", "params": {"amount": 5}, "definition_id": "", "table_id": table_id}
			else:
				reward.definition_id = rng.choose(pool)
			reward["kind"] = "bag" if chosen.reward_type == "bag_pool" else "item"
		rewards.append(reward)
	run.rng.reward = rng.state
	return rewards

func content_pool(run: Dictionary, type: String, params: Dictionary) -> Array:
	var pool: Array = []
	var is_bag = type == "bag_pool"
	for row in db.rows("bags" if is_bag else "items"):
		if int(row.chapter_min) > int(run.act) and not bool(params.get("ignore_chapter_gate", false)): continue
		var rarity = str(params.get("rarity", ""))
		if not rarity.is_empty() and row.rarity not in rarity.split("_or_"): continue
		if not is_bag:
			var owner = str(params.get("owner", "current_or_public"))
			var owners: Array = ["public", run.character_id]
			if owner == "alchemist_or_public": owners = ["public", "alchemist"]
			elif owner == "public": owners = ["public"]
			if row.owner_pool not in owners: continue
			var tags: Array = db.list_values(row.tags)
			var filter = str(params.get("tag", ""))
			if not filter.is_empty():
				var match_tag = false
				for tag in filter.split("_or_"):
					if tag in tags: match_tag = true
				if not match_tag: continue
		pool.append(row.id)
	return pool
