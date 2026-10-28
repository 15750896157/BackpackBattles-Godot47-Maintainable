extends SceneTree

var db
var placement
var spatial
var economy
var shop_generator
var crafting
var checks = 0
var failures: Array = []

class RecipeFixture:
	extends RefCounted
	var base
	var rule = "adjacent_4"
	var priority_case = false
	func _init(content, placement_rule: String, priority: bool = false):
		base = content
		rule = placement_rule
		priority_case = priority
	func rows(table: String) -> Array:
		var result = base.rows(table)
		if table == "recipes":
			for row in result:
				if row.id == "recipe_iron_sword":
					row.placement_rule = rule
			if priority_case:
				result.append({"id": "fixture_priority", "result_item_id": "buckler", "tier": 1, "placement_rule": rule, "priority": 100, "chapter_min": 1})
		elif table == "recipe_ingredients" and priority_case:
			result.append({"recipe_id": "fixture_priority", "slot": 1, "item_id": "utility_knife", "consume": true})
			result.append({"recipe_id": "fixture_priority", "slot": 2, "item_id": "sharpening_stone", "consume": true})
		return result
	func get_row(table: String, id: String) -> Dictionary:
		return base.get_row(table, id)
	func shape(id: String, bag: bool = false) -> Array:
		return base.shape(id, bag)
	func value(key: String, fallback = null):
		return base.value(key, fallback)

func _init():
	call_deferred("_run")

func _run():
	db = ContentDB.new()
	if not db.errors.is_empty():
		failures.append("ContentDB: %s" % str(db.errors))
		_finish()
		return
	placement = PlacementService.new(db)
	spatial = SpatialQueryService.new(db)
	economy = EconomyService.new(db)
	shop_generator = ShopGenerator.new(db)
	crafting = CraftingService.new(db)
	_test_placement()
	_test_history()
	_test_spatial()
	_test_shop()
	_test_economy()
	_test_crafting()
	_test_configured_layouts()
	_finish()

func _check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _entry(id: String, uid: String, x: int = 0, y: int = 0, rotation: int = 0) -> Dictionary:
	return {"uid": uid, "definition_id": id, "x": x, "y": y, "rotation": rotation, "used": false, "purchased_visit": 1, "purchase_price": 2}

func _build() -> Dictionary:
	var build = BuildState.new(db).create()
	build.bags.append(_entry("bag_canvas_frame", "bag"))
	return build

func _run_state(seed_value: int = 18421) -> Dictionary:
	return {"run_id": "test", "run_seed": seed_value, "rng": {"shop": seed_value, "route": 111, "reward": 222, "combat": 333}, "character_id": "armorer", "loadout_id": "armorer_blades", "act": 1, "step": 1, "visit": 1, "next_uid": 100, "gold": 50, "build": _build(), "shop": ShopState.new(db).create(), "current_node": {"node_type": "battle"}, "completed_nodes": [], "pending_rewards": []}

