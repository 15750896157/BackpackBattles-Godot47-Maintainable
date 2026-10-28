extends Node
var output=""
var samples:Array=[]
var failures:Array=[]
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func idle():await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
func sample(label):
	var max_error=0.0;var worst={}
	var sprite_error=0.0
	for actor in [Game.PLAYER,Game.OPPONENT]:
		if not is_instance_valid(actor):continue
		for item in actor.INVENTORY.getItems():
			if not item.has_meta("pve_entry"):continue
			var entry=item.get_meta("pve_entry")
			var expected=actor.INVENTORY.tilemap.to_global(LegacyGrid.cell_origin(actor.INVENTORY.tilemap,Vector2(entry.x,entry.y)))
			var error=item.getTopLeftGlobal().distance_to(expected)
			if error>max_error:max_error=error;worst={"uid":entry.uid,"id":entry.definition_id,"offset":item.getTopLeftGlobal()-expected,"mode":item.mode,"owner":item.ownerType}
			sprite_error=maxf(sprite_error,item.sprite.position.distance_to(item.get_meta("pve_sprite_position",Vector2.ZERO)))
	samples.append({"label":label,"max_error_px":max_error,"sprite_offset_px":sprite_error,"worst":worst})
	if max_error>1.0:failures.append(label+": grid anchor drift "+str(max_error))
	if sprite_error>24.0:failures.append(label+": activation sprite escapes occupied cells "+str(sprite_error))
func run_tests():
	while not Expedition.initialized:await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(output)
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0);await idle()
	sample("shop")
	Game.startCombatButton.activateButton();await idle();Expedition.set_playback(1.0,false)
	for actor in [Game.PLAYER,Game.OPPONENT]:
		for item in actor.INVENTORY.getItems():
			if not item.isBag():item.playActivationAnimation(Item.ActivationAni.Stab,false)
	for frame in 120:
		await get_tree().process_frame
		if frame%10==0:sample("combat_"+str(frame))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("combat.png"))
	await Expedition.return_to_title();await idle()
	await Expedition.continue_run();await idle();Expedition.set_playback(1.0,true)
	for frame in 45:
		await get_tree().process_frame
		if frame%15==0:sample("reopened_"+str(frame))
	var file=FileAccess.open(output.path_join("combat-anchors-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":samples.size(),"failures":failures,"samples":samples},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
