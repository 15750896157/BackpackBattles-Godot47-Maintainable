extends Node
var output = ""
var checks: Array = []
var failures: Array = []
var observations: Array = []
var player_copy = false
var route_events: Array = []
var route_results: Array = []
var route_phases: Array = []
var legacy_animations: Array = []
var initial_title: WeakRef
var initial_title_scope := ""
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg=="--core-flow-player-copy": player_copy=true
	call_deferred("run_tests")
func check(value, message):
	checks.append({"ok":bool(value),"message":message})
	if not value: failures.append(message);print("CORE_FAIL ",message)
	return bool(value)
func wait_for(predicate: Callable, seconds = 12.0) -> bool:
	var deadline = Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()
func idle() -> bool:
	return not Expedition.route_in_progress() and not Expedition.syncing and not Expedition.entering_shop and not Expedition.combat_loading and not Expedition.art.curtain.busy and not Game.sceneAnimation.is_playing()
func settle():
	for frame in 4: await get_tree().process_frame
	await wait_for(idle,25.0)
	await get_tree().create_timer(0.3,true,false,true).timeout
func note(label):
	var row={"phase":label,"screen":Expedition.flow.screen_state,"native":Game.state,"page":Expedition.current_page,"panel":Expedition.panel.visible,"pending":Expedition.render_pending,"syncing":Expedition.syncing,"curtain":Expedition.art.curtain.busy,"input_sources":InputBlocker.curSources,"title_mode":Game.titleScreen.process_mode,"ranked_filter":Game.titleScreen.rankedButton.mouse_filter,"ranked_disabled":Game.titleScreen.rankedButton.disabled,"scene_animation":Game.sceneAnimation.current_animation,"stream":AssetStream.stats()}
	observations.append(row);print("CORE_OBSERVATION ",JSON.stringify(row))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
func shelf_matches() -> bool:
	for index in Game.shopSceneNode.slots.size():
		var offer=Game.shopSceneNode.slots[index]
		var data=Expedition.bridge.slot_data(index)
		if data.is_empty() or bool(data.get("sold",false)): continue
		if not is_instance_valid(offer.item) or str(offer.item.get_meta("pve_definition_id","")) != str(data.definition_id): return false
	return true
func press_text(caption: String) -> bool:
	for control in Expedition.panel.find_children("*","BaseButton",true,false):
		if ((control is Button and control.text == caption) or str(control.get_meta("action_caption",""))==caption) and not control.disabled:
			if player_copy: await click_control(control)
			else: control.pressed.emit()
			return true
	return false
func click_control(control: Control):
	if Expedition.popup_content.is_ancestor_of(control):
		Expedition.popup_scroll.ensure_control_visible(control)
		await get_tree().process_frame
		await get_tree().process_frame
	var point=control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
		get_viewport().push_input(event,true)
		await get_tree().process_frame