func _test_placement():
	var build = _build()
	_check(placement.validate(build).ok, "starter bag valid")
	var l = _entry("broad_axe", "axe", 0, 0, 90)
	var rotated = placement.local_cells(l)
	_check(rotated.has(Vector2i(1, 0)) and rotated.has(Vector2i(0, 0)) and rotated.has(Vector2i(0, 1)), "rotation normalizes L shape")
	_check(placement.auto_place(build, _entry("utility_knife", "a")).ok, "auto placement")
	var before = build.duplicate(true)
	_check(not placement.remove(build, "bag").ok and build == before, "bag removal rejects unsupported items atomically")
	_check(not placement.remove(build, "bag", true).ok and build == before, "bag storage rejects unsupported items atomically")
	_check(not placement.move(build, "a", 9, 0, 0).ok and build == before, "out of bounds move atomic")
	_check(not placement.move(build, "a", 4, 4, 0).ok and build == before, "item outside valid bag cells")
	_check(placement.auto_place(build, _entry("utility_knife", "b")).ok, "second item")
	before = build.duplicate(true)
	_check(not placement.move(build, "a", int(build.items[1].x), int(build.items[1].y), 0).ok and build == before, "same layer collision")
	_check(placement.swap(build, "a", "b").ok, "same layer swap")
	_check(placement.remove(build, "a", true).ok and build.storage.size() == 1, "store placed item")
	_check(placement.swap(build, "a", "b").ok and placement.find(build, "b").layer == "storage", "storage and inventory swap")
	_check(placement.restore(build, "b").ok and build.storage.is_empty(), "restore stored item")
	_check(placement.expand_storage(build, 4).ok and not placement.expand_storage(build, 5).ok, "storage cap 4")
	_check(not placement.expand_storage(build, 2).ok, "storage cannot shrink")
	var invalid = _build()
	invalid.bags.append(_entry("bag_canvas_frame", "bag2", 1, 0))
	_check(not placement.validate(invalid).ok, "bag overlap")
	invalid = _build()
	invalid.items.append(_entry("utility_knife", "fraction"))
	invalid.items[0].x = 0.5
	_check(not placement.validate(invalid).ok, "integer grid enforced")
	invalid = _build()
	invalid.width = 9.5
	_check(not placement.validate(invalid).ok, "fractional canvas dimension rejected")
	invalid = _build()
	invalid.storage_capacity = 2.5
	_check(not placement.validate(invalid).ok, "fractional storage capacity rejected")
	invalid = _build()
	invalid.items.append(_entry("twin_needles", "wrong_rotation", 0, 0, 180))
	_check(not placement.validate(invalid).ok, "shape allowed rotations enforced")
	var suggestion = BuildState.new(db).compact_suggestion(build)
	_check(suggestion.ok and placement.validate(suggestion.build).ok, "compact suggestion remains legal")

func _test_history():
	var history = BuildState.new(db)
	var build = _build()
	for i in range(25):
		var before = build.duplicate(true)
		build["test_revision"] = i + 1
		history.record(before, build)
	_check(history.undo_stack.size() == 20, "20 edit history cap")
	for i in range(20):
		history.undo(build)
	_check(build.test_revision == 5 and not history.undo(build).ok, "undo exact twenty snapshots")
	for i in range(20):
		history.redo(build)
	_check(build.test_revision == 25, "redo exact state")
	history.undo(build)
	var before = build.duplicate(true)
	build.test_revision = 99
	history.record(before, build)
	_check(not history.redo(build).ok, "new edit clears redo branch")
	history.begin_phase(build)
	_check(not history.undo(build).ok, "history limited to current preparation phase")

