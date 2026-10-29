extends RefCounted
## Normalize art to UI pixel density before nine-slicing. Caps never stretch.
const ROOT = "res://Art/Touch20261027/"
static func normalized(key: String, region: Rect2i, size: Vector2i) -> Texture2D:
	var original: Texture2D = load(ROOT+key+".png")
	var image = original.get_image()
	if image.is_compressed(): image.decompress()
	image = image.get_region(region)
	image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	var result = ImageTexture.create_from_image(image)
	result.set_meta("source_art",ROOT+key+".png")
	return result

static func apply(theme: Theme):
	var panel = StyleBoxTexture.new()
	panel.texture=load(ROOT+"window.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		panel.set_texture_margin(side,70)
		panel.set_content_margin(side,60)
	theme.set_stylebox("panel","PanelContainer",panel)
	var wood=load("res://Art/Supplied20261028/ui/button.png")
	for state in ["normal","hover","pressed","disabled"]:
		var style = StyleBoxTexture.new(); style.texture = wood
		for side in [SIDE_LEFT,SIDE_RIGHT]:
			style.set_texture_margin(side,48); style.set_content_margin(side,30)
		for side in [SIDE_TOP,SIDE_BOTTOM]:
			style.set_texture_margin(side,16); style.set_content_margin(side,16)
		style.modulate_color = Color(1.1,1.06,1.0) if state == "hover" else Color(0.72,0.69,0.63) if state == "disabled" else Color(0.86,0.80,0.72) if state == "pressed" else Color.WHITE
		for type in ["Button","OptionButton"]: theme.set_stylebox(state,type,style)
	# Toggle rows sit on paper, so do not inherit Button's dark wood background.
	var toggle = StyleBoxEmpty.new()
	toggle.set_content_margin_all(12)
	for type in ["CheckBox","CheckButton"]:
		for state in ["normal","hover","pressed","hover_pressed","disabled"]: theme.set_stylebox(state,type,toggle)
	var focus = StyleBoxFlat.new(); focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("6c420e"); focus.set_border_width_all(2)
	for type in ["Button","OptionButton","CheckBox"]: theme.set_stylebox("focus",type,focus)
	for type in ["Label","RichTextLabel","CheckBox","CheckButton","LineEdit","PopupMenu"]:
		theme.set_color("font_color",type,Color("302114"))
		theme.set_color("font_hover_color",type,Color("302114"))
		theme.set_color("font_focus_color",type,Color("302114"))
		theme.set_color("font_pressed_color",type,Color("302114"))
		theme.set_color("font_hover_pressed_color",type,Color("302114"))
	theme.set_color("default_color","RichTextLabel",Color("302114"))
	theme.set_color("font_placeholder_color","LineEdit",Color("715139"))
	theme.set_color("selection_color","LineEdit",Color("725032"))
	theme.set_color("font_selected_color","LineEdit",Color("fff4d7"))
	for type in ["Button","OptionButton"]:
		for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: theme.set_color(state,type,Color("302114"))
		theme.set_color("font_disabled_color",type,Color("574532"))
		theme.set_color("font_outline_color",type,Color("fff1c0")); theme.set_constant("outline_size",type,1)
	var input = StyleBoxFlat.new(); input.bg_color = Color("f5deb7"); input.border_color = Color("8c623c"); input.set_border_width_all(2)
	input.content_margin_left = 18; input.content_margin_right = 18; input.content_margin_top = 10; input.content_margin_bottom = 10
	theme.set_stylebox("normal","LineEdit",input); theme.set_stylebox("focus","LineEdit",input)
	var menu = panel.duplicate(); menu.set_content_margin_all(28)
	theme.set_stylebox("panel","PopupMenu",menu)