func resume_from_title():
	var resume=Expedition.art.ui.get_node_or_null("TitleStart")
	if not check(resume!=null and not resume.disabled,"main start offers saved run"):return
	if player_copy:await click_control(resume)
	else:resume.pressed.emit()
	await settle()
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	if not await wait_for(func():return Expedition.initialized,90.0): check(false,"initialize");finish();return
	await settle()
	if Expedition.native_routes != null: record_routes()
	if player_copy:
		await resume_from_title()
	else:
		check(Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true).ok,"new isolated run")
		Expedition.flow.skip_tutorial();await settle()
		check(Expedition.flow.choose_route(0).ok,"route enters shop")
	await settle();await note("01-shop")
	check(Game.state==Game.State.Shop and shelf_matches(),"initial visible shelf matches authoritative offers")
	if Expedition.art.ui==null: finish();return
	if Expedition.native_routes != null and not player_copy: await cancel_prepared_title()
	# The user's normal item drag must precede refresh/result checks: signal-only
	# runs miss the deferred update that happens while the drop owns syncing.
	var held=Game.PLAYER.INVENTORY.getItems().filter(func(item):return not item.isBag())[0]
	var origin=Expedition.flow.placement.find(Expedition.flow.run.build,str(held.get_meta("pve_uid"))).entry.duplicate(true)
	held.pickup()
	Game.PLAYER.INVENTORY.orientItem(held,Vector2(origin.x,origin.y),int(origin.rotation)/90)
	var drop=held.drop();held.reactToDropResult(drop)
	check(drop==Item.DropResult.AddedToInventory,"native drag and drop commits through original interaction")
	check(await wait_for(func():return idle() and not Expedition.bridge.drop_pending and not Expedition.render_pending,3.0),"drop resumes its deferred presentation update")
	await note("01b-after-native-drop")
	for index in range(3):
		Expedition.flow.run.free_refreshes=3
		var before=Expedition.flow.run.shop.duplicate(true)
		if player_copy: await click_control(Expedition.art.ui.get_node("Action_refresh"))
		else: Expedition.art.ui.get_node("Action_refresh").pressed.emit()
		var matched=await wait_for(func(): return idle() and shelf_matches(),6.0)
		await settle()
		check(Expedition.flow.run.shop!=before,"refresh changes authoritative offers "+str(index))
		check(matched and shelf_matches(),"refresh swaps visible item scenes with their prices "+str(index))
		await note("02-refresh-"+str(index))
	check(not Expedition.render_pending,"no stranded render request after refresh")
	if Expedition.flow.run.current_node.get("type","")=="merchant":
		Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
		check(await wait_for(func():return Expedition.flow.screen_state=="ROUTE_SELECT",4.0),"merchant leaves through its normal route flow")
		await settle()
		var combat_route=-1
		for index in Expedition.flow.run.route_candidates.size():
			if str(Expedition.flow.run.route_candidates[index].type).ends_with("combat"):combat_route=index;break
		if combat_route<0:check(false,"next combat route available");finish();return
		Expedition.flow.choose_route(combat_route);await settle()
	Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"start battle through visible art control")
	Expedition.set_playback(4.0,false)
	check(await wait_for(func():return Expedition.flow.screen_state=="COMBAT_RESULT",45.0),"ordinary playback reaches battle end")
	check(await wait_for(func():return Expedition.panel.visible and Expedition.current_page=="COMBAT_RESULT",3.0),"result automatically opens without touching intel")
	await settle()
	await note("03-automatic-result")
	if Expedition.current_page=="COMBAT_RESULT":
		var claim=Expedition.panel.find_child("LootChoice_0",true,false)
		check(claim!=null and Expedition.panel.find_child("ResultNext",true,false)==null,"combined result exposes loot directly without another Next")
		if claim!=null:
			claim.pressed.emit()
			check(await wait_for(func():return Expedition.flow.screen_state=="SHOP_PREPARE" and Game.state==Game.State.Shop,15.0),"one claim returns directly to shop")
	await Expedition.return_to_title();await settle();await note("04-title-after-result")
	check(not InputBlocker.isActive(),"title has no transition or menu input shield")
	var title=Expedition.art.ui
	if title.has_node("TitleNewRun"):
		title.get_node("TitleNewRun").pressed.emit();await settle()
		check(str(Expedition.flow.run.get("state",""))=="RUN_RESULT","ending the current run keeps the player on the title")
	title.get_node("TitleStart").pressed.emit();await settle()
	check(Expedition.current_page=="SETUP" and Expedition.panel.visible,"start opens setup after the current run ends")
	Expedition.create_run("armorer","armorer_blades","tutorial",1340,true)
	check(await wait_for(func():return Expedition.current_page=="ROUTE_SELECT",4.0),"new game actually leaves setup and shows routes")
	if Expedition.render_pending: finish();return
	Expedition.close_popup();await settle()
	check(Expedition.flow.new_run("armorer","armorer_blades","tutorial",1340,true).ok,"second fresh run")
	Expedition.flow.skip_tutorial();await settle()
	Expedition.flow.choose_route(0);await settle()
	Expedition.show_settings();await settle()
	check(await press_text(Expedition.t("ui.save_menu")),"save current shop through settings")
	await settle()
	await resume_from_title()
	check(await wait_for(func():return Game.state==Game.State.Shop and Expedition.flow.screen_state=="SHOP_PREPARE" and idle() and not Expedition.render_pending,25.0),"title continue restores saved shop without a manual redraw")
	Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"second combat entered")
	Expedition.art.ui.get_node("CombatPauseTarget").pressed.emit()
	check(Expedition.flow.combat_paused,"pause button stops playback before exit")
	Expedition.art.ui.get_node("Action_combat_settings").pressed.emit();await settle()
	check(await press_text(Expedition.t("ui.save_menu")),"save and exit button in live combat settings")
	await settle();await note("05-title-after-combat-exit")
	check(Game.state==Game.State.Title and idle(),"combat exit finishes title transition")
	check(not InputBlocker.isActive() and Expedition.art.ui.get_node("TitleStart").mouse_filter!=Control.MOUSE_FILTER_IGNORE,"title buttons accept real pointer input after combat exit")
	await resume_from_title()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"continue button reconstructs exited combat")
	await note("06-continue")
	await Expedition.return_to_title();await settle()
	if Expedition.native_routes != null and not player_copy:
		await verify_routes()
		await verify_title_shutdown()
	finish()