func _test_spatial():
	var build = _build()
	build.items = [_entry("utility_knife", "source", 1, 1), _entry("utility_knife", "east", 2, 1), _entry("utility_knife", "diagonal", 2, 2), _entry("bandage_roll", "northwest", 0, 0)]
	_check(placement.validate(build).ok, "spatial fixture valid")
	_check(spatial.targets(build, "source", "adjacent_4") == ["east"], "four neighbors exclude diagonal")
	_check(spatial.targets(build, "source", "adjacent_8").size() == 3, "eight neighbors include diagonals")
	for length in [1, 2, 3]:
		_check(spatial.targets(build, "source", "front_%d" % length) == ["east"], "front range %d" % length)
	_check(spatial.targets(build, "source", "same_row") == ["east"], "same logical row")
	_check(spatial.targets(build, "source", "same_column").is_empty(), "same logical column")
	_check(spatial.targets(build, "source", "same_bag").size() == 3, "same bag targets")
	_check(spatial.targets(build, "source", "global_same_tag") == ["diagonal", "east"], "global shared tags exclude unrelated")
	_check(spatial.targets(build, "source", "none").is_empty(), "none spatial selector")
	_check(spatial.condition(build, "source", "spatial_target_count", {"template": "adjacent_4", "tag": "potion", "max": 0}), "negative spatial zero count")
	_check(not spatial.condition(build, "source", "spatial_target_count", {"template": "adjacent_4", "tag": "weapon", "max": 0}), "negative spatial excludes adjacent weapon")
	_check(spatial.condition(build, "source", "source_has_tag", "weapon"), "scalar tag condition")
	_check(spatial.condition(build, "source", "build_tag_count", {"tag": "weapon", "min": 3}), "build tags ignore warehouse")
	build.storage = [_entry("utility_knife", "stored")]
	_check(not spatial.targets(build, "source", "same_bag").has("stored"), "warehouse excluded from geometry")
	var stars = BuildState.new(db).create()
	stars.bags = [_entry("bag_guard_harness", "starbag", 0, 0, 90)]
	stars.items = [_entry("utility_knife", "star_source", 0, 0), _entry("utility_knife", "on_star", 1, 0)]
	_check(placement.validate(stars).ok, "rotated star bag fixture")
	_check(spatial.special_cells(stars, "on_star")[0].cell == Vector2i(1, 0), "special cell follows normalized bag rotation")
	_check(spatial.targets(stars, "star_source", "star_cell").has("on_star"), "star relation")
	_check(spatial.special_cells(stars, "star_source").is_empty() and spatial.active_special_effects(stars, "star_source").size() == 1, "star active effect includes neighbor without changing physical coverage query")
	_check(spatial.derived(build).size() == 4, "all eleven templates recomputed")
	var large = BuildState.new(db).create()
	for y in [0, 3]:
		for x in [0, 3, 6]:
			large.bags.append(_entry("bag_canvas_frame", "large_bag_%d_%d" % [x, y], x, y))
	large.items = [_entry("utility_knife", "ray", 0, 0), _entry("utility_knife", "distance1", 1, 0), _entry("utility_knife", "distance2", 2, 0), _entry("utility_knife", "distance3", 3, 0)]
	_check(placement.validate(large).ok, "full multi-bag spatial fixture")
	for length in [1, 2, 3]:
		_check(spatial.targets(large, "ray", "front_%d" % length).size() == length, "front ray actual distance boundary %d" % length)
	large.items = [_entry("hunting_spear", "vertical", 0, 0, 90), _entry("utility_knife", "below", 0, 3)]
	_check(spatial.targets(large, "vertical", "front_1") == ["below"], "rotated multi-cell front projects from exposed edge")
	_check(spatial.condition(large, "vertical", "spatial_target_count", "template:front_1|min:1|not:false"), "string false negative flag parsed correctly")
	_check(not spatial.condition(large, "vertical", "spatial_target_count", "template:front_1|min:1|not:true"), "explicit negative inversion")

