extends RefCounted
## Mouse/touch settings. Legacy shortcut data remains readable but has no UI.
var owner
var ui
var section="general"
func _init(host,shell):owner=host;ui=shell
func show_page(target:String="general"):
	section="general" if target=="inputs" else target
	ui.open("SETTINGS",ui.words("设置","Settings"))
	var tabs=ui.row()
	ui.segment(tabs,ui.words("画面与操作","Display & play"),func():show_page("general"),section=="general")
	ui.segment(tabs,ui.words("声音","Sound"),func():show_page("sound"),section=="sound")
	var columns=ui.row();var left=ui.column(columns,680);var right=ui.column(columns,680)
	if section=="sound":
		for index in 4:
			var names=[["music","BGM"],["ambient","PvEAmbient"],["ui","PvEUI"],["combat","PvECombat"]]
			var pair=names[index];var parent=left if index<2 else right
			owner.label(owner.t("native.volume_"+pair[0]),parent,25)
			var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1
			slider.value=float(owner.preferences.values[pair[0]])*100;slider.custom_minimum_size=Vector2(500,70);parent.add_child(slider)
			slider.set_meta("volume_key",pair[0])
			slider.value_changed.connect(func(value):owner.preferences.values[pair[0]]=value/100.0;AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[1]),linear_to_db(value/100.0));owner.preferences.save())
		return
	cycle(left,"language",ui.words("语言","Language"),["简体中文","English"],["zh_CN","en"],func():
		Settings.setVal(Settings.Setting.language,"zh_Hans_CN" if str(owner.preferences.values.language).begins_with("zh") else "en");show_page())
	cycle(left,"ui_scale",ui.words("字号","Text size"),["80%","100%","120%","140%"],[0.8,1.0,1.2,1.4],func():owner.ui_theme.default_font_size=roundi(24*owner.preferences.values.ui_scale);show_page())
	cycle(left,"window_mode",ui.words("显示","Display"),[ui.words("窗口","Window"),ui.words("无边框","Borderless"),ui.words("全屏","Full screen")],["windowed","borderless","fullscreen"],owner.preferences.apply_window)
	cycle(left,"resolution",ui.words("分辨率","Resolution"),["1280×720","1366×768","1600×900","1920×1080","1280×1024","2560×1080"],["1280x720","1366x768","1600x900","1920x1080","1280x1024","2560x1080"],owner.preferences.apply_window)
	for key in ["reduce_flash","reduce_motion","reduce_effects","high_contrast"]:
		var toggle=CheckBox.new();toggle.text=owner.t("native."+key);toggle.button_pressed=bool(owner.preferences.values[key]);toggle.custom_minimum_size=Vector2(620,78)
		toggle.set_meta("preference_key",key);toggle.add_theme_font_size_override("font_size",mini(28,roundi(22*owner.preferences.values.ui_scale)))
		right.add_child(toggle);toggle.toggled.connect(func(value):owner.preferences.values[key]=value;owner.preferences.save())
	ui.text_pages(owner.popup_content,ui.words("点按拿放道具；拿起后用屏幕上的左右箭头旋转，用红色叉号放回。点价格牌可以锁定或解锁货物。","Tap to pick and place. While holding an item, use the on-screen arrows to rotate or the red cross to return it. Tap a price tag to lock or unlock an offer."),1430,80,22)
func cycle(parent:Node,key:String,title:String,captions:Array,values:Array,callback:Callable):
	var row=ui.row(parent);var heading=owner.label(title,row,24);heading.custom_minimum_size.x=170
	var current=maxi(0,values.find(owner.preferences.values[key]))
	var button=ui.action(row,str(captions[current])+"  ›",func():pass)
	button.set_meta("setting_key",key);button.set_meta("setting_values",values)
	button.pressed.connect(func():
		var index=(values.find(owner.preferences.values[key])+1)%values.size()
		owner.preferences.values[key]=values[index];button.text=str(captions[index])+"  ›";owner.preferences.save();callback.call())