func cancel_prepared_title():
	var shop = Game.shopSceneNode
	var title_path := "res://PvE/UI/TitleScreen.tscn"
	check(initial_title.get_ref() == null and not AssetStream.scopes.has(initial_title_scope) and not AssetStream.resources.has(title_path), "leaving startup frees title and its asset scope")
	var observation := {"prepared": false, "covered": false}
	var cancel = func(_id, phase):
		if phase != &"prepared": return
		observation.prepared = true
		observation.covered = Expedition.art.curtain.covered
		SceneRouter.cancel_current()
	SceneRouter.phase_changed.connect(cancel)
	var error = await Expedition.native_routes.change(&"title", "qa_cancel_prepared_title")
	SceneRouter.phase_changed.disconnect(cancel)
	await settle()
	var result = SceneRouter.result(SceneRouter.last_request_id)
	check(observation.prepared and observation.covered and error == ERR_SKIP and not result.get("committed", true), "prepared owned title can be cancelled before commit under the cloud")
	check(SceneRouter.get_current_node() == shop and Game.state == Game.State.Shop and shelf_matches(), "title cancellation preserves the active native shop")
	check(not AssetStream.scopes.has(initial_title_scope) and not AssetStream.resources.has(title_path), "cancelled title drops the staged scene and resource scope")
	check(not InputBlocker.isActive() and not Expedition.loading_screen.visible, "title cancellation releases the overlay and input lock")

func record_routes():
	var screen = SceneRouter.get_current_node()
	initial_title = weakref(screen)
	initial_title_scope = str(SceneRouter.diagnostics().current_scope)
	check(screen != Game.titleScreen and screen == Expedition.art.ui and screen.scene_file_path == "res://PvE/UI/TitleScreen.tscn" and SceneRouter.current_screen_id == &"title", "router owns the visible startup title")
	check(not initial_title_scope.is_empty() and AssetStream.scopes.has(initial_title_scope), "startup title has a tracked resource scope")
	var startup_reasons = Expedition.loading_screen.history.filter(func(row): return row.event == "begin").map(func(row): return row.reason)
	check(startup_reasons == ["startup"], "initial title uses the existing startup overlay once")
	for event in ["switch_to_shop", "title_to_shop", "pre_shop_opened_from_title", "pre_shop_opened_from_combat", "run_started", "shop_opened", "combat_start_pressed", "shop_closed", "switching_to_combat", "combat_scene_entered", "return_to_title", "returned_to_title"]:
		Game.connect(event, func(): route_events.append({"id": SceneRouter.diagnostics().active_id, "event": event}))
	Game.sceneAnimation.animation_started.connect(func(animation): legacy_animations.append(animation))
	SceneRouter.screen_changed.connect(func(screen):
		var info = SceneRouter.diagnostics()
		route_events.append({"id": info.active_id, "event": "screen_changed", "screen": screen}))
	SceneRouter.request_finished.connect(func(id, screen, error):
		route_results.append({"id": id, "screen": screen, "error": error, "committed": SceneRouter.result(id).get("committed", false)}))
	SceneRouter.phase_changed.connect(func(id, phase):
		route_phases.append({"id": id, "phase": phase, "screen": SceneRouter.current_screen_id,
			"covered": Expedition.art.curtain.covered, "ready": Expedition.art.ready_kind,
			"root_active": SceneRouter.get_current_node().is_visible_in_tree(),
			"round_revision": Expedition.bridge.build_revisions.get(Item.Owner.PlayerInventory, 0)}))

