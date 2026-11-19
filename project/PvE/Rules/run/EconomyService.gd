class_name EconomyService
extends RefCounted

var db
var placement
var generator

func _init(content = null):
	db = content
	placement = PlacementService.new(content)
	generator = ShopGenerator.new(content)

func buy(run: Dictionary, slot_index: int) -> Dictionary:
	var slots = run.get("shop", {}).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return _error("invalid_shop_slot", "找不到商品槽位。")
	var slot = slots[slot_index]
	if bool(slot.get("sold", false)):
		return _error("slot_sold", "该商品已售出。")
	var price = int(slot.get("price", 0))
	if price < 1 or int(run.get("gold", 0)) < price:
		return _error("not_enough_gold", "金币不足。")
	var candidate = run.duplicate(true)
	var entry = make_entry(candidate, str(slot.definition_id), price)
	var status = placement.auto_place(candidate.build, entry)
	var stored = false
	if not status.ok:
		status = placement.store(candidate.build, entry)
		stored = status.ok
	if not status.ok:
		return _error("inventory_full", "背包和仓库都无法接收商品，请先整理空间。")
	candidate.gold = int(candidate.gold) - price
	candidate.shop.slots[slot_index]["sold"] = true
	candidate.shop.slots[slot_index]["locked"] = false
	candidate.shop.slots[slot_index]["lock_remaining"] = 0
	_commit(run, candidate)
	return {"ok": true, "error": "", "entry": placement.find(run.build, str(entry.uid)).entry, "stored": stored, "price": price, "gold": run.gold}

func sell(run: Dictionary, uid: String) -> Dictionary:
	var found = placement.find(run.get("build", {}), uid)
	if found.is_empty():
		return _error("missing_item", "找不到要出售的物品。")
	var candidate = run.duplicate(true)
	var status = placement.remove(candidate.build, uid)
	if not status.ok:
		return status
	var entry = found.entry
	var fresh = not bool(entry.get("used", false)) and int(entry.get("purchased_visit", -1)) == int(run.get("visit", 0)) and not bool(entry.get("crafted", false))
	var base = int(placement.definition(str(entry.definition_id)).get("base_price", 0))
	var ratio = clampf(float(db.value("used_sell_ratio", 0.5)) + float(run.get("sell_ratio_bonus", 0.0)), 0.0, 1.0)
	var price = int(entry.get("purchase_price", base)) if fresh else maxi(1, int(floor(base * ratio)))
	candidate.gold = int(candidate.gold) + price
	_commit(run, candidate)
	return {"ok": true, "error": "", "gold": run.gold, "refund": fresh, "income": price, "price": price, "entry": entry}

func toggle_lock(run: Dictionary, slot_index: int) -> Dictionary:
	var slots = run.get("shop", {}).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or bool(slots[slot_index].get("sold", false)):
		return _error("invalid_lock_slot", "该槽位没有可锁定的商品。")
	var locked = bool(slots[slot_index].get("locked", false))
	var count = 0
	for slot in slots:
		if bool(slot.get("locked", false)) and not bool(slot.get("sold", false)):
			count += 1
	if not locked and count >= int(db.value("shop_lock_limit", 2)):
		return _error("lock_limit", "最多锁定两个商品。")
	slots[slot_index]["locked"] = not locked
	slots[slot_index]["lock_remaining"] = 0 if locked else 1
	return {"ok": true, "error": "", "locked": not locked}

func refresh_cost(run: Dictionary) -> int:
	if _has_free_refresh(run):
		return 0
	var count = int(run.get("shop", {}).get("refresh_count", 0))
	var difficulty = db.get_row("difficulty_levels", str(run.get("difficulty_id", "standard")))
	return maxi(0, mini(3, 1 + int(count / 2)) + int(difficulty.get("refresh_cost_delta", 0)))

func refresh(run: Dictionary) -> Dictionary:
	var cost = refresh_cost(run)
	if int(run.get("gold", 0)) < cost:
		return _error("not_enough_gold", "金币不足，无法刷新。")
	var candidate = run.duplicate(true)
	var result = generator.generate(candidate, true)
	if not result.ok:
		return result
	candidate.gold = int(candidate.gold) - cost
	if cost == 0 and _has_free_refresh(candidate):
		candidate["free_refreshes"] = maxi(0, int(candidate.get("free_refreshes", 0)) - 1)
	_commit(run, candidate)
	return {"ok": true, "error": "", "cost": cost, "gold": run.gold, "shop": run.shop.duplicate(true)}

func battle_income(run: Dictionary, is_elite: bool, is_boss: bool) -> Dictionary:
	var curve = db.get_row("economy_curve", "act_%d" % int(run.get("act", 1)))
	var base = 0 if is_boss else int(curve.get("normal_gold", 4 + int(run.get("act", 1))))
	var elite = int(curve.get("elite_bonus_gold", 2)) if is_elite and not is_boss else 0
	var difficulty = db.get_row("difficulty_levels", str(run.get("difficulty_id", "standard")))
	var scalar = maxf(0.0, float(difficulty.get("gold_reward_scalar", 1.0)))
	var scaled_base = int(floor(base * scalar))
	elite = int(floor((base + elite) * scalar)) - scaled_base
	base = scaled_base
	var step = maxi(1, int(curve.get("interest_step", db.value("interest_step_gold", 5))))
	var cap = maxi(0, int(curve.get("interest_cap", db.value("interest_cap", 2))) + int(run.get("interest_cap_delta", 0)))
	var interest = 0 if is_boss else mini(cap, int(int(run.get("gold", 0)) / step))
	var income = base + elite + interest
	run["gold"] = int(run.get("gold", 0)) + income
	return {"ok": true, "error": "", "base": base, "elite_bonus": elite, "interest": interest, "income": income, "gold": run.gold}

func mark_used(build: Dictionary) -> Dictionary:
	for layer in ["bags", "items"]:
		for entry in build.get(layer, []):
			entry["used"] = true
	return {"ok": true, "error": ""}

func make_entry(run: Dictionary, definition_id: String, purchase_price: int = 0) -> Dictionary:
	var serial = int(run.get("next_uid", 1))
	run["next_uid"] = serial + 1
	return {"uid": "%s_%d" % [str(run.get("run_id", "run")), serial], "definition_id": definition_id, "x": 0, "y": 0, "rotation": 0, "used": false, "purchased_visit": int(run.get("visit", 0)), "purchase_price": purchase_price}

func _has_free_refresh(run: Dictionary) -> bool:
	return int(run.get("free_refreshes", 0)) > 0 and int(run.get("free_refresh_expiry", 2147483647)) > run.get("completed_nodes", []).size()

func _commit(run: Dictionary, source: Dictionary) -> void:
	run.clear()
	run.merge(source, true)

func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
