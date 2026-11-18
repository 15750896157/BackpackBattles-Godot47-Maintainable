extends RefCounted
## Two flat sheets; the first uses the supplied 1768 x 992 reference coordinates.
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const KEYS = ["window","settings_plate","close","check","checkbox","highlight","slider_fill","slider_base","slider_knob","ornament","button","button_blue"]
var owner
var ui
var section = "general"
var return_to_selection = false
const PREFERENCES_VM = preload("res://Runtime/ViewModel/PreferencesVM.gd")
var model: PREFERENCES_VM

func _init(host, shell):
	owner = host
	ui = shell
	model = PREFERENCES_VM.new(host.preferences)
func show_page(target: String = "general"):
	if owner.current_page != "SETTINGS": return_to_selection = owner.current_page == "SETUP"
	section = "general" if target in ["general","sound","inputs"] else "advanced"
	var root = ui.open_canvas("SETTINGS",ui.words("游戏设置","Game settings"))
	var ticket = owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(KEYS),"popup") or ticket != owner.popup_epoch: return
	# The reference dims the town behind the paper, without layering menu buttons over it.
	owner.modal_shield.color = Color(0.0, 0.0, 0.0, 153.0 / 255.0)
	var content = Control.new(); content.name = "SettingsReference1768"
	content.scale = Vector2(1920.0/1768.0,1080.0/992.0); content.size = Vector2(1768,992)
	root.add_child(content)
	REF.picture(content,"window",Rect2(277,170,1205,692),true)
	REF.picture(content,"ornament",Rect2(508,275,176,35))
	REF.picture(content,"ornament",Rect2(1053,275,176,35)).flip_h = true
	REF.text(content,ui.words("游戏设置","Game settings"),Rect2(710,240,320,90),64)
	REF.button(content,"close",Rect2(1406,128,101,106),close_page).name = "CloseMenu"
	owner.back_action = close_page
	if section == "general": main_sheet(content)
	else: advanced_sheet(content)
	REF.button(content,"button_blue",Rect2(1170,752,240,55),func():show_page("advanced" if section == "general" else "general"),ui.words("更多设置" if section == "general" else "基本设置","More settings" if section == "general" else "Basic settings"),25).name = "SettingsNextSheet"
	REF.button(content,"button",Rect2(365,752,220,55),owner.show_ui_guide,ui.words("界面教程","UI guide"),25).name = "SettingsGuide"
	if owner.active:
		var save = REF.button(content,"button",Rect2(650,752,380,55),owner.return_to_title,ui.words("保存并返回主页","Save and return"),25)
		save.name = "SaveAndExit";save.set_meta("action_caption",owner.t("ui.save_menu"))
	elif return_to_selection and section == "advanced":
		REF.button(content,"button",Rect2(650,752,380,55),func():owner.menus.runs.seed_value=Time.get_ticks_usec()&0xffffffff,ui.words("换一张地图","Shuffle map"),25).name="ShuffleSeed"
func close_page():
	if return_to_selection:owner.menus.runs.new_setup()
	else:owner.view_return()
func main_sheet(root: Control):
	REF.picture(root,"settings_plate",Rect2(340,406,512,262),true)
	REF.picture(root,"settings_plate",Rect2(885,406,512,262),true)
	REF.text(root,ui.words("画面","Display"),Rect2(526,433,145,62),42)
	REF.text(root,ui.words("声音","Sound"),Rect2(1062,433,145,62),42)
	for index in 2:
		var full = index == 0
		var selected = model.snapshot().window_mode == ("fullscreen" if full else "windowed")
		var y = 508 + index*56
		if selected: REF.picture(root,"highlight",Rect2(412,y-2,359,42),true)
		REF.text(root,ui.words("全屏模式" if full else "窗口模式","Full screen" if full else "Windowed"),Rect2(422,y-3,236,45),31).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		REF.picture(root,"checkbox",Rect2(731,y+1,35,35))
		if selected: REF.picture(root,"check",Rect2(731,y-3,41,39))
		var action = REF.zone(root,Rect2(413,y-7,360,54),func():
			if not root.is_inside_tree(): return
			model.set_option("window_mode", "fullscreen" if full else "windowed")
			show_page())
		action.name = "Fullscreen" if full else "Windowed"
	slider(root,"music",ui.words("音乐音量","Music"),Rect2(1062,512,277,34),Vector2(927,500))
	slider(root,"ui",ui.words("音效音量","Effects"),Rect2(1062,568,277,34),Vector2(927,556))
