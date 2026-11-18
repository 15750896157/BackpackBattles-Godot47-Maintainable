extends "res://PvE/tests/NativeFeedbackQA.gd"
## Actual combat wiring plus explicitly marked presentation-only effect fixtures.
const PALETTE = preload("res://PvE/Art/CombatPalette.gd")
var frames_ms: Array = []
var test_role: String = "armorer"

func snapshot(name: String):
	# Capture transient poses/effects on this frame, before they expire.
	check(not Expedition.art.curtain.busy and not Expedition.loading_screen.visible,"capture is past actual loading curtain: "+name)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))

func real_frames(count: int) -> void:
	for index in count: await get_tree().process_frame

## Effects age in seconds; a fixed frame count expires too early on high-refresh GPUs.
func real_seconds(duration: float) -> void:
	var deadline: int = Time.get_ticks_usec()+int(duration*1000000.0)
	while Time.get_ticks_usec()<deadline:
		await get_tree().process_frame

func start_combat(reduced: bool) -> bool:
	Expedition.set_process(true)
	await Expedition.return_to_title();await frames(4)
	for key in ["reduce_flash","reduce_motion","reduce_effects"]: Expedition.preferences.values[key]=reduced
	var loadout="archer_precision" if test_role=="archer" else "warrior_blades"
	check(Expedition.create_run(test_role,loadout,"tutorial",71015,true).ok,"current release run starts: "+loadout)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0)
	check(await wait_for(func():return Game.state==Game.State.Shop and not Game.sceneAnimation.is_playing() and not Expedition.entering_shop,25),"new-role shop is ready")
	await frames(2);Game.startCombatButton.activateButton()
	var ready=await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and not Game.sceneAnimation.is_playing(),25)
	check(ready,"current release combat is ready: "+test_role)
	await frames(4)
	Expedition.set_process(false)
	return ready

func pose_test() -> void:
	var fx = Expedition.art.combat_fx
	var portrait = Game.PLAYER.sprite
	var body: Sprite2D = portrait.get_node("Body")
	var entries = Expedition.flow.run.build.duplicate(true)
	for kind in ["slash","heavy","arrow","arcane"]:
		fx.clear(); portrait.attack(kind)
		check(await wait_for(func(): return absf(body.skew) > 0.005, 0.35), "attack visibly deforms supplied portrait: "+kind)
		var feet = body.to_global(Vector2(body.texture.get_width()*0.5,body.texture.get_height()))
		check(feet.distance_to(portrait.global_position)<0.1,"pose keeps feet anchored: "+kind)
		await snapshot("pose-"+kind)
	fx.clear(); portrait.hurt()
	check(await wait_for(func(): return absf(body.skew) > 0.005, 0.35), "damage creates a distinct recoil pose")
	await snapshot("pose-hurt")
	fx.clear();portrait.defend()
	check(await wait_for(func(): return absf(body.skew) > 0.005, 0.35), "defense creates a guarded pose")
	await snapshot("pose-guard")
	check(await wait_for(func(): return is_zero_approx(body.skew) and is_zero_approx(body.rotation), 0.65), "pose returns to neutral without accumulating transforms")
	check(Expedition.flow.run.build==entries,"portrait deformation never changes canonical grid/build")

