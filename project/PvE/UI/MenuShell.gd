extends RefCounted
## One persistent panel. Sections replace its body; there is no menu stack.
const ART = "res://Art/Mobile20261027/"
const TOUCH_ART = "res://Art/Touch20261027/"
var owner
var textures: Dictionary = {}
var pager
func _init(host): owner = host
func words(zh: String, en: String) -> String: return owner.bilingual(zh,en)
func image(key: String) -> Texture2D:
	if not textures.has(key): textures[key] = load((TOUCH_ART if key in ["window","button","card","close","previous","next","continue","new_run"] else ART)+key+".png")
	return textures[key]
func open(page: String, title: String):
	owner.clear_popup(title)
	owner.current_page = page
	owner.back_action = owner.view_return
	owner.panel.set_meta("menu_depth",1)
	owner.panel.set_meta("mobile_ui",true)
func chrome(title: String):
	if pager!=null:pager.reset()
	for parent in [owner.menu_header,owner.menu_nav]: clear(parent)
	var heading = owner.label(title,owner.menu_header,32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close = symbol(owner.menu_header,"close",words("关闭","Close"),owner.view_return,Vector2(80,72));close.name="CloseMenu"
	for entry in [["codex",words("图鉴","Collection"),owner.show_codex],["journey",words("敌情","Journey"),owner.show_current_enemy],["settings",words("设置","Settings"),owner.show_settings],["guide",words("教程","Guide"),owner.show_ui_guide]]:
		icon_button(owner.menu_nav,entry[0],entry[1],entry[2],Vector2(116,92))
	if owner.active: icon_button(owner.menu_nav,"home",owner.t("ui.save_menu"),owner.return_to_title,Vector2(130,92)).name = "SaveAndExit"
func clear(parent: Node):
	for child in parent.get_children(): parent.remove_child(child);child.queue_free()
func row(parent: Node = null) -> HBoxContainer:
	var box = HBoxContainer.new();box.add_theme_constant_override("separation",20)
	box.alignment=BoxContainer.ALIGNMENT_CENTER
	(parent if parent != null else owner.popup_content).add_child(box)
	return box
func column(parent: Node, width: float = 0) -> VBoxContainer:
	var box = VBoxContainer.new();box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = width;box.add_theme_constant_override("separation",14);parent.add_child(box)
	return box
func grid(parent: Node, columns: int = 4) -> GridContainer:
	var box = GridContainer.new();box.columns = columns
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("h_separation",14);box.add_theme_constant_override("v_separation",14)
	parent.add_child(box);return box
func action(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var node = owner.button(text,callback,parent,disabled)
	node.custom_minimum_size = Vector2(240,80)
	node.autowrap_mode=TextServer.AUTOWRAP_OFF
	node.set_meta("word_action",true)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return node
func icon_button(parent: Node, key: String, caption: String, callback: Callable, extent: Vector2 = Vector2(150,140)) -> Button:
	var button = Button.new();button.custom_minimum_size = extent
	button.focus_mode = Control.FOCUS_ALL;button.tooltip_text = caption
	button.set_meta("icon_key",key);button.set_meta("action_caption",caption)
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(button)
	var picture = TextureRect.new();picture.texture = image(key)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);picture.offset_bottom = -34
	button.add_child(picture)
	var label = owner.label(caption,button,22);label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text=str({"codex":words("图鉴","Codex"),"journey":words("敌情","Intel"),"home":words("保存","Save")}.get(key,caption))
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size",mini(26,roundi(22*owner.preferences.values.ui_scale)))
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);label.offset_top = -34
	button.pressed.connect(callback)
	button.button_down.connect(func(): picture.modulate = Color(0.78,0.78,0.78))
	button.button_up.connect(func(): picture.modulate = Color.WHITE)
	return button
func segment(parent: Node,caption: String,callback: Callable,selected: bool = false) -> Button:
	var button=action(parent,caption,callback,selected)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size=Vector2(155,70);button.autowrap_mode=TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size",mini(26,roundi(23*owner.preferences.values.ui_scale)))
	for state in ["normal","hover","pressed","disabled"]:
		var skin=owner.ui_theme.get_stylebox("normal","Button").duplicate()
		skin.modulate_color=Color(1.14,1.14,1.04) if selected else Color(0.75,0.86,0.8)
		button.add_theme_stylebox_override(state,skin)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:button.add_theme_color_override(state,Color("fff3d9"))
	return button
func picture(parent: Node, texture: Texture2D, extent: Vector2 = Vector2(110,110)) -> TextureRect:
	var icon = TextureRect.new();icon.texture = texture;icon.custom_minimum_size = extent
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE;parent.add_child(icon);return icon
func card(parent: Node, title: String, texture: Texture2D, callback: Callable, hint: String = "", disabled: bool = false) -> Button:
	var node = Button.new();node.custom_minimum_size = Vector2(210,230)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL;node.disabled = disabled
	node.tooltip_text = title;node.set_meta("action_caption",title)
	for state in ["normal","hover","pressed","disabled"]:
		var skin = StyleBoxTexture.new();skin.texture=image("card")
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:skin.set_texture_margin(side,32);skin.set_content_margin(side,14)
		skin.modulate_color=Color.WHITE if state=="normal" else Color(1.08,1.08,1.02) if state=="hover" else Color(0.88,0.92,0.85)
		node.add_theme_stylebox_override(state,skin)
	parent.add_child(node)
	var content = VBoxContainer.new();content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=12;content.offset_right=-12;content.offset_top=10;content.offset_bottom=-10
	node.add_child(content)
	picture(content,texture,Vector2(100,80))
	var label = owner.label(title,content,24);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",mini(28,roundi(22*owner.preferences.values.ui_scale)))
	label.max_lines_visible=2;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if not hint.is_empty():
		var detail=owner.label(hint,content,20);detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.pressed.connect(callback);return node

func symbol(parent:Node,key:String,caption:String,callback:Callable,extent:Vector2=Vector2(76,68))->Button:
	var node=Button.new();node.custom_minimum_size=extent;node.tooltip_text=caption;node.set_meta("icon_key",key);node.set_meta("action_caption",caption)
	for state in ["normal","hover","pressed","disabled","focus"]:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(node);var visual=picture(node,image(key),Vector2.ZERO)
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.pressed.connect(callback);node.button_down.connect(func():visual.modulate=Color(0.75,0.82,0.77));node.button_up.connect(func():visual.modulate=Color.WHITE)
	return node
func text_pages(parent:Node,text:String,width:float=520,height:float=300,size:int=23):
	return preload("res://PvE/UI/TextDeck.gd").new(self,parent,text,width,height,size)