func _test_shop():
	var a = _run_state()
	var b = _run_state()
	_check(shop_generator.generate(a).ok and shop_generator.generate(b).ok, "generate shop")
	_check(a.shop == b.shop and a.rng == b.rng, "seeded reproducible shop")
	_check(a.shop.slots.size() == 5, "five shop slots")
	var count = 0
	for slot in a.shop.slots:
		if slot.discounted:
			count += 1
		_check(int(slot.price) >= 1, "minimum shop price")
	_check(count == 1, "exactly one promotion")
	_check(a.rng.route == 111 and a.rng.reward == 222 and a.rng.combat == 333, "shop RNG isolated")
	_check(economy.toggle_lock(a, 0).ok and economy.toggle_lock(a, 1).ok and not economy.toggle_lock(a, 2).ok, "two lock limit")
	var locked = [a.shop.slots[0].duplicate(true), a.shop.slots[1].duplicate(true)]
	_check(economy.refresh(a).ok and a.shop.slots[0] == locked[0] and a.shop.slots[1] == locked[1], "refresh retains exact locked offers")
	a.visit += 1
	_check(shop_generator.generate(a).ok and a.shop.slots[0].definition_id == locked[0].definition_id and not a.shop.slots[0].locked, "locks carry one node and must be renewed")
	var pity = _run_state()
	pity.shop.bag_pity_count = 3
	_check(shop_generator.generate(pity).ok, "pity shop generated")
	_check(pity.shop.slots.any(func(slot): return slot.kind == "bag") and pity.shop.bag_pity_count == 0, "fourth standard shop includes bag")
	var merchant = _run_state()
	merchant.current_node.node_type = "merchant"
	merchant.shop.bag_pity_count = 2
	shop_generator.generate(merchant)
	_check(merchant.shop.bag_pity_count == 2, "merchant excluded from standard pity counter")
	var costs = _run_state()
	shop_generator.generate(costs)
	for expected in [1, 1, 2, 2, 3, 3]:
		_check(economy.refresh_cost(costs) == expected, "escalating refresh %d" % expected)
		economy.refresh(costs)
	var unchanged = costs.duplicate(true)
	costs.gold = 0
	unchanged.gold = 0
	_check(not economy.refresh(costs).ok and costs == unchanged, "failed refresh preserves gold and RNG")
	var affordable = _run_state(233)
	affordable.gold = 1
	shop_generator.generate(affordable)
	_check(affordable.shop.slots.any(func(slot): return slot.price <= 1), "minimum usability supplies affordable offer when possible")
	var discounted = _run_state()
	discounted.shop_discount = 0.2
	shop_generator.generate(discounted)
	discounted.shop_discount = 0.0
	economy.refresh(discounted)
	_check(discounted.shop.extra_discount == 0.2 and discounted.shop.slots.all(func(slot): return slot.discount_pct >= 0.2), "current visit discount retained across refresh")
	var biased = _run_state()
	biased.build.items = [_entry("utility_knife", "combo"), _entry("twin_needles", "combo2", 0, 1)]
	_check(shop_generator.detected_archetype(biased) == "combo_arsenal", "character archetype detected from equipped tags")
	biased.build.storage = biased.build.items.duplicate(true)
	biased.build.items = []
	_check(shop_generator.detected_archetype(biased).is_empty(), "archetype excludes storage")
	var easy = _run_state()
	easy.difficulty_id = "tutorial"
	shop_generator.generate(easy)
	_check(economy.refresh_cost(easy) == 0 and easy.shop.price_scalar == 0.9, "tutorial shop price and refresh modifiers")
	for slot in easy.shop.slots:
		_check(slot.price == maxi(1, int(floor(float(slot.base_price) * 0.9 * (1.0 - float(slot.discount_pct))))), "difficulty modifies final shop price")
	var challenge = _run_state()
	challenge.difficulty_id = "challenge_5"
	shop_generator.generate(challenge)
	_check(economy.refresh_cost(challenge) == 2 and challenge.shop.price_scalar == 1.05, "challenge shop modifiers")

