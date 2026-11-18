extends "res://tests/combat_tests.gd"
func entry(id:String,uid:String,x=0,y=0)->Dictionary:
	return {"definition_id":id,"uid":uid,"x":x,"y":y,"rotation":0,"used":false,"purchase_price":0,"purchased_visit":-1}
func build_fixture()->Dictionary:
	return {"width":9,"height":7,"bags":[entry("bag_release_transport","bag")],"items":[],"storage":[],"storage_capacity":2}
func run_tests():
	db=ContentDB.new()
	var release=db.release_catalog;var placement=PlacementService.new(db);var crafting=CraftingService.new(db)
	check(db.errors.is_empty() and release.characters==["armorer","archer"],"release has exactly warrior and archer selectable")
	check(release.items.size()==76 and release.bags.size()==8 and release.recipes.size()==18,"all reviewed release definitions are registered")
	var counts={"public":0,"armorer":0,"archer":0}
	for id in release.items:
		var row=db.get_row("items",id);counts[row.owner_pool]+=1
		check(row.icon_ref.begins_with("res://Art/Supplied20261102/items/"),id+": configured current icon")
		if "elite_loot" in row.tags or "material" in row.tags:check(not row.shop_enabled,id+": restricted loot never enters ordinary shop")
	check(counts.public>=40 and counts.armorer>=10 and counts.archer>=10,"public and exclusive pool quotas are met")
	for role in release.characters:
		for loadout in release.loadouts[role]:
			for seed_value in [1337,1855,3371]:
				var flow=GameFlow.new(db,SaveService.new(OS.get_user_data_dir().path_join("release-tests/"+loadout+str(seed_value))))
				check(flow.new_run(role,loadout,"tutorial",seed_value,true).ok,loadout+": actual setup succeeds")
				check(placement.validate(flow.run.build).ok,loadout+": actual starter arrangement is legal")
				flow.skip_tutorial();flow.choose_route(0)
				check(flow.screen_state=="SHOP_PREPARE",loadout+": first actual route enters shop")
				for index in 5:
					var generated=flow.shop_generator.generate(flow.run,index>0)
					check(generated.ok,loadout+": seeded refresh succeeds")
					for slot in flow.run.shop.slots:
						check(db.release_contains("bags" if slot.kind=="bag" else "items",slot.definition_id),"new pools exclude compatibility definitions")
				var snapshot_player=flow.snapshots.player(flow.run)
				var snapshot_enemy=flow.snapshot_enemy(flow.run.current_node)
				var a=EngineClass.new(db).simulate(snapshot_player,snapshot_enemy,35421)
				var b=EngineClass.new(db).simulate(snapshot_player,snapshot_enemy,35421)
				check(a.ok and a.replay_digest==b.replay_digest,loadout+": deterministic new-content combat")
				var rewards=RewardService.new(db)
				flow.run.current_node.type="elite_combat"
				var options=rewards.generate(flow.run,"reward_elite")
				check(options.any(func(value):return value.id=="elite_crest_choice"),"every elite offers a configured crest choice")
				flow.run.current_node.type="normal_combat"
				check(rewards.content_pool(flow.run,"item_pool",{"tag":"elite_loot"}).is_empty(),"crest cannot drop from ordinary reward pool")
	for id in release.recipes:
		var recipe=db.get_row("recipes",id);var materials=[]
		for row in db.rows("recipe_ingredients"):
			if row.recipe_id==id:materials.append(row.item_id)
		var build=build_fixture();var width=0
		for cell in placement.local_cells(entry(materials[0],"a")):width=maxi(width,cell.x+1)
		build.items=[entry(materials[0],"a"),entry(materials[1],"b",width,0)]
		var run={"build":build,"act":3,"visit":1,"run_id":"recipe-test","next_uid":10,"pending_rewards":[]}
		check(placement.validate(build).ok,id+": materials occupy distinct supported cells")
		var result=crafting.execute(run,id)
		check(result.ok,id+": actual manual crafting transaction succeeds")
		if result.ok:check(result.entry.definition_id==recipe.result_item_id and placement.validate(run.build).ok,id+": result and final layout are valid")
	var spatial=SpatialQueryService.new(db)
	var tagged={"width":9,"height":7,"bags":[entry("bag_release_weapon","weaponbag")],"items":[entry("supply_dagger","blade",0,0),entry("supply_fruit","fruit",1,1)],"storage":[],"storage_capacity":2}
	check(spatial.active_special_effects(tagged,"fruit").is_empty(),"weapon bag never grants its tag bonus to food")
	var attacker=snapshot([item("attack",[effect("physical_damage","value:10")],1.0)],150)
	var thorns=snapshot([item("thorns",[effect("apply_status","value:thorns:3|duration:60","combat_start","self")])],150)
	var reflected=EngineClass.new(db).simulate(thorns,attacker,123)
	check(reflected.ok and reflected.full_events.any(func(value):return value.get("status_id","")=="thorns" and value.type=="STATUS_DAMAGE"),"thorns reflect real physical hits without recursion")
	var resistant=snapshot([item("resist",[effect("apply_status","value:resistance:5|duration:60","combat_start","self")])],150)
	var reduced=EngineClass.new(db).simulate(resistant,attacker,123)
	check(reduced.ok and reduced.full_events.any(func(value):return value.type=="PHYSICAL_DAMAGE" and value.target_side==0 and value.value==8.0),"resistance contributes within shared physical reduction cap")
	print("RELEASE_RULES_TESTS "+JSON.stringify({"checks":checks,"failures":failures,"pool_counts":counts,"content_version":db.content_version}))
	quit(0 if failures.is_empty() else 1)
