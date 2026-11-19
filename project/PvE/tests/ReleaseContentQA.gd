extends "res://PvE/tests/RestartResidencyQA.gd"
var observations:Array=[]
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	check(Game.lastCursorType>=0,"startup initializes the actual cursor without waiting for a new hover state")
	for cursor_index in 6:
		var expected=Game.cursors[cursor_index].duplicate()
		var actual=Game.scaledCursors[cursor_index].get_image()
		expected.resize(actual.get_width(),actual.get_height(),Image.INTERPOLATE_TRILINEAR)
		check(expected.get_data()==actual.get_data(),"active cursor pixels match supplied hand state: "+str(cursor_index))
	var catalogue=Expedition.db.release_catalog
	check(catalogue.characters==["armorer","archer"],"new content tracks remain warrior and archer")
	check(catalogue.selectable_characters==["armorer","archer","alchemist"],"selection restores all three existing professions")
	check(Expedition.db.starting_loadouts("alchemist").size()==2,"restored alchemist has both existing loadouts")
	check(catalogue.items.size()>=60 and catalogue.bags.size()==8 and catalogue.recipes.size()>=18,"release scope satisfies frozen minimums")
	for row in Expedition.db.rows("tutorial_steps"):Expedition.flow.profile_service.profile.tutorial_completed.append(row.id)
	for role in catalogue.characters:
		for loadout in catalogue.loadouts[role]:
			check(Expedition.create_run(role,loadout,"tutorial",1337,true).ok,"new release setup is valid: "+loadout)
			check(Expedition.db.release_run(Expedition.flow.run),"new setup has explicit release content identity")
			check(Expedition.flow.placement.validate(Expedition.flow.run.build).ok,"starting equipment fully fits new bag: "+loadout)
			Expedition.flow.choose_route(0)
			check(await wait_until(func():return Game.state==Game.State.Shop and idle()),"different-role release shop loads: "+loadout)
			check(Game.PLAYER.sprite.get("art_key")==role,"carrier adapter displays the selected hero: "+role)
			var backdrop=Game.shopSceneNode.get_node("Background")
			check(backdrop.texture!=null and backdrop.is_visible_in_tree(),"shop backdrop is present: "+loadout)
			if backdrop.texture!=null:check(backdrop.texture.resource_path=="res://Art/Supplied20261102/shop/shop_vignette.png","shop uses current supplied backdrop")
			var origin=Game.PLAYER.INVENTORY.cellToGlobalPos(Vector2.ZERO)
			check(is_equal_approx(Game.PLAYER.INVENTORY.cellToGlobalPos(Vector2.RIGHT).distance_to(origin),64.0),"new grid horizontal spacing is 64 presentation pixels")
			check(is_equal_approx(Game.PLAYER.INVENTORY.cellToGlobalPos(Vector2.DOWN).distance_to(origin),64.0),"new grid vertical spacing is 64 presentation pixels")
			check(Game.STORAGEBOX.has_meta("art_storage_slots") and (not is_instance_valid(Game.STORAGEBOX.pve_slot_root) or Game.STORAGEBOX.pve_slot_root.get_child_count()==0),"cloth storage never adds a second grid")
			for slot in Expedition.flow.run.shop.slots:check(Expedition.db.release_contains("bags" if slot.get("kind","")=="bag" else "items",slot.definition_id),"new shop never mixes legacy item definitions")
			await shot("shop-"+loadout)
			observations.append({"loadout":loadout,"grid_scale":Game.PLAYER.INVENTORY.scale,"background_live":Expedition.scenery.live.has("shop")})
			await Expedition.return_to_title();await settle()
	# Test each supplied definition through its actual native scene and binding,
	# including long upright artwork, new bag shapes and tint variants.
	Expedition.create_run("archer","archer_precision","tutorial",1431,true)
	var holder=Node2D.new();holder.hide();Game.mainNode.add_child(holder)
	var probes:Array=[]
	var probe_ids:Array=catalogue.items+catalogue.bags
	if "--no-art-probes" in OS.get_cmdline_user_args():probe_ids=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-count="):probe_ids=probe_ids.slice(0,int(arg.trim_prefix("--probe-count=")))
	for id in probe_ids:
		check(await AssetStream.prepare(Expedition.bindings.scene_paths([id]),"release-art-probe"),"asynchronous resources resolve: "+id)
		var item=await Expedition.bindings.instance_async(id,Item.Owner.BuildViewerIcon,"release-art-probe")
		if "--orphan-diagnostic" in OS.get_cmdline_user_args():print("CREATED_PROBE ",item.get_instance_id()," ",id)
		check(item!=null,"native item instantiates: "+id)
		if item==null:continue
		holder.add_child(item);await get_tree().process_frame
		item.set_meta("pve_entry",{"definition_id":id,"uid":"probe-"+id,"x":0,"y":0,"rotation":0})
		item.ownerType=Item.Owner.Shop;item.set_meta("pve_drag_layout",false)
		Expedition.bridge.fit_native_visual(item)
		var path=Expedition.bindings.replacement_path(id)
		check(item.sprite.texture.resource_path==path,"actual shelf sprite uses configured current art: "+id)
		check(is_zero_approx(item.get_rotation()),"shelf item is upright: "+id)
		item.ownerType=Item.Owner.PlayerInventory;item.set_meta("pve_drag_layout",true)
		Expedition.bridge.fit_native_visual(item)
		var bounds:Rect2=item.get_meta("pve_visual_bounds")
		var size:Vector2=item.get_meta("pve_size")
		check(bounds.size.x<=size.x*1.04+1 and bounds.size.y<=size.y*1.04+1,"grid graphic stays within occupied envelope: "+id)
		if item.isBag():check(is_equal_approx(item.spriteScale.x,item.spriteScale.y),"new bag texture is not stretched: "+id)
		item.ownerType=Item.Owner.BuildViewerIcon
		probes.append(item)
	for frame in 40:await get_tree().process_frame
	for item in probes:
		var probe_id=item.get_instance_id();item.free()
		check(not is_instance_id_valid(probe_id),"probe is physically freed: "+str(probe_id))
	probes.clear()
	AssetStream.release("release-art-probe");holder.queue_free()
	check(Game.cursors[0].get_size()==Vector2i(48,49),"default cursor uses supplied hand dimensions")
	check(Game.cursors[2].get_size()==Vector2i(48,49) and Game.cursors[4].get_size()==Vector2i(48,49),"grab and interact states use supplied hand")
	# A target scene is protected throughout an asynchronous actor transaction.
	Expedition.entering_shop=true
	check(await Expedition.scenery.ensure_view("shop"),"background residency starts independently")
	Expedition.scenery.trim_inactive()
	check(Game.shopSceneNode.get_node("Background").texture!=null,"inactive trimming respects in-progress shop entry")
	Expedition.entering_shop=false;Expedition.scenery.unload("shop")
	check(Game.shopSceneNode.get_node("Background").texture==null,"unneeded shop background actually unloads")
	await Expedition.return_to_title();await settle()
	if "--orphan-diagnostic" in OS.get_cmdline_user_args():Node.print_orphan_nodes()
	var file=FileAccess.open(output.path_join("release-content-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"active_items":catalogue.items.size(),"active_bags":catalogue.bags.size(),"active_recipes":catalogue.recipes.size()},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain()
	await get_tree().create_timer(0.12,true,false,true).timeout
	await get_tree().process_frame;await get_tree().process_frame
	get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