func _test_economy():
	var run = _run_state()
	run.shop.slots = [{"definition_id": "utility_knife", "kind": "item", "base_price": 2, "price": 1, "locked": false, "sold": false, "discounted": true}]
	var bought = economy.buy(run, 0)
	_check(bought.ok and run.gold == 49, "discount purchase charged actual price")
	var sold = economy.sell(run, str(bought.entry.uid))
	_check(sold.ok and sold.refund and sold.income == 1 and run.gold == 50, "same visit full actual-price refund no discount arbitrage")
	run.shop.slots[0].sold = false
	bought = economy.buy(run, 0)
	economy.mark_used(run.build)
	sold = economy.sell(run, str(bought.entry.uid))
	_check(sold.ok and not sold.refund and sold.income == 1, "used sale uses base price floor half")
	run.gold = 19
	var income = economy.battle_income(run, true, false)
	_check(income.base == 5 and income.elite_bonus == 2 and income.interest == 2 and run.gold == 28, "elite income capped pre-income interest")
	var boss = economy.battle_income(run, false, true)
	_check(boss.income == 0 and run.gold == 28, "boss gold and interest excluded")
	var harder = _run_state()
	harder.difficulty_id = "challenge_5"
	harder.gold = 0
	var less_income = economy.battle_income(harder, true, false)
	_check(less_income.income == 6 and less_income.interest == 0, "difficulty reward multiplier before interest")
	run.free_refreshes = 1
	run.free_refresh_expiry = 99
	shop_generator.generate(run)
	var gold = run.gold
	_check(economy.refresh(run).ok and run.gold == gold and run.free_refreshes == 0, "free refresh consumed transactionally")
	run.free_refreshes = 1
	run.free_refresh_expiry = 1
	run.completed_nodes = [{}]
	_check(economy.refresh_cost(run) > 0, "timed free refresh expires at completed node boundary")
	var full = _run_state()
	full.build.bags = []
	full.build.storage = [_entry("utility_knife", "s1"), _entry("utility_knife", "s2")]
	full.shop.slots = [{"definition_id": "utility_knife", "kind": "item", "price": 2, "sold": false}]
	var before = full.duplicate(true)
	_check(not economy.buy(full, 0).ok and full == before, "full inventory purchase does not charge or burn UID")

func _test_crafting():
	var run = _run_state()
	run.build.items = [_entry("utility_knife", "knife", 0, 0), _entry("sharpening_stone", "stone", 1, 0)]
	var before = run.duplicate(true)
	var candidates = crafting.candidates(run.build, 1)
	_check(candidates.any(func(c): return c.recipe_id == "recipe_iron_sword"), "adjacent ingredients discover recipe")
	var preview = crafting.preview(run, "recipe_iron_sword")
	_check(preview.ok and run == before, "craft preview has no side effects")
	var invalid = crafting.execute(run, "recipe_iron_sword", {"x": 8, "y": 6})
	_check(not invalid.ok and run == before, "invalid explicit result placement preserves materials")
	var result = crafting.execute(run, "recipe_iron_sword")
	_check(result.ok and run.build.items.size() == 1 and run.build.items[0].definition_id == "iron_sword" and placement.validate(run.build).ok, "manual craft consumes exact materials into legal output")
	_check(run.build.items[0].craft_tier == 1 and run.recipes_discovered.has("recipe_iron_sword"), "craft discovery and tier persisted")
	run.act = 2
	var upgrades = crafting.upgrade_candidates(run.build, 2)
	_check(upgrades.any(func(c): return c.recipe_id == "recipe_chain_blade"), "defined tier two free upgrade available")
	var uid = str(run.build.items[0].uid)
	_check(crafting.upgrade(run, uid, "recipe_chain_blade").ok, "free upgrade consumes only selected tier one result")
	_check(crafting.upgrade_candidates(run.build, 3).is_empty(), "tier two result cannot upgrade again")
	var blocked = _run_state()
	blocked.build.bags = []
	blocked.build.bags.append(_entry("bag_tool_roll", "small"))
	blocked.build.items = [_entry("utility_knife", "k", 0, 0), _entry("sharpening_stone", "s", 1, 0), _entry("utility_knife", "f1", 2, 0), _entry("utility_knife", "f2", 0, 1), _entry("utility_knife", "f3", 1, 1), _entry("utility_knife", "f4", 2, 1)]
	blocked.build.storage = [_entry("utility_knife", "storage1"), _entry("utility_knife", "storage2")]
	_check(placement.validate(blocked.build).ok, "pending craft fixture valid")
	var pending = crafting.execute(blocked, "recipe_iron_sword")
	_check(pending.ok and pending.pending and blocked.pending_rewards.size() == 1, "oversized output retained pending when bag and storage full")
	_check(blocked.pending_rewards[0].entry.materials.size() == 2 and placement.validate(blocked.build).ok, "pending output retains provenance and leaves valid build")
	var warehouse = _run_state()
	warehouse.build.storage = [_entry("utility_knife", "wk"), _entry("sharpening_stone", "ws")]
	_check(crafting.candidates(warehouse.build, 1).is_empty(), "storage never participates in ordinary recipes")
	var priority_service = CraftingService.new(RecipeFixture.new(db, "adjacent_4", true))
	var materials = _run_state()
	materials.build.items = [_entry("utility_knife", "pk", 0, 0), _entry("sharpening_stone", "ps", 1, 0)]
	var choices = priority_service.candidates(materials.build, 1)
	_check(choices.size() == 1 and choices[0].recipe_id == "fixture_priority", "higher priority resolves same material set")
	var same_bag = CraftingService.new(RecipeFixture.new(db, "same_bag"))
	materials.build.items[1].x = 2
	materials.build.items[1].y = 2
	_check(not crafting.candidates(materials.build, 1).any(func(c): return c.recipe_id == "recipe_iron_sword") and same_bag.candidates(materials.build, 1).size() == 1, "same bag recipe supports non-adjacent ingredients")
	var star_recipe = CraftingService.new(RecipeFixture.new(db, "star_cell"))
	materials.build.bags = [_entry("bag_guard_harness", "star_recipe_bag")]
	materials.build.items = [_entry("utility_knife", "sk", 0, 2), _entry("sharpening_stone", "ss", 0, 0)]
	_check(placement.validate(materials.build).ok and star_recipe.candidates(materials.build, 1).size() == 1, "at least one material covers star recipe")
	var history = BuildState.new(db)
	var craft_run = _run_state()
	craft_run.build.items = [_entry("utility_knife", "undo_k", 0, 0), _entry("sharpening_stone", "undo_s", 1, 0)]
	var original = craft_run.duplicate(true)
	crafting.execute(craft_run, "recipe_iron_sword")
	var finished = craft_run.duplicate(true)
	history.record(original, craft_run)
	history.undo(craft_run)
	_check(craft_run == original, "whole intent history restores craft materials UID and discovery")
	history.redo(craft_run)
	_check(craft_run == finished, "whole intent redo restores exact craft result")

