extends Node
var output=""
var checks:Array=[]
var failures:Array=[]
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func check(value,message):
	checks.append({"ok":bool(value),"message":message})
	if not value:failures.append(message);print("TOUCH_FAIL ",message)
func settle():
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	for frame in 8:await get_tree().process_frame
func snapshot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))
func inspect_page(name):
	check(Expedition.panel.get_meta("menu_depth",0)==1,name+": single menu level")
	check(Expedition.panel.find_children("*","OptionButton",true,false).is_empty() and Expedition.panel.find_children("*","PopupMenu",true,false).is_empty(),name+": no nested drop-down")
	check(Expedition.popup_content.size.x<=Expedition.popup_scroll.size.x+1,name+": contents fit viewport width")
	check(not Expedition.popup_scroll.is_ancestor_of(Expedition.menu_nav),name+": fixed navigation remains reachable")
	check(Rect2(0,0,1920,1080).encloses(Expedition.panel.get_global_rect()),name+": fixed panel stays in viewport")
	check(Expedition.panel.get_global_rect().encloses(Expedition.popup_scroll.get_global_rect()),name+": content viewport inside frame")
	check(Expedition.panel.get_global_rect().encloses(Expedition.menus.shell.pager.footer.get_global_rect()),name+": page arrows inside frame")
	check(Expedition.panel.find_children("*","LineEdit",true,false).is_empty(),name+": no keyboard entry required")
	check(Expedition.popup_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,name+": no scrollbar")
	var pager=Expedition.menus.shell.pager;pager.refresh()
	for index in pager.starts.size():
		pager.index=index;pager._apply();await get_tree().process_frame
		check(Expedition.popup_scroll.scroll_vertical<=Expedition.popup_content.size.y,name+": button page "+str(index))
	pager.index=0;pager._apply()
	var before=Expedition.popup_scroll.scroll_vertical
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=Expedition.popup_scroll.global_position+Vector2(200,100)
	get_viewport().push_input(wheel,true);await get_tree().process_frame
	check(Expedition.popup_scroll.scroll_vertical==before,name+": wheel cannot change page")
	for grid in Expedition.popup_content.find_children("*","Control",true,false).filter(func(node):return node.has_meta("pve_build_grid")):
		check(Expedition.popup_scroll.get_global_rect().encloses(grid.get_global_rect()),name+": entire enemy build fits one sheet")
	for button in Expedition.popup_content.find_children("*","Button",true,false):
		if not button.has_meta("word_action") or button.text.is_empty():continue
		var width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
		check(width<=button.size.x-12,name+": complete button text fits: "+button.text)
	for label in Expedition.popup_content.find_children("*","Label",true,false):
		if not label.has_meta("text_deck"):continue
		var restored="";var font=label.get_theme_font("font");var size=label.get_theme_font_size("font_size")
		for page in label.get_meta("deck_pages"):
			restored+=page
			for line in page.split("\n"):check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=label.size.x,name+": long description fits horizontally")
		check(restored.replace("\n","").replace(" ","")==str(label.get_meta("source_text")).replace("\n","").replace(" ",""),name+": text pages retain complete description")