func verify_routes():
	var actors := [Game.playerNode.get_instance_id(), Game.opponentNode.get_instance_id()]
	var carriers := [Game.titleScreen.get_instance_id(), Game.shopSceneNode.get_instance_id(), Game.combatSceneNode.get_instance_id()]
	var run_id: String = Expedition.flow.run.run_id
	var rng: Dictionary = Expedition.flow.run.rng.duplicate(true)
	var checkpoint: Dictionary = Expedition.flow.run.combat_checkpoint.duplicate(true)

	Expedition.continue_run()
	var before_commit = SceneRouter.last_request_id
	check(await wait_for(func(): return SceneRouter.diagnostics().phase == &"preparing" and is_instance_valid(Game.OPPONENT)), "fast cancel catches actual staged enemy before commit")
	await Expedition.return_to_title()
	await settle()
	check(SceneRouter.result(before_commit).get("error") == ERR_SKIP and not SceneRouter.result(before_commit).get("committed", true), "staged combat request cancels before commit")
	check(SceneRouter.current_screen_id == &"title" and not is_instance_valid(Game.OPPONENT), "title wins cancellation and removes the staged enemy")

	var handoff := {"covered": false}
	var redirect = func(_id, phase):
		if phase == &"settling" and SceneRouter.current_screen_id == &"combat":
			var ticket = Expedition.art.curtain.generation
			Expedition.return_to_title()
			handoff.covered = Expedition.art.curtain.covered and Expedition.art.curtain.generation == ticket
	SceneRouter.phase_changed.connect(redirect)
	Expedition.continue_run()
	var after_commit = SceneRouter.last_request_id
	check(await wait_for(func(): return SceneRouter.last_request_id > after_commit and idle(), 15.0), "new title request wins reentry from a combat commit")
	SceneRouter.phase_changed.disconnect(redirect)
	check(handoff.covered, "reentry keeps the existing cloud over the committed view while its art is still preparing")
	check(SceneRouter.result(after_commit).get("error") == ERR_SKIP and SceneRouter.result(after_commit).get("committed", false), "superseded committed view reports cancellation without rolling back domain")
	check(Expedition.flow.run.run_id == run_id and Expedition.flow.run.rng == rng and Expedition.flow.run.combat_checkpoint == checkpoint, "cancellation preserves saved combat and all RNG streams")
	check(not InputBlocker.isActive() and Expedition.loading_screen.mode.is_empty(), "reentry releases both visual locks and loading overlay")
	await resume_from_title()
	check(SceneRouter.current_screen_id == &"combat" and Expedition.native_battle_ready and idle(), "normal continue succeeds after two supersessions")
	await Expedition.return_to_title()
	await settle()

	for row in route_results:
		var events = route_events.filter(func(event): return event.id == row.id).map(func(event): return event.event)
		if row.error == ERR_SKIP:
			check(events.count("screen_changed") == 0, "cancelled request emits no screen_changed: %s" % row.id)
			continue
		check(row.error == OK and row.committed and events.count("screen_changed") == 1, "committed route emits a single screen_changed: %s" % row.id)
		var phases = route_phases.filter(func(phase): return phase.id == row.id)
		var settled = phases.filter(func(phase): return phase.phase == &"settling")
		var revealed = phases.filter(func(phase): return phase.phase == &"revealing")
		if not check(settled.size() == 1 and revealed.size() == 1, "route settles and reveals exactly once: %s" % row.id): continue
		var commit = settled[0]
		var reveal = revealed[0]
		check(commit.covered and commit.screen == row.screen and commit.root_active and reveal.covered and reveal.ready == row.screen, "commit and target readiness occur under the cloud: %s" % row.id)
		match row.screen:
			&"title":
				check(events == ["return_to_title", "returned_to_title", "screen_changed"], "title compatibility events once: %s" % row.id)
			&"shop":
				var from_title = ["switch_to_shop", "title_to_shop", "pre_shop_opened_from_title", "run_started", "shop_opened", "screen_changed"]
				var from_combat = ["pre_shop_opened_from_combat", "shop_opened", "screen_changed"]
				check(events == from_title or events == from_combat, "shop compatibility events once: %s" % row.id)
				check(reveal.round_revision == commit.round_revision + 1, "shop entry builds one native round: %s" % row.id)
			&"combat":
				var opening = ["shop_closed", "switching_to_combat", "combat_scene_entered", "screen_changed"]
				check(events == opening or events == ["combat_start_pressed"] + opening, "combat compatibility events once: %s" % row.id)
	check(legacy_animations.is_empty(), "routed entries never start the legacy SceneAnimation")
	check(actors == [Game.playerNode.get_instance_id(), Game.opponentNode.get_instance_id()] and carriers == [Game.titleScreen.get_instance_id(), Game.shopSceneNode.get_instance_id(), Game.combatSceneNode.get_instance_id()], "native anchors and all three original carrier identities survive all routes")
	var current_title = SceneRouter.get_current_node()
	check(initial_title.get_ref() == null and is_instance_valid(current_title) and current_title == Expedition.art.ui and current_title.scene_file_path == "res://PvE/UI/TitleScreen.tscn", "title is released and instantiated again after returning")
	check(current_title.is_visible_in_tree() and not Game.titleScreen.visible and Game.titleScreen.process_mode == Node.PROCESS_MODE_DISABLED and not Game.shopSceneNode.visible and not Game.combatSceneNode.visible and not is_instance_valid(Game.OPPONENT), "only the routed title is visible while compatibility carriers stay mounted")