func _finish():
	var report = {"checks": checks, "failures": failures, "ok": failures.is_empty()}
	print("INVENTORY_ECONOMY_TESTS " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_configured_layouts():
	for loadout in db.rows("character_loadouts"):
		var build = BuildState.new(db).create()
		build.bags.append(_entry(str(loadout.starting_bag_id), "starter_bag"))
		for item in db.rows("starting_build_items"):
			if item.loadout_id == loadout.id:
				build.items.append(_entry(str(item.item_id), str(item.instance_id), int(item.origin_x), int(item.origin_y), int(item.rotation)))
		_check(placement.validate(build).ok, "configured starter valid: " + str(loadout.id))
	for enemy in db.rows("enemy_builds"):
		var build = BuildState.new(db).create()
		for bag in db.rows("enemy_build_bags"):
			if bag.enemy_build_id == enemy.id:
				build.bags.append(_entry(str(bag.bag_id), str(bag.instance_id), int(bag.origin_x), int(bag.origin_y), int(bag.rotation)))
		for item in db.rows("enemy_build_items"):
			if item.enemy_build_id == enemy.id:
				build.items.append(_entry(str(item.item_id), str(item.instance_id), int(item.origin_x), int(item.origin_y), int(item.rotation)))
		_check(placement.validate(build).ok, "configured enemy valid: " + str(enemy.id))
	for boss in db.rows("bosses"):
		var build = BuildState.new(db).create()
		build.bags = db.boss_bags(str(boss.id))
		for item in db.rows("boss_build_items"):
			if item.boss_id == boss.id:
				build.items.append(_entry(str(item.item_id), str(item.instance_id), int(item.origin_x), int(item.origin_y), int(item.rotation)))
		_check(placement.validate(build).ok, "configured cumulative boss phases valid: " + str(boss.id))
