extends "res://PvE/tests/ReferenceLayoutQA.gd"
var evidence: Array = []

func wait_for(predicate: Callable, seconds: float = 35.0) -> bool:
	var deadline: int = Time.get_ticks_msec()+roundi(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await get_tree().process_frame
	return false

func same(a, b) -> bool:
	return JSON.stringify(a,"",true)==JSON.stringify(b,"",true)

func node_named(value: String) -> Node:
	return Expedition.panel.find_child(value,true,false)

func owned_count(id: String) -> int:
	var count: int = 0
	for layer in ["bags","items","storage"]:
		for entry in Expedition.flow.run.build[layer]:
			if entry.definition_id==id:count+=1
	for entry in Expedition.flow.run.pending_rewards:
		if entry.get("definition_id","")==id:count+=1
	return count

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	if "--postbattle-reopen" in OS.get_cmdline_user_args():
		await reopen();finish();return
	for row in Expedition.db.rows("tutorial_steps"):Expedition.flow.profile_service.profile.tutorial_completed.append(row.id)
	var roles: Array = ["armorer","archer","alchemist"]
	for role in roles:
		var loadout: String = Expedition.db.starting_loadouts(role)[0].id
		check(Expedition.create_run(role,loadout,"tutorial",20261104,true).ok,"new run: "+role)
		Expedition.flow.skip_tutorial()
		check(Expedition.flow.choose_route(0).ok,"initial route: "+role)
		await settle()
		check(await wait_for(func():return Game.state==Game.State.Shop and not Expedition.syncing and not Expedition.art.curtain.busy),"native shop ready: "+role)
		check(Expedition.art.ui.get_node_or_null("Action_undo")==null and Expedition.art.ui.get_node_or_null("Action_redo")==null,"shop has no history buttons: "+role)
		check(Expedition.art.ui.get_node_or_null("TouchReturn")==null and Expedition.art.touch_buttons.size()==2,"held-item UI only has rotation buttons: "+role)
		Expedition.flow.run.health=1000;Expedition.flow.run.max_health=1000
		Game.startCombatButton.activateButton()
		if not await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready):check(false,"battle ready: "+role);break
		Expedition.flow.advance_combat(10000)
		check(await wait_for(func():return node_named("LootChoice_0")!=null and not Expedition.art.curtain.busy),"automatic combined loot page: "+role)
		await settle()
		check(Expedition.flow.screen_state=="COMBAT_RESULT","legacy safe result state retained until claiming: "+role)
		check(node_named("LootStatistics")!=null,"result exposes its statistics action: "+role)
		check(node_named("LootCanvas").scene_file_path == "res://PvE/UI/LootScreen.tscn"
			and node_named("LootChoice_0").get_parent().scene_file_path == "res://PvE/UI/LootCard.tscn",
			"authored result and choice scenes are mounted: " + role)
		check(node_named("CloseMenu")==null and node_named("ResultNext")==null,"no ineffective close or next button: "+role)
		var rng = Expedition.flow.run.rng.duplicate(true)
		var preview: Array = Expedition.flow.loot_choices()
		check(same(preview,Expedition.flow.loot_choices()) and same(rng,Expedition.flow.run.rng),"opening rewards does not consume RNG: "+role)
		check(same(node_named("LootChoice_0").get_meta("reward"),preview[0]),"displayed reward matches deterministic preview: "+role)
		node_named("LootStatistics").pressed.emit()
		check(await wait_for(func():return node_named("LootStats_0")!=null and node_named("LootStats_1")!=null),"statistics compare both sides: "+role)
		await settle()
		await shot("loot-statistics-"+role)
		node_named("CloseMenu").pressed.emit()
		check(await wait_for(func():return node_named("LootChoice_0")!=null),"statistics closes back to the unclaimed rewards: "+role)
		await settle()
		check(same(preview,Expedition.flow.loot_choices()) and same(rng,Expedition.flow.run.rng),"reading statistics does not consume rewards or RNG: "+role)
		if role == "armorer":
			var old_choice: TextureButton = node_named("LootChoice_0")
			var run_before: Dictionary = Expedition.flow.run.duplicate(true)
			Expedition.menus.runs.result()
			old_choice.pressed.emit()
			check(same(run_before, Expedition.flow.run) and Expedition.flow.screen_state == "COMBAT_RESULT",
				"replaced popup cannot claim through its previous button")
			check(await wait_for(func(): return node_named("LootChoice_0") != null), "replacement settles after an expired choice")
			check(await wait_for(func(): return is_equal_approx(node_named("LootCanvas").modulate.a, 1.0), 2.0),
				"replacement page finishes its fade")
		await shot("loot-"+role)
		var chosen = node_named("LootSkipGold") if role=="archer" else node_named("LootChoice_0")
		var reward_id: String = str(preview[0].get("definition_id",""))
		var count_before: int = owned_count(reward_id)
		if role == "alchemist":
			check(Expedition.flow.confirm_combat().ok and Expedition.flow.choose_reward(0).ok, "selected reward fixture uses the existing saved state")
			check(await wait_for(func(): return node_named("LootResume") != null), "previously selected reward offers continue")
			await settle()
			chosen = node_named("LootResume")
		var income_trial: Dictionary = Expedition.flow.run.duplicate(true)
		Expedition.flow.economy.battle_income(income_trial,false,false)
		var skip_gold_expected: int = int(income_trial.gold)+2
		check(chosen!=null,"one-step claim action exists: "+role)
		await click(chosen)
		check(await wait_for(func():return Game.state==Game.State.Shop and Expedition.flow.screen_state=="SHOP_PREPARE" and node_named("RouteCancel")!=null and not Expedition.art.curtain.busy),"claim directly enters shop then prompts route: "+role)
		await settle()
		check(bool(Expedition.flow.run.get("route_pending",false)),"route is genuinely unselected: "+role)
		if role=="archer":check(int(Expedition.flow.run.gold)==skip_gold_expected,"skip grants battle income plus exactly configured gold")
		elif preview[0].type in ["item_pool","bag_pool"]:check(owned_count(reward_id)==count_before+1,"exact displayed loot granted once: "+role)
		check(Expedition.flow.saves.validate_run(Expedition.flow.run,Expedition.db).ok,"pending route save validates: "+role)
		check(Game.shopSceneNode.get_node("Background").is_visible_in_tree() and Game.shopSceneNode.get_node("Background").texture!=null,"real shop backdrop is present behind route: "+role)
		await shot("shop-route-"+role)
		await click(node_named("RouteCancel"));await settle()
		check(not Expedition.panel.visible and Expedition.flow.run.route_pending,"route can be dismissed without choosing: "+role)
		for frame in 30:await get_tree().process_frame
		check(not Expedition.panel.visible,"dismissed route does not immediately reopen: "+role)
		check(not Expedition.start_battle() and Expedition.flow.screen_state=="SHOP_PREPARE","battle cannot bypass required route: "+role)
		await settle()
		check(node_named("RouteCancel")!=null,"battle button reopens required route: "+role)
		if role!="alchemist":
			var candidates: Array = Expedition.flow.run.route_candidates
			var index: int = -1
			for i in candidates.size():
				if str(candidates[i].type).ends_with("combat") or candidates[i].type=="boss":index=i;break
			check(index>=0,"combat branch is available: "+role)
			if index>=0:
				var shop = Expedition.flow.run.shop.duplicate(true)
				var shop_rng = Expedition.flow.run.rng.shop
				var visit = Expedition.flow.run.visit
				await click(node_named("RouteGo_"+str(index)));await settle()
				check(not bool(Expedition.flow.run.get("route_pending",false)),"route is locked in: "+role)
				check(same(shop,Expedition.flow.run.shop) and shop_rng==Expedition.flow.run.rng.shop and visit==Expedition.flow.run.visit,"route choice never rerolls stock or spends another visit: "+role)
				Game.startCombatButton.activateButton()
				check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready),"next battle starts after choosing: "+role)
		else:
			await click(node_named("RouteCancel"));await settle()
			await shot("shop-after-cancel")
			var file = FileAccess.open(output.path_join("pending-route-expected.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify({"run_id":Expedition.flow.run.run_id,"shop":Expedition.flow.run.shop,"rng":Expedition.flow.run.rng,"build":Expedition.flow.run.build},"\t"));file.close()
		await Expedition.return_to_title();await settle()
	await edge_cases()
	finish()

func edge_cases():
	var flow = GameFlow.new(Expedition.db,SaveService.new(output.path_join("edge-saves")))
	flow.new_run("alchemist","alchemist_toxin","tutorial",703,true);flow.skip_tutorial();flow.choose_route(0)
	flow.run.health=10000;flow.run.max_health=10000
	check(flow.start_combat().ok,"overflow fixture starts real deterministic combat")
	flow.advance_combat(10000)
	check(int(flow.combat_result.winner_side)==0,"overflow fixture wins")
	flow.confirm_combat()
	for index in 64:
		if not flow.placement.auto_place(flow.run.build,flow._entry("healing_herb","full_"+str(index))).ok:break
	for index in int(flow.run.build.storage_capacity):
		flow.placement.store(flow.run.build,flow._entry("healing_herb","stored_"+str(index)))
	check(flow.placement.validate(flow.run.build).ok,"overflow fixture uses a valid full bag and warehouse")
	flow.run.reward_choices=[{"id":"overflow","table_id":"reward_normal","type":"item_pool","kind":"item","definition_id":"healing_herb","params":{}}]
	check(flow.claim_loot(0).ok,"full backpack still returns to shop")
	check(flow.screen_state=="SHOP_PREPARE" and flow.run.pending_rewards.size()==1 and flow.run.pending_rewards[0].definition_id=="healing_herb","overflow loot retained as pending, never discarded or silently sold")
	check(flow.placement.validate(flow.run.build).ok and flow.saves.validate_run(flow.run,Expedition.db).ok,"overflow save and geometry remain valid")
	check(flow.handle_pending(0,"sell").ok and flow.run.pending_rewards.is_empty(),"overflow can be explicitly resolved in shop")
	for act in [1,3]:
		flow.new_run("armorer","armorer_blades","tutorial",704+act,true);flow.skip_tutorial()
		flow.run.act=act;flow.run.step=5
		var boss = Expedition.db.rows("bosses").filter(func(row):return row.act_id=="act_"+str(act))[0]
		flow.run.route_candidates=[{"type":"boss","boss_id":boss.id,"enemy_id":"","event_id":"","affix_id":"","reward_table_id":boss.reward_table_id,"act":act,"step":5}]
		check(flow.choose_route(0).ok,"boss branch fixture: "+str(act))
		flow.run.health=10000;flow.run.max_health=10000
		check(flow.start_combat().ok,"real boss simulation starts: "+str(act))
		flow.advance_combat(10000)
		check(int(flow.combat_result.winner_side)==0,"boss fixture wins: "+str(act))
		check(flow.claim_loot(0).ok,"one-step boss loot: "+str(act))
		check((flow.screen_state=="SHOP_PREPARE" and int(flow.run.act)==2 and flow.run.route_pending) if act==1 else flow.screen_state=="RUN_RESULT","chapter advance or final victory remains reachable: "+str(act))

func reopen():
	var expected_path: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--postbattle-expected="):expected_path=argument.trim_prefix("--postbattle-expected=")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	check(Expedition.art.ui.get_node_or_null("TitleStart")!=null,"restart title has continue")
	await click(Expedition.art.ui.get_node("TitleStart"))
	check(await wait_for(func():return Game.state==Game.State.Shop and node_named("RouteCancel")!=null and not Expedition.art.curtain.busy),"restarting restores shop and prompts pending route")
	check(Expedition.flow.run.run_id==expected.run_id and Expedition.flow.run.character_id=="alchemist","restart retains third profession and same run")
	check(same(Expedition.flow.run.shop,expected.shop) and same(Expedition.flow.run.rng,expected.rng) and same(Expedition.flow.run.build,expected.build),"restart retains exact stock RNG and all equipment")
	await click(node_named("RouteCancel"));await settle()
	check(not Expedition.start_battle(),"restarting cannot bypass unchosen route")
	await settle();await shot("pending-route-after-reopen")
	Expedition.close_popup()
	check(Expedition.create_run("armorer","armorer_blades","tutorial",818,true).ok,"loss fixture starts fresh after restored run")
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0);await settle()
	await wait_for(func():return Game.state==Game.State.Shop and not Expedition.syncing and not Expedition.art.curtain.busy)
	Expedition.flow.run.health=1
	Game.startCombatButton.activateButton()
	check(await wait_for(func():return Expedition.native_battle_ready and Game.state==Game.State.Combat),"loss fixture enters real battle")
	Expedition.flow.advance_combat(10000)
	check(await wait_for(func():return node_named("LootReturnHome")!=null and not Expedition.art.curtain.busy),"defeat has one real exit action after transition")
	await settle()
	check(int(Expedition.flow.combat_result.winner_side)==1,"loss fixture actually loses")
	if await wait_for(func(): return is_equal_approx(node_named("LootCanvas").modulate.a, 1.0), 2.0):
		await shot("loot-defeat")
	await click(node_named("LootReturnHome"));await settle()
	check(await wait_for(func():return Game.state==Game.State.Title and Expedition.flow.screen_state=="MAIN_MENU" and not Expedition.art.curtain.busy),"one defeat action reaches title without another result window")
	check(not InputBlocker.isActive(),"defeat exit leaves no stale input shield")
	await click(Expedition.art.ui.get_node("TitleStart"));await settle()
	check(Expedition.current_page=="SETUP","new game remains usable after defeat")

func finish():
	var file = FileAccess.open(output.path_join("postbattle-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
