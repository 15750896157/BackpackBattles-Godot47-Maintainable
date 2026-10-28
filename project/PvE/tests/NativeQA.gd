extends Node

var checks: int = 0
var failures: Array = []
var output: String = ""
var digest: String = ""

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func frames(count: int = 3):
	for index in range(count): await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func check(value: bool, text: String):
	checks += 1
	if not value: failures.append(text)

func shot(name: String):
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func run_tests():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: failures.append("native initialization timeout"); finish(); return
		await get_tree().process_frame
	await get_tree().create_timer(1.0,true,false,true).timeout
	Settings.setVal(Settings.Setting.language, "zh_Hans_CN")
	Game.sceneAnimation.play("StartOnTitle")
	Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	await frames()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://Core/Main.tscn", "original main scene is entry")
	check(Game.mainNode == get_parent(), "original Main is the runtime root")
	check(Expedition.db.errors.is_empty(), "PVE configuration loaded")
	check(is_instance_valid(Game.PLAYER) and Game.PLAYER.INVENTORY != null, "original Player and Inventory exist")
	await shot("01-original-title")
	Expedition.begin_setup(Game.Mode.Unranked)
	await frames()
	check(Expedition.panel.visible and Expedition.current_page == "SETUP", "native paper setup opens")
	await shot("02-native-setup")
	Expedition.perform(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true))
	await frames()
	check(Expedition.flow.screen_state == "ROUTE_SELECT", "PVE route state")
	await shot("03-original-route-popup")
	Expedition.perform(Expedition.flow.choose_route(0))
	print("NATIVE_STEP shop transition; paused=",get_tree().paused," scale=",Engine.time_scale)
	await get_tree().create_timer(5.5,true,false,true).timeout
	print("NATIVE_STEP shop timer finished")
	await frames()
	check(Game.state == Game.State.Shop, "original shop scene active")
	check(Game.shopSceneNode.slots.size() == 5, "five original ShopOffer nodes reused")
	check(Game.PLAYER.INVENTORY.getItems().size() == Expedition.flow.run.build.bags.size() + Expedition.flow.run.build.items.size(), "native inventory matches authoritative build")
	check(Game.getGold() == int(Expedition.flow.run.gold), "native gold matches model")
	check(Game.PLAYER.getCurrentHealth() == float(Expedition.flow.run.health), "native health preserves model")
	Expedition.show_ui_guide();await frames()
	check(Expedition.current_page=="UI_GUIDE" and Expedition.panel.visible,"independent illustrated tutorial opens in the shared panel")
	Expedition.close_popup()
	for item in Game.PLAYER.INVENTORY.getItems():
		check(item is Item and item.has_meta("pve_definition_id") and item.sprite.texture != null, "real original item scene and texture " + str(item.name))
	await shot("04-original-shop-items")
	Expedition.flow.skip_tutorial()
	var offer = -1
	for index in Expedition.flow.run.shop.slots.size():
		if not Expedition.flow.run.shop.slots[index].sold and int(Expedition.flow.run.shop.slots[index].price) <= int(Expedition.flow.run.gold): offer = index; break
	check(offer >= 0, "affordable original shop item")
	if offer >= 0:
		var before = int(Expedition.flow.run.gold)
		var price = int(Expedition.flow.run.shop.slots[offer].price)
		var result = Expedition.flow.buy(offer)
		Expedition.perform(result)
		await frames()
		check(result.ok and int(Expedition.flow.run.gold) == before - price, "shop actual configured price")
		check(Game.getGold() == int(Expedition.flow.run.gold), "original shop UI reflects purchase")
		check(Expedition.flow.edit("undo").ok, "undo restores purchase")
		await frames()
		check(Game.getGold() == before, "native gold restores on undo")
		check(Expedition.flow.edit("redo").ok, "redo commits purchase")
		await frames()
	await shot("05-original-purchased")
	var held = Game.PLAYER.INVENTORY.getItems().filter(func(item): return not item.isBag())[0]
	held.pickup()
	await frames()
	check(not Expedition.start_battle() and Expedition.flow.screen_state == "SHOP_PREPARE", "held original item blocks combat snapshot")
	for control in Expedition.toolbar.get_children():
		if control is Button: check(control.disabled, "toolbar transaction disabled while dragging")
	var drop_result = held.drop()
	held.reactToDropResult(drop_result)
	await frames(8)
	check(not is_instance_valid(Game.draggedItem), "original drop releases dragged item")
	Expedition.show_crafting()
	await frames()
	check(Expedition.current_page == "CRAFTING", "original recipe entrance uses new rules")
	Expedition.close_popup()
	Expedition.show_records()
	await frames()
	check(Expedition.current_page == "CODEX" and Expedition.menus.library.category=="records", "local achievements and history open inline")
	Expedition.close_popup()
	Expedition.menus.library.show_page("items")
	await frames()
	var seen:Dictionary={}
	for page_index in int(ceil(Expedition.db.rows("items").size()/6.0)):
		Expedition.menus.library.page=page_index;Expedition.menus.library.populate();await frames()
		var cards=Expedition.detail_views.results.find_children("*","Button",true,false).filter(func(card):return card.has_meta("definition_id"))
		check(cards.size()<=6,"codex instantiates at most six touch cards per page")
		for card in cards:
			var icons=card.find_children("*","TextureRect",true,false)
			check(icons.size()==1 and icons[0].texture!=null,"paged card has real texture "+str(card.get_meta("definition_id")))
			seen[card.get_meta("definition_id")]=true
	check(Expedition.current_page == "CODEX" and seen.size() == Expedition.db.rows("items").size(), "paged codex covers every configured item")
	Expedition.close_popup()
	Expedition.show_current_enemy()
	await frames()
	check(Expedition.panel.visible, "native full enemy intel opens")
	await shot("06-original-enemy-intel")
	Expedition.close_popup()
	check(Expedition.start_battle(), "PVE battle passes snapshot and save")
	Game.switchToCombat()
	await get_tree().create_timer(5.5,true,false,true).timeout
	await frames()
	check(Expedition.native_battle_ready and is_instance_valid(Game.OPPONENT), "original Opponent and combat transition used")
	check(Expedition.flow.combat_result.ok, "pure deterministic combat valid")
	digest = str(Expedition.flow.combat_result.replay_digest)
	Expedition.set_playback(1.0, true)
	var paused_time = Expedition.flow.playback_time
	await get_tree().create_timer(0.15,true,false,true).timeout
	check(Expedition.flow.playback_time == paused_time, "native pause freezes rule playback")
	await shot("07-original-battle-paused")
	Expedition.return_to_title()
	await frames()
	Expedition.continue_run()
	await get_tree().create_timer(5.5,true,false,true).timeout
	await frames()
	check(Expedition.flow.combat_result.get("replay_digest", "") == digest, "native quit/continue repeats same battle")
	Expedition.set_playback(4.0, false)
	Expedition.flow.advance_combat(10000)
	await frames()
	check(Expedition.flow.screen_state == "COMBAT_RESULT", "original combat produces PVE result")
	await shot("08-original-result")
	Expedition.show_combat_log()
	await frames()
	check(Expedition.current_page == "COMBAT_LOG", "native combat log uses deterministic statistics")
	check(not Expedition.flow.run.logs.back().get("item_stats_by_instance_id", {}).is_empty(), "local history saves new combat statistics")
	await shot("08b-original-combat-log")
	Expedition.render_state()
	Expedition.advance_result()
	await frames()
	if Expedition.flow.screen_state == "REWARD_SELECT":
		await shot("09-original-rewards")
		Expedition.perform(Expedition.flow.choose_reward(0))
		await frames()
		while not Expedition.flow.run.pending_rewards.is_empty():
			var result = Expedition.flow.handle_pending(0, "place")
			if not result.ok: result = Expedition.flow.handle_pending(0, "storage")
			if not result.ok: result = Expedition.flow.handle_pending(0, "sell")
			check(result.ok, "native reward resolves")
			if not result.ok: break
		Expedition.perform(Expedition.flow.complete_node())
		await frames()
		check(Expedition.flow.screen_state == "ROUTE_SELECT", "reward returns to PVE route")
	var history_digest = str(Expedition.flow.run.logs.back().digest)
	Expedition.return_to_title()
	await frames()
	Expedition.continue_run()
	await frames()
	check(str(Expedition.flow.run.logs.back().digest) == history_digest, "finished battle history survives local save/continue")
	check(not Expedition.flow.run.logs.back().get("item_stats_by_instance_id", {}).is_empty(), "saved history restores per-item statistics")
	finish()

func finish():
	var report = {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "entry": ProjectSettings.get_setting("application/run/main_scene"), "content_sha256": Expedition.db.content_sha256 if Expedition.db != null else "", "battle_digest": digest, "mode": "actual original root scene with PVE adapter; public UI and rule methods"}
	print("NATIVE_PVE_QA " + JSON.stringify(report))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file = FileAccess.open(output.path_join("native-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ")); file.close()
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
