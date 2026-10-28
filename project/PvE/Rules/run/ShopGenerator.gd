class_name ShopGenerator
extends RefCounted

var db

func _init(content = null):
	db = content

func generate(run: Dictionary, refresh: bool = false) -> Dictionary:
	var before_shop = run.get("shop", ShopState.new(db).create()).duplicate(true)
	var rule = db.get_row("shop_rules", "standard")
	var streams = run.get("rng", {})
	var stream = int(streams.shop) if streams.has("shop") else int(run.get("run_seed", 1)) ^ 0x53484F50
	var rng = DeterministicRNG.new(stream)
	var shop = before_shop.duplicate(true) if refresh else ShopState.new(db).create()
	shop["bag_pity_count"] = int(before_shop.get("bag_pity_count", 0))
	shop["visit"] = int(run.get("visit", 0))
	shop["refresh_count"] = int(before_shop.get("refresh_count", 0)) + 1 if refresh else 0
	var count = int(rule.get("slots", 5))
	var carry: Dictionary = {}
	if not refresh:
		for slot in ShopState.new(db).locked_carry(before_shop):
			carry[int(slot.slot_index)] = slot
	var eligible = _eligible(run)
	if eligible.is_empty():
		return {"ok": false, "error": "no_shop_content", "message": "当前章节没有可售商品。"}
	var slots: Array = []
	var generated_indices: Array = []
	var seen: Dictionary = {}
	for index in range(count):
		var slot: Dictionary = {}
		if refresh and index < before_shop.get("slots", []).size() and before_shop.slots[index].get("locked", false) and not before_shop.slots[index].get("sold", false):
			slot = before_shop.slots[index].duplicate(true)
		elif carry.has(index):
			slot = carry[index]
		else:
			var chosen = _choose(eligible, run, rng, seen)
			if chosen.is_empty():
				return {"ok": false, "error": "shop_pool_empty", "message": "商品池权重无法生成商品。"}
			slot = _slot(chosen)
			generated_indices.append(index)
		seen[str(slot.definition_id)] = int(seen.get(str(slot.definition_id), 0)) + 1
		slots.append(slot)
	var standard = _standard_visit(run)
	var has_bag = _has_bag(slots)
	var pity = int(rule.get("bag_pity_count", 3))
	if standard and not refresh and not has_bag and int(shop.bag_pity_count) >= pity and not generated_indices.is_empty():
		var bags: Array = []
		for row in eligible:
			if row.kind == "bag":
				bags.append(row)
		if not bags.is_empty():
			var index = int(generated_indices[rng.next_int() % generated_indices.size()])
			slots[index] = _slot(bags[rng.next_int() % bags.size()])
			has_bag = true
	if standard:
		if has_bag:
			shop.bag_pity_count = 0
		elif not refresh:
			shop.bag_pity_count = int(shop.bag_pity_count) + 1
	var promo = -1
	# Carried/locked promotion retains its exact price and is this shop's single promotion.
	for index in range(slots.size()):
		if not generated_indices.has(index) and bool(slots[index].get("discounted", false)):
			promo = index
			break
	if promo < 0 and not generated_indices.is_empty():
		promo = int(generated_indices[rng.next_int() % generated_indices.size()])
	var extra_discount = clampf(float(before_shop.get("extra_discount", run.get("shop_discount", 0.0)) if refresh else run.get("shop_discount", 0.0)), 0.0, 0.9)
	shop["extra_discount"] = extra_discount
	var price_scalar = maxf(0.0, float(db.get_row("difficulty_levels", str(run.get("difficulty_id", "standard"))).get("shop_price_scalar", 1.0)))
	shop["price_scalar"] = price_scalar
	for index in generated_indices:
		var discount = extra_discount + (float(rule.get("discount_pct", 0.25)) if index == promo else 0.0)
		slots[index]["discounted"] = index == promo
		slots[index]["discount_pct"] = minf(discount, 0.9)
		slots[index]["price"] = maxi(1, int(floor(float(slots[index].base_price) * price_scalar * (1.0 - minf(discount, 0.9)))))
		slots[index]["price_scalar"] = price_scalar
	_ensure_usable(slots, generated_indices, eligible, run)
	if standard and _has_bag(slots):
		shop.bag_pity_count = 0
	shop["slots"] = slots
	shop["discount_slot"] = promo
	shop["detected_archetype"] = detected_archetype(run)
	run["shop"] = shop
	if not run.has("rng"):
		run["rng"] = {}
	run.rng["shop"] = rng.state
	return {"ok": true, "error": "", "shop": shop.duplicate(true), "rng_state": rng.state}

func detected_archetype(run: Dictionary) -> String:
	var tag_counts: Dictionary = {}
	for entry in run.get("build", {}).get("items", []):
		var row = db.get_row("items", str(entry.definition_id))
		for tag in str(row.get("tags", "")).split("|", false):
			tag_counts[tag] = mini(3, int(tag_counts.get(tag, 0)) + 1)
	var best = ""
	var score = 0.0
	for archetype in db.rows("character_archetypes"):
		if str(archetype.get("character_id")) != str(run.get("character_id")):
			continue
		var value = 0.0
		for tag in str(archetype.get("primary_tags", "")).split("|", false):
			value += int(tag_counts.get(tag, 0))
		value *= float(archetype.get("shop_bias_weight", 1))
		if value > score:
			score = value
			best = str(archetype.id)
	return best