func slider(root: Control,key: String,title: String,rect: Rect2,heading: Vector2):
	REF.text(root,title,Rect2(heading,Vector2(126,52)),30)
	var control = HSlider.new(); control.name = "Volume_"+key
	control.position = rect.position-Vector2(0,14); control.size = rect.size+Vector2(0,28)
	control.min_value = 0; control.max_value = 100; control.step = 1
	control.value = float(model.snapshot()[key])*100; control.set_meta("volume_key",key)
	for pair in [["slider","slider_base"],["grabber_area","slider_fill"],["grabber_area_highlight","slider_fill"]]:
		var style = StyleBoxTexture.new(); style.texture = REF.texture(pair[1])
		style.texture_margin_left = 16; style.texture_margin_right = 16
		style.texture_margin_top = 16; style.texture_margin_bottom = 16
		style.content_margin_top = 16; style.content_margin_bottom = 16
		control.add_theme_stylebox_override(pair[0],style)
	for state in ["grabber","grabber_highlight","grabber_disabled"]: control.add_theme_icon_override(state,REF.texture("slider_knob"))
	root.add_child(control)
	control.value_changed.connect(func(value):
		if control.is_inside_tree():
			model.set_volume(key, value / 100.0))
func advanced_sheet(root: Control):
	var left = VBoxContainer.new();left.position = Vector2(370,400);left.size = Vector2(490,320);root.add_child(left)
	var right = VBoxContainer.new();right.position = Vector2(920,400);right.size = Vector2(480,320);root.add_child(right)
	var refresh := func(): show_page("advanced")
	cycle(left, "language", ui.words("语言", "Language"), ["简体中文", "English"], ["zh_CN", "en"], refresh)
	cycle(left, "ui_scale", ui.words("字号", "Text size"), ["80%", "100%", "120%", "140%"], [0.8, 1.0, 1.2, 1.4], refresh)
	cycle(left, "window_mode", ui.words("显示", "Display"), [ui.words("窗口","Window"),ui.words("无边框","Borderless"),ui.words("全屏","Full screen")], ["windowed","borderless","fullscreen"])
	cycle(left, "resolution", ui.words("分辨率", "Resolution"), ["1280×720","1366×768","1600×900","1920×1080","1280×1024","2560×1080"], ["1280x720","1366x768","1600x900","1920x1080","1280x1024","2560x1080"])
	for key in ["reduce_flash","reduce_motion","reduce_effects","high_contrast"]:
		var toggle = CheckBox.new();toggle.text = owner.t("native."+key);toggle.button_pressed = bool(model.snapshot()[key]);toggle.custom_minimum_size = Vector2(460,65)
		toggle.set_meta("preference_key",key);toggle.add_theme_font_size_override("font_size",24)
		right.add_child(toggle)
		toggle.toggled.connect(func(value):
			if toggle.is_inside_tree():
				model.set_option(key, value))
	slider(root,"ambient",ui.words("环境音量","Ambient"),Rect2(510,680,277,34),Vector2(370,669))
	slider(root,"combat",ui.words("战斗音量","Combat"),Rect2(1070,680,277,34),Vector2(930,669))
func cycle(parent: Node,key: String,title: String,captions: Array,values: Array,callback: Callable = Callable()):
	var row = ui.row(parent);row.add_theme_constant_override("separation",8)
	var heading=owner.label(title,row,23);heading.custom_minimum_size.x=170;heading.add_theme_font_size_override("font_size",24)
	var current = maxi(0,values.find(model.snapshot()[key]))
	var button = ui.action(row,str(captions[current])+"  ›",func():pass)
	button.custom_minimum_size = Vector2(280,60); button.set_meta("setting_key",key);button.set_meta("setting_values",values)
	button.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed","disabled"]:
		var style=button.get_theme_stylebox(state).duplicate();style.content_margin_top=8;style.content_margin_bottom=8;button.add_theme_stylebox_override(state,style)
	button.pressed.connect(func():
		if not button.is_inside_tree(): return
		var index = (values.find(model.snapshot()[key]) + 1) % values.size()
		model.set_option(key, values[index])
		button.text = str(captions[index]) + "  ›"
		if callback.is_valid(): callback.call())
