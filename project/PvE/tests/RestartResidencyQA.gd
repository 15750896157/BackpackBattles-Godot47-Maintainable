extends "res://PvE/tests/ReferenceLayoutQA.gd"
var scenario="restart"
func wait_until(predicate:Callable,seconds=20.0)->bool:
	var deadline=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await get_tree().process_frame
	return predicate.call()
func idle()->bool:
	return not Expedition.route_in_progress() and not Expedition.syncing and not Expedition.entering_shop and not Expedition.combat_loading and not Expedition.art.curtain.busy and not Game.sceneAnimation.is_playing()
func run_tests():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):scenario=arg.trim_prefix("--scenario=")
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	for row in Expedition.db.rows("tutorial_steps"):Expedition.flow.profile_service.profile.tutorial_completed.append(row.id)
	if scenario=="background":
		Expedition.flow.new_run("alchemist","alchemist_toxin","tutorial",1337,true)
		Expedition.flow.choose_route(0)
		check(await wait_until(func():return Game.state==Game.State.Shop and idle()),"different-role shop entry finishes")
		var background=Game.shopSceneNode.get_node("Background")
		check(background.texture!=null,"shop backdrop survives asynchronous actor preparation")
		check(background.is_visible_in_tree() and background.modulate.a>0.9,"shop backdrop is visible after reveal")
		await shot("background-after-role-change")
	else:
		Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
		# Valid defeated-build fixture: one health and only a food item. The
		# real combat engine, playback and confirm-result path produce the loss.
		Expedition.flow.run.health=1
		var food=Expedition.flow.run.build.items[1].duplicate(true);food.definition_id="travel_ration"
		Expedition.flow.run.build.items=[food]
		Expedition.flow.choose_route(0)
		check(await wait_until(func():return Game.state==Game.State.Shop and idle()),"loss fixture enters shop")
		Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
		check(await wait_until(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle()),"loss fixture enters native combat")
		Expedition.set_playback(4.0,false)
		check(await wait_until(func():return Expedition.flow.screen_state=="COMBAT_RESULT",30.0),"real combat reaches result")
		check(int(Expedition.flow.combat_result.get("winner_side",-1))==1,"fixture actually loses")
		Expedition.perform(Expedition.flow.confirm_combat())
		await get_tree().process_frame
		check(Expedition.flow.screen_state=="RUN_RESULT","defeat reaches run result")
		Expedition.menus.runs.new_setup();await get_tree().process_frame
		await wait_until(func():return Expedition.panel.find_child("BeginExpedition",true,false)!=null)
		Expedition.panel.find_child("BeginExpedition",true,false).pressed.emit()
		check(await wait_until(func():return idle() and Expedition.flow.screen_state=="ROUTE_SELECT",10.0),"new game after defeat releases loading curtain")
		check(Game.state==Game.State.Title,"new route uses native title presentation")
		check(not Expedition.loading_screen.visible,"new route has no stuck loading bar")
		await shot("new-game-after-defeat")
	var file=FileAccess.open(output.path_join("restart-residency-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"scenario":scenario,"checks":checks,"failures":failures,"flow":Expedition.flow.screen_state,"native":Game.state,"curtain":Expedition.art.curtain.busy},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