func verify_title_shutdown():
	var title = weakref(SceneRouter.get_current_node())
	var title_path := "res://PvE/UI/TitleScreen.tscn"
	Expedition.native_routes.change(&"title", "qa_shutdown_prepared_title")
	var id = SceneRouter.last_request_id
	check(await wait_for(func(): return SceneRouter.diagnostics().phase == &"prepared"), "shutdown probe reaches prepared replacement title")
	Game._begin_shutdown()
	await AssetStream.drain()
	for frame in 3: await get_tree().process_frame
	var cancelled = SceneRouter.result(id)
	check(cancelled.get("error") == ERR_SKIP and not cancelled.get("committed", true), "shutdown cancels the prepared title before commit")
	check(title.get_ref() == null and SceneRouter.get_current_node() == null and not AssetStream.resources.has(title_path), "shutdown frees current and prepared title resources")
	check(not Expedition.art.curtain.busy and not Expedition.loading_screen.visible, "shutdown clears title transition and loading overlay")

func finish():
	var file=FileAccess.open(output.path_join("core-flow-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"route_results":route_results,"route_phases":route_phases,"route_events":route_events,"legacy_animations":legacy_animations},"\t"));file.close()
	print("CORE_FLOW_QA ",checks.size()," failures=",failures)
	Game._begin_shutdown();await AssetStream.drain()
	await get_tree().create_timer(0.12,true,false,true).timeout
	get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
