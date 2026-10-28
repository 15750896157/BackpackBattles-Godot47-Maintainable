extends RefCounted
static var skin: Texture2D
static func apply(subject):
	if not Expedition.enabled: return
	if skin == null and ResourceLoader.exists("res://Art/Polish20261022/tooltip.png"):
		var original: Texture2D = load("res://Art/Polish20261022/tooltip.png")
		var image = original.get_image()
		if image.is_compressed(): image.decompress()
		var used = image.get_used_rect(); image = image.get_region(used)
		image.resize(584,730,Image.INTERPOLATE_LANCZOS)
		skin = ImageTexture.create_from_image(image)
	if skin != null:
		subject.texture = skin
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: subject.set_patch_margin(side,30)
		subject.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	var definition = Expedition.flow.placement.definition(str(subject.item.get_meta("pve_definition_id","")))
	if not definition.is_empty(): subject.nameLabel.text = "[center]"+Expedition.t(str(definition.name_key))+"[/center]"
	subject.triggerColor_html = Color("78400c").to_html(false)
	for node in subject.find_children("*","Control",true,false):
		if node is Label:
			node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			node.add_theme_color_override("font_color",Color("382316"))
			node.add_theme_font_override("font",Expedition.ui_font)
		elif node is RichTextLabel:
			node.add_theme_color_override("default_color",Color("382316"))
			node.add_theme_font_override("normal_font",Expedition.ui_font)
			node.add_theme_font_override("bold_font",Expedition.ui_font)
			if node == subject.nameLabel: node.add_theme_font_size_override("normal_font_size",32)
		if node is Label or node is RichTextLabel:
			node.add_theme_constant_override("outline_size",0)
			node.add_theme_constant_override("shadow_offset_x",0); node.add_theme_constant_override("shadow_offset_y",0)
	for row in subject.propertyContainer.get_children():
		if not row.has_method("setTuple"): continue
		row.custom_minimum_size.y = 36
		row.add_theme_constant_override("separation",10)
		row.valueLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.perSecondLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.nameLabel.custom_minimum_size.x = maxf(110,row.nameLabel.custom_minimum_size.x)
		row.call_deferred("positionIcon")
	subject.rarityLabel.add_theme_color_override("font_color",Game.rarityColors[subject.item.getRarity()].darkened(0.60))