func palette_and_equipment() -> void:
	var holder = Node2D.new();Game.mainNode.add_child(holder)
	var gallery = CanvasLayer.new();gallery.layer=65;add_child(gallery)
	var backdrop=ColorRect.new();backdrop.position=Vector2(350,720);backdrop.size=Vector2(1200,280);backdrop.color=Color(0.035,0.05,0.07,0.96);gallery.add_child(backdrop)
	var evidence_rows:Array=[]
	for id in ["supply_dagger","supply_flint","supply_magic_bow","supply_battle_axe","supply_holy_bulwark"]:
		var row = Expedition.db.get_row("items",id)
		check(not row.is_empty(),"equipment preview is a real content definition: "+id)
		if row.is_empty(): continue
		var profile = PALETTE.profile(row)
		check(await AssetStream.prepare(Expedition.bindings.scene_paths([id]),"vfx-probe"),"glowing equipment resolves asynchronously: "+id)
		var item = await Expedition.bindings.instance_async(id,Item.Owner.BuildViewerIcon,"vfx-probe")
		check(item!=null,"glowing equipment uses real item view: "+id)
		if item==null: continue
		holder.add_child(item);await real_frames(1)
		Expedition.art.lighting.apply_to_item(item,true)
		var strength = float(item.sprite.material.get_shader_parameter("emission_strength"))
		check(is_equal_approx(strength,float(profile.glow)),"shader emission matches element/rarity: "+id)
		var display=Sprite2D.new();display.texture=Expedition.bindings.texture_for(id);display.material=item.sprite.material
		display.position=Vector2(480+evidence_rows.size()*230,850);display.scale=Vector2.ONE*minf(170.0/display.texture.get_width(),200.0/display.texture.get_height());gallery.add_child(display)
		evidence_rows.append({"id":id,"kind":profile.kind,"color":str(profile.color),"rank":profile.rank,"glow":strength})
		Expedition.art.lighting.apply_to_item(item,false)
		check(item.sprite.material==null or item.sprite.material!=Expedition.art.lighting.surface,"reduced effects restores original material: "+id)
		item.free()
	await real_frames(2);await snapshot("equipment-emission-gallery")
	gallery.queue_free()
	holder.queue_free();AssetStream.release("vfx-probe")
	evidence.equipment = evidence_rows
	var common = PALETTE.profile({"rarity":"common","tags":"weapon"})
	var rare = PALETTE.profile({"rarity":"rare","tags":"weapon"})
	var legendary = PALETTE.profile({"rarity":"legendary","tags":"weapon"})
	check(common.glow==0.0 and legendary.glow>rare.glow,"ordinary steel stays unlit and higher rarity gets stronger emission")
	check(common.rarity_color!=rare.rarity_color and rare.rarity_color!=legendary.rarity_color,"rarity has distinguishable colors")
	check(PALETTE.profile(Expedition.db.get_row("items","supply_bread")).glow==0.0,"ordinary food does not glow like enchanted equipment")

