extends Node
## Exercise real instances, footprint fitting, rotation and chapter residency.
const ART=preload("res://PvE/Art/SuppliedArt.gd")
var output=""
var checks:Array=[]
var failures:Array=[]
func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func check(value,message):
	checks.append({"ok":bool(value),"message":message})
	if not value:failures.append(message);print("ART_FAIL ",message)
func settle():
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	for frame in 6:await get_tree().process_frame
func shot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	await shot("title")
	var title_background=Game.titleScreen.get_node("Node2D/Background/SuppliedTitleBackdrop")
	var top=title_background.to_global(title_background.get_rect().position)
	var bottom=title_background.to_global(title_background.get_rect().end)
	check(top.x<=1 and top.y<=1 and bottom.x>=1919 and bottom.y>=1079,"new title art covers the entire viewport")
	var holder=Node2D.new();holder.hide();Game.mainNode.add_child(holder)
	var instances:Array=[]
	for id in ART.ITEMS:
		check(await AssetStream.prepare(Expedition.bindings.scene_paths([id]),"art-probe"),id+": async dependencies")
		var item=await Expedition.bindings.instance_async(id,Item.Owner.BuildViewerIcon,"art-probe")
		holder.add_child(item);await get_tree().process_frame
		item.ownerType=Item.Owner.Shop
		item.set_meta("pve_entry",{"definition_id":id,"uid":"probe_"+id,"rotation":0,"x":0,"y":0})
		Expedition.bridge.fit_native_visual(item)
		check(item.sprite.texture.resource_path==ART.item_path(id),id+": real shelf sprite uses supplied PNG")
		check(not item.sprite.region_enabled and item.sprite.hframes==1 and item.sprite.vframes==1,id+": entire single-frame image retained")
		check(not item.sprite.flip_h and not item.sprite.flip_v,id+": shelf image is upright")
		var rect:Rect2=item.get_meta("pve_visual_bounds")
		check(rect.size.x<=185 and rect.size.y<=161,id+": shelf image fits display bounds")
		item.ownerType=Item.Owner.BuildViewerIcon
		Expedition.bridge.fit_native_visual(item)
		var cells=Expedition.flow.placement.local_cells(item.get_meta("pve_entry"))
		var occupied={};for cell in cells:occupied[Vector2i(cell)]=true
		var geometry=Expedition.bridge.footprint_layout.geometry(item)
		var fit=item.get_meta("pve_visual_fit");var anchor:Vector2=item.get_meta("pve_anchor")
		var inside=true
		for point in geometry.points:
			var local_point=item.sprite.position-anchor+Vector2(point)*float(fit.factor)
			if not occupied.has(Vector2i((local_point/80.0).floor())):inside=false;break
		check(inside,id+": visible artwork lies over occupied cells")
		for direction in 4:
			item.setFaceDirectionInstant(direction)
			check(item.sprite.texture.resource_path==ART.item_path(id),id+": rotation "+str(direction)+" retains supplied texture")
		item.setFaceDirectionInstant(0)
		item.playActivationAnimation(Item.ActivationAni.Stab,false)
		instances.append(item)
	for frame in 40:
		await get_tree().process_frame
		if frame in [0,15,39]:
			for item in instances:check(item.sprite.texture.resource_path==ART.item_path(str(item.get_meta("pve_definition_id"))),str(item.get_meta("pve_definition_id"))+": activation retains replacement frame "+str(frame))
	for item in instances:item.free()
	holder.queue_free();AssetStream.release("art-probe")
	check(ART.item_path("unplanned_bow").is_empty(),"no unplanned item bindings")
	for role in ["armorer","alchemist"]:
		check(Expedition.flow.new_run(role,role+"_"+("blades" if role=="armorer" else "toxin"),"tutorial",1337,true).ok,role+": public new run")
		await settle()
		Expedition.flow.skip_tutorial()
		if Expedition.flow.screen_state=="ROUTE_SELECT":Expedition.flow.choose_route(0)
		await settle()
		check(Game.state==Game.State.Shop,role+": native shop entered")
		check(Game.PLAYER.sprite.get_meta("new_art_path")==ART.actor_path(role),role+": distinct player illustration")
		check(Game.PLAYER.sprite.body.texture.resource_path==ART.shop_actor_path(role),role+": supplied shop portrait")
		await shot(role+"-shop")
		Game.startCombatButton.activateButton();await settle()
		check(Game.state==Game.State.Combat,role+": native battle entered")
		check(Game.PLAYER.sprite.body.texture.resource_path==ART.actor_path(role),role+": full figure in combat")
		await shot(role+"-combat")
		Expedition.return_to_title();await settle()
	for act in 3:
		Expedition.flow.run.act=act+1
		check(await Expedition.scenery.ensure_view("combat"),"chapter "+str(act+1)+": streamed background")
		var background=Game.combatSceneNode.backgroundNode.get_node("Desert")
		check(background.texture.resource_path==ART.ROOT+"backgrounds/"+["forest","desert","volcano"][act]+".png","chapter background mapping")
		Expedition.scenery.unload("combat");await get_tree().process_frame
	check(not Expedition.scenery.live.has("combat"),"unused chapter scenery released")
	Expedition.flow.screen_state="REST";Expedition.menus.runs.event();await settle()
	var camp=Expedition.panel.find_child("RestCampArt",true,false)
	check(camp!=null and camp.texture!=null and camp.texture.resource_path==ART.ROOT+"ui/camp.png","rest camp loaded through guarded popup resource scope")
	await shot("rest-camp")
	var file=FileAccess.open(output.path_join("supplied-art-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