func click(control:Control):
	var point=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;get_viewport().push_input(motion,true)
	await get_tree().process_frame
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true);await get_tree().process_frame
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	while Game.sceneAnimation.is_playing():await get_tree().process_frame
	await settle();check(not Game.titleScreen.continueNode.is_visible_in_tree(),"no standalone continue banner");await snapshot("01-title")
	Expedition.begin_setup(Game.Mode.Ranked);await settle();await inspect_page("setup");await snapshot("02-setup")
	check(Expedition.panel.find_child("BeginExpedition",true,false)!=null,"no save goes directly to setup")
	Expedition.create_run("armorer","armorer_blades","tutorial",1337,true);await settle()
	Expedition.show_ui_guide();await settle()
	var skip=Expedition.panel.find_child("SkipTutorial",true,false);check(skip!=null,"independent guide preserves tutorial skip")
	if skip!=null:await click(skip)
	await settle();check(Expedition.flow.profile_service.profile.tutorial_completed.size()==Expedition.db.rows("tutorial_steps").size(),"guide skip persists tutorial completion")
	Expedition.flow.choose_route(0);await settle();await snapshot("03-shop")
	check(Expedition.art.ui.get_node("ArtStartBattle").size.x>=330,"prominent battle button preserved")
	check(Game.PLAYER.sprite.body.texture.get_height()*Game.PLAYER.sprite.body.scale.y>=340,"enlarged shop character preserved")
	var item=Game.PLAYER.INVENTORY.getItems().filter(func(value):return not value.isBag())[0]
	var original=Expedition.flow.run.build.duplicate(true);item.pickup();await settle()
	check(Expedition.art.ui.get_node("TouchRotateRight").visible,"on-screen rotation appears only while holding")
	var rotation=item.rotation
	await click(Expedition.art.ui.get_node("TouchRotateRight"));await settle()
	check(Game.draggedItem==item and not is_equal_approx(item.rotation,rotation),"mouse rotate button rotates held item without accidental drop")
	await click(Expedition.art.ui.get_node("TouchReturn"));await settle()
	check(not is_instance_valid(Game.draggedItem) and Expedition.flow.run.build==original,"return button restores held item and saved placement")
	var build=Expedition.flow.run.build.duplicate(true)
	for language in ["zh_CN","en"]:
		Expedition.preferences.values.language=language;Settings.setVal(Settings.Setting.language,"zh_Hans_CN" if language=="zh_CN" else "en")
		for scale in [1.0,1.4]:
			Expedition.preferences.values.ui_scale=scale;Expedition.ui_theme.default_font_size=roundi(24*scale)
			for page in ["settings","sound","guide","items","bags","recipes","enemies","rules","records","intel","enemy-build"]:
				if page=="settings":Expedition.show_settings()
				elif page=="sound":Expedition.menus.settings.show_page("sound")
				elif page=="guide":Expedition.show_ui_guide()
				elif page in ["intel","enemy-build"]:
					Expedition.menus.journey.section="build" if page=="enemy-build" else "abilities";Expedition.show_current_enemy()
				else:Expedition.menus.library.show_page(page)
				await settle();await inspect_page(page+language+str(scale));await snapshot(page+"-"+language+"-"+str(scale))
	check(build==Expedition.flow.run.build,"UI paging never edits inventory")
	Expedition.menus.library.show_page("items");await settle()
	await click(Expedition.panel.find_child("ListNext",true,false));await settle()
	check(Expedition.menus.library.page==1,"viewport mouse click advances item sheet")
	await click(Expedition.panel.find_child("ListPrevious",true,false));await settle()
	check(Expedition.menus.library.page==0,"viewport mouse click returns item sheet")
	for extent in [Vector2i(960,540),Vector2i(1280,1024),Vector2i(2400,1080)]:
		DisplayServer.window_set_size(extent);Expedition.show_ui_guide();await settle();await inspect_page("viewport "+str(extent));await snapshot("guide-"+str(extent.x)+"x"+str(extent.y))
	DisplayServer.window_set_size(Vector2i(1280,720));await settle()
	await Expedition.return_to_title();await settle()
	check(not Game.titleScreen.continueNode.is_visible_in_tree(),"saved run still has no standalone banner")
	var saved=Expedition.flow.saves.load_save("run").data
	Expedition.begin_setup(Game.Mode.Ranked);await settle();await inspect_page("resume choice");await snapshot("04-continue-choice")
	check(Expedition.panel.find_child("ResumeSavedRun",true,false)!=null,"standard entrance offers continue")
	check(Expedition.panel.find_child("NewGameChoice",true,false)!=null,"standard entrance offers new game")
	check(Expedition.flow.saves.load_save("run").data==saved,"opening entrance preserves previous run")
	Expedition.panel.find_child("ResumeSavedRun",true,false).pressed.emit();await settle()
	check(Expedition.flow.run.run_id==saved.run_id,"continue preserves run identity")
	await Expedition.return_to_title();await settle();Expedition.begin_setup(Game.Mode.Unranked);await settle()
	check(Expedition.panel.find_child("ResumeSavedRun",true,false)!=null,"tutorial entrance also offers saved run")
	var before_draft=Expedition.flow.saves.load_save("run").data
	Expedition.panel.find_child("NewGameChoice",true,false).pressed.emit();await settle()
	check(Expedition.panel.find_child("ArchiveConsent",true,false)==null,"new game needs no archive checkbox")
	check(Expedition.flow.saves.load_save("run").data==before_draft,"draft selection does not destroy progress")
	Expedition.panel.find_child("BeginExpedition",true,false).pressed.emit();await settle()
	check(Expedition.flow.run.run_id!=saved.run_id and Expedition.flow.screen_state=="ROUTE_SELECT","explicit new game replaces run and reaches routes")
	await inspect_page("new routes");await snapshot("05-new-routes")
	var file=FileAccess.open(output.path_join("touch-pages-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