func effect_fixtures() -> void:
	var fx = Expedition.art.combat_fx
	var profiles = {"slash":"supply_dagger","heavy":"supply_battle_axe","arrow":"supply_hero_bow","arcane":"supply_basic_staff","guard":"supply_leather_armor","heal":"supply_bread","status":"supply_basic_staff","impact":"supply_battle_axe"}
	for kind in profiles:
		fx.clear()
		fx.emit(kind,0,PALETTE.profile(Expedition.db.get_row("items",profiles[kind])),kind=="impact")
		await real_frames(7)
		check(not fx.bursts.is_empty(),"live rendered effect exists: "+kind)
		await snapshot("effect-"+kind)
		await real_seconds(0.65)
		check(fx.bursts.is_empty() and not fx.is_processing(),"effect expires and processing stops: "+kind)
	fx.emit("arrow",0,PALETTE.profile(Expedition.db.get_row("items","supply_hero_bow")))
	await real_frames(3)
	Expedition.set_playback(1.0,true)
	var age = float(fx.bursts[0].age)
	await real_frames(12)
	check(is_equal_approx(float(fx.bursts[0].age),age),"particles freeze during real combat pause")
	Expedition.set_playback(2.0,false)
	await real_seconds(0.35)
	check(fx.bursts.is_empty(),"particles expire under 2x combat playback")
	Expedition.set_playback(1.0,false)
	var profile = PALETTE.profile(Expedition.db.get_row("items","supply_battle_axe"))
	for index in 120:
		for burst in fx.bursts: burst.age = 0.1
		fx.emit(["slash","heavy","arrow","arcane","guard","impact"][index%6],index%2,profile,true)
	check(fx.bursts.size()<=fx.MAX_BURSTS and fx.particle_count<=fx.MAX_PARTICLES,"120-event overload remains within burst and particle budgets")
	evidence.peak_particles = fx.peak_particles
	await snapshot("effect-budget-stress")
	fx.clear()
	for index in 120:
		if index%4==0: fx.emit(["slash","heavy","arrow","arcane","guard"][index%5],index%2,profile,true)
		var started=Time.get_ticks_usec()
		await get_tree().process_frame
		frames_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
	frames_ms.sort()
	evidence.active_combat_sample={"frames":frames_ms.size(),"frame_median_ms":frames_ms[60],"frame_p95_ms":frames_ms[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"peak_particles":fx.peak_particles}
	fx.clear()
	Expedition.preferences.values.reduce_flash=true
	fx.emit("heavy",0,profile)
	check(is_equal_approx(float(fx.light_material.get_shader_parameter("flash_limit")),0.55),"reduce-flash dims local emission")
	fx.clear();Expedition.preferences.values.reduce_effects=true
	fx.emit("arrow",0,profile)
	check(fx.bursts.is_empty(),"reduce-effects suppresses all new particles")
	Expedition.preferences.values.reduce_effects=false;Expedition.preferences.values.reduce_flash=false
	Expedition.preferences.values.reduce_motion=true
	Game.PLAYER.sprite.attack("heavy");await real_frames(4)
	check(is_zero_approx(Game.PLAYER.sprite.body.skew),"reduce-motion suppresses pose distortion")
	Expedition.preferences.values.reduce_motion=false
	fx.clear()

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	check(await wait_for(func():return Expedition.initialized,90),"actual original Main initialized")
	var defaults = Expedition.preferences.values.duplicate(true)
	if await start_combat(false):
		var result_before=JSON.stringify(Expedition.flow.combat_result,"",true)
		var rng_before=JSON.stringify(Expedition.flow.run.rng,"",true)
		var fx=Expedition.art.combat_fx
		for index in Expedition.flow.combat_result.full_events.size():
			if Expedition.flow.combat_result.full_events[index].type=="ITEM_ACTIVATED":play_batch(index);break
		check(not fx.emitted.is_empty(),"actual event playback reaches new visual effects")
		await pose_test();await palette_and_equipment();await effect_fixtures()
		check(JSON.stringify(Expedition.flow.combat_result,"",true)==result_before,"all new effects leave full combat result byte-identical")
		check(JSON.stringify(Expedition.flow.run.rng,"",true)==rng_before,"all new effects consume no authoritative RNG")
		Expedition.flow.advance_combat(10000);Expedition.show_battle_result();await frames(4)
		check(fx.bursts.is_empty(),"settlement clears transient battle effects")
		var outcome := "victory" if int(Expedition.flow.combat_result.winner_side) == 0 else "defeat"
		var suffix := "zh" if TranslationServer.get_locale().begins_with("zh") else "ribbon"
		var result_key := "result_%s_%s" % [outcome,suffix]
		var emblem: TextureRect = Expedition.panel.find_child("Ref_"+result_key,true,false)
		check(emblem!=null and emblem.is_visible_in_tree() and emblem.texture!=null and emblem.texture.resource_path=="res://Art/Supplied20261109/ui/"+result_key+".png","result displays the supplied banner for its actual outcome")
		for key in ["guide","home"]:
			var image=Expedition.menus.shell.image(key)
			check("Supplied20261102" in image.resource_path,"settlement toolbar uses current art: "+key)
		await snapshot("result-current-icons")
		await Expedition.return_to_title();await frames()
		check(fx.bursts.is_empty() and not fx.is_processing(),"title return unloads effects and stops updates")
		test_role="archer"
		if await start_combat(false):
			var arrows=int(fx.emitted.get("arrow",0))
			for index in Expedition.flow.combat_result.full_events.size():
				var event=Expedition.flow.combat_result.full_events[index]
				if event.type=="ITEM_ACTIVATED" and int(event.source_side)==0 and PALETTE.event_profile(event,Expedition.db,Expedition.flow.combat_result).kind=="arrow":
					play_batch(index);break
			check(int(fx.emitted.get("arrow",0))>arrows,"real current archer activation selects arrow trail")
			await real_frames(6);await snapshot("actual-archer-weapon")
			var run_id=Expedition.flow.run.run_id
			await Expedition.return_to_title();await frames()
			check(fx.bursts.is_empty(),"saving mid-battle clears particles")
			Expedition.set_process(true)
			await Expedition.continue_run();await frames(4)
			check(await wait_for(func():return Expedition.flow.run.run_id==run_id and Game.state==Game.State.Combat and Expedition.native_battle_ready,25),"new effects do not break saved current-archer combat restoration")
			await Expedition.return_to_title();await frames()
	Expedition.preferences.values=defaults
	var file=FileAccess.open(output.path_join("combat-vfx-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
