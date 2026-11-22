extends "res://PvE/tests/ReferenceLayoutQA.gd"
var samples:Array=[]
func inspect_page(name:String):
	check(Expedition.panel.get_meta("menu_depth",0)==1,name+": one parent menu")
	check(Expedition.panel.find_children("*","OptionButton",true,false).is_empty(),name+": no nested selectors")
	check(Expedition.panel.find_children("*","LineEdit",true,false).is_empty(),name+": no keyboard required")
	var scope=Expedition.menus.shell.canvas if is_instance_valid(Expedition.menus.shell.canvas) else Expedition.panel
	var bounds=Rect2(0,0,1920,1082)
	for control in scope.find_children("*","BaseButton",true,false):
		if control.is_visible_in_tree():check(bounds.encloses(control.get_global_rect()),name+": visible target fits "+str(control.name))
	for label in scope.find_children("*","Label",true,false):
		if not label.is_visible_in_tree() or label.text.is_empty() or label.autowrap_mode!=TextServer.AUTOWRAP_OFF:continue
		var font=label.get_theme_font("font");var size=label.get_theme_font_size("font_size")
		for line in label.text.split("\n"):check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=label.size.x+2,name+": text width fits "+line)
		if label.has_meta("text_deck"):
			var restored="".join(label.get_meta("deck_pages"))
			check(restored.replace("\n","").replace(" ","")==str(label.get_meta("source_text")).replace("\n","").replace(" ",""),name+": complete paged rule text retained")
	# Every button caption spans the button and is centred. Cards that place an icon
	# plus inset text keep their own composition and are skipped here.
	for button in scope.find_children("*","BaseButton",true,false):
		if not button.is_visible_in_tree():continue
		if button is Button and not button is CheckBox and not button is CheckButton and not button.text.strip_edges().is_empty():
			check(button.alignment==HORIZONTAL_ALIGNMENT_CENTER,name+": button text centred "+str(button.name))
		var br=button.get_global_rect()
		for child in button.get_children():
			if not child is Label or not child.is_visible_in_tree() or child.text.strip_edges().is_empty():continue
			var lr=child.get_global_rect()
			if lr.position.x>br.position.x+2.0 or lr.size.x<br.size.x*0.9:continue
			check(child.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,name+": caption centred horizontally "+str(button.name))
			check(child.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,name+": caption centred vertically "+str(button.name))
			check(br.grow(4).encloses(lr),name+": caption stays inside "+str(button.name))
	var before=Expedition.popup_scroll.scroll_vertical
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=Vector2(700,500)
	get_viewport().push_input(wheel,true);await get_tree().process_frame
	check(Expedition.popup_scroll.scroll_vertical==before,name+": wheel does not move UI")
	samples.append({"page":name,"scope_resources":AssetStream.scopes.get("popup",{}).size()})
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	Expedition.create_run("armorer","warrior_blades","tutorial",1337,true);Expedition.flow.skip_tutorial();await settle();Expedition.flow.choose_route(0);await settle()
	var build=Expedition.flow.run.build.duplicate(true)
	# Discovered fixtures live only in the isolated test profile, never user data.
	for data in Expedition.db.rows("items")+Expedition.db.rows("bags"):Expedition.flow.profile_service.discover(data.id)
	for data in Expedition.db.rows("recipes"):Expedition.flow.profile_service.recipe(data.id)
	for data in Expedition.db.rows("enemy_builds")+Expedition.db.rows("bosses"):Expedition.flow.profile_service.profile.seen_enemies.append(data.id)
	for language in ["zh_CN","en"]:
		Expedition.preferences.values.language=language;Settings.setVal(Settings.Setting.language,"zh_Hans_CN" if language=="zh_CN" else "en")
		for scale in [1.0,1.4]:
			Expedition.preferences.values.ui_scale=scale;Expedition.ui_theme.default_font_size=roundi(24*scale)
			for page in ["settings","advanced","guide","items","bags","recipes","enemies","rules","records","intel","enemy-build"]:
				if page=="settings":Expedition.show_settings()
				elif page=="advanced":Expedition.menus.settings.show_page("advanced")
				elif page=="guide":Expedition.show_ui_guide()
				elif page in ["intel","enemy-build"]:Expedition.menus.journey.section="build" if page=="enemy-build" else "abilities";Expedition.show_current_enemy()
				else:Expedition.menus.library.show_page(page)
				await settle();await inspect_page(page+language+str(scale))
				if scale==1.0 and page in ["advanced","items","recipes","enemies","guide"]:await shot(page+"-"+language)
	for extent in [Vector2i(960,540),Vector2i(1280,1024),Vector2i(2560,1080)]:
		DisplayServer.window_set_size(extent)
		for page in ["settings","items","recipes","enemies"]:
			if page=="settings":Expedition.show_settings()
			else:Expedition.menus.library.show_page(page)
			await settle();await inspect_page(page+str(extent))
		await shot("book-"+str(extent.x)+"x"+str(extent.y))
	check(build==Expedition.flow.run.build,"every UI page preserves original inventory")
	DisplayServer.window_set_size(Vector2i(1280,720));Expedition.preferences.values.language="zh_CN";Settings.setVal(Settings.Setting.language,"zh_Hans_CN");Expedition.preferences.values.ui_scale=1.0
	await Expedition.return_to_title();await settle()
	Expedition.menus.runs.new_setup();await settle();Expedition.show_settings();await settle()
	await click(Expedition.panel.find_child("CloseMenu",true,false));await settle()
	check(Expedition.current_page=="SETUP" and Expedition.panel.find_child("BeginExpedition",true,false)!=null,"settings closes back to the same character draft")
	var file=FileAccess.open(output.path_join("reference-touch-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