func _eligible(run: Dictionary) -> Array:
	var result: Array = []
	for row in db.rows("items"):
		if bool(row.get("shop_enabled", false)) and not bool(row.get("crafted_only", false)) and int(row.get("chapter_min", 1)) <= int(run.get("act", 1)) and (str(row.get("owner_pool", "public")) in ["public", str(run.get("character_id", ""))]):
			row["kind"] = "item"
			result.append(row)
	for row in db.rows("bags"):
		if str(row.get("availability", "")) == "shop" and int(row.get("chapter_min", 1)) <= int(run.get("act", 1)):
			row["kind"] = "bag"
			row["owner_pool"] = "public"
			result.append(row)
	return result

func _choose(eligible: Array, run: Dictionary, rng: DeterministicRNG, seen: Dictionary) -> Dictionary:
	var rarity_curve = db.get_row("shop_rarity_curve", "act_%d" % int(run.get("act", 1)))
	var rule = db.get_row("shop_rules", "standard")
	var archetype = db.get_row("character_archetypes", detected_archetype(run))
	var primary = str(archetype.get("primary_tags", "")).split("|", false)
	var rarity = _weighted(["common", "rare", "legendary"], [float(rarity_curve.get("common_weight", 0.8)), float(rarity_curve.get("rare_weight", 0.2)), float(rarity_curve.get("legendary_weight", 0.0))], rng)
	var sources = ["public", "character", "archetype"]
	var source_weights = [float(rule.get("pool_public_weight", 0.6)), float(rule.get("pool_character_weight", 0.25)), float(rule.get("pool_archetype_weight", 0.15)) if not primary.is_empty() else 0.0]
	for index in range(sources.size()):
		var pool_rule = db.get_row("shop_pool_weights", sources[index])
		source_weights[index] = minf(float(source_weights[index]), float(pool_rule.get("max_effective_weight", 1.0)))
	var source = _weighted(sources, source_weights, rng)
	var pool: Array = []
	for row in eligible:
		if str(row.get("rarity")) == str(rarity) and _in_source(row, str(source), str(run.get("character_id")), primary):
			pool.append(row)
	# A selected unavailable character/rarity pool falls back to the same rarity's public pool.
	if pool.is_empty():
		for row in eligible:
			if str(row.get("rarity")) == str(rarity):
				pool.append(row)
	if pool.is_empty():
		pool = eligible.duplicate()
	var weights: Array = []
	for row in pool:
		weights.append(pow(float(rule.get("duplicate_decay", 0.35)), int(seen.get(str(row.id), 0))))
	return _weighted(pool, weights, rng)

func _in_source(row: Dictionary, source: String, character: String, primary: Array) -> bool:
	if source == "public":
		return str(row.get("owner_pool", "public")) == "public"
	if source == "character":
		return str(row.get("owner_pool", "")) == character
	for tag in str(row.get("tags", "")).split("|", false):
		if primary.has(tag):
			return true
	return false

func _weighted(values: Array, weights: Array, rng: DeterministicRNG):
	var total = 0.0
	for weight in weights:
		total += maxf(float(weight), 0.0)
	if values.is_empty() or total <= 0:
		return {}
	var pick = rng.unit() * total
	for index in range(values.size()):
		pick -= maxf(float(weights[index]), 0.0)
		if pick <= 0:
			return values[index]
	return values.back()

func _slot(row: Dictionary) -> Dictionary:
	return {"definition_id": str(row.id), "kind": str(row.kind), "base_price": int(row.get("base_price", 1)), "price": maxi(1, int(row.get("base_price", 1))), "locked": false, "sold": false, "discounted": false, "discount_pct": 0.0, "lock_remaining": 0}

func _ensure_usable(slots: Array, generated: Array, eligible: Array, run: Dictionary) -> void:
	var gold = int(run.get("gold", 0))
	if gold <= 0:
		return
	var placement = PlacementService.new(db)
	for slot in slots:
		if int(slot.price) <= gold and _can_receive(placement, run.get("build", {}), str(slot.definition_id)):
			return
	var candidates = eligible.duplicate(true)
	candidates.sort_custom(func(a, b): return int(a.base_price) < int(b.base_price) if int(a.base_price) != int(b.base_price) else str(a.id) < str(b.id))
	var bag_count = 0
	for slot in slots:
		if slot.kind == "bag":
			bag_count += 1
	for index in generated:
		var old = slots[index]
		for row in candidates:
			# Never remove the only bag offer to satisfy usability.
			if old.kind == "bag" and bag_count == 1 and row.kind != "bag":
				continue
			var price = maxi(1, int(floor(float(row.base_price) * float(old.get("price_scalar", 1.0)) * (1.0 - float(old.get("discount_pct", 0.0))))))
			if price > gold or not _can_receive(placement, run.get("build", {}), str(row.id)):
				continue
			var replacement = _slot(row)
			replacement.price = price
			replacement.discounted = bool(old.get("discounted", false))
			replacement.discount_pct = float(old.get("discount_pct", 0.0))
			replacement["price_scalar"] = float(old.get("price_scalar", 1.0))
			slots[index] = replacement
			return

func _can_receive(placement: PlacementService, build: Dictionary, id: String) -> bool:
	if build.get("storage", []).size() < int(build.get("storage_capacity", 2)):
		return true
	var probe = {"uid": "__shop_preview__", "definition_id": id, "x": 0, "y": 0, "rotation": 0}
	var copy = build.duplicate(true)
	return bool(placement.auto_place(copy, probe).ok)

func _has_bag(slots: Array) -> bool:
	for slot in slots:
		if slot.get("kind") == "bag":
			return true
	return false

func _standard_visit(run: Dictionary) -> bool:
	var node = run.get("current_node", {})
	return str(node.get("node_type", node.get("type", "standard"))) != "merchant"
