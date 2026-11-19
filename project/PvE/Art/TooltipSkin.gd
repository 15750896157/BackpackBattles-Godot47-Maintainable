extends RefCounted
const ART = "res://Art/Supplied20261109/"
const PROPERTY_ICON = {
	Item.Stat.MaxDamage: "attack", Item.Stat.StaminaCost: "stamina",
	Item.Stat.Cooldown: "cooldown_boost", Item.Stat.CritChance: "crit",
}
const EFFECT_ICON = {
	"heal": "heal", "gain_stamina": "regen_boost", "modify_crit_chance": "crit",
	"advance_cooldown": "cooldown_boost", "modify_cooldown_pct": "cooldown_boost",
}
static var skin: Texture2D
static var divider: Texture2D

static func apply(subject):
	if not Expedition.enabled: return
	if skin == null:
		skin = load(ART+"ui/tooltip_paper.png")
		divider = load(ART+"ui/tooltip_rule.png")
	if skin != null:
		subject.texture = skin
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: subject.set_patch_margin(side,30)
		subject.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	subject.divider1.texture = divider
	for node in subject.toReturn:
		if node is TextureRect and node.scene_file_path == "res://UI/Interface/Tooltips/TooltipDivider.tscn":
			node.texture = divider
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
	for stat in subject.properties:
		var row = subject.properties[stat]
		if PROPERTY_ICON.has(stat):
			row.iconSprite.texture = load(stat_path(PROPERTY_ICON[stat]))
		row.custom_minimum_size.y = 36
		row.add_theme_constant_override("separation",10)
		row.valueLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.perSecondLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.nameLabel.custom_minimum_size.x = maxf(110,row.nameLabel.custom_minimum_size.x)
		row.call_deferred("positionIcon")
	if not definition.is_empty() and subject.descrLabel.visible:
		var symbols: Array[String] = []
		for entry in Expedition.db.rows("item_effects"):
			if entry.item_id != definition.id: continue
			var icon := str(EFFECT_ICON.get(entry.effect_type,""))
			if entry.effect_type == "apply_status" and "lifesteal" in str(entry.effect_params):
				icon = "lifesteal"
			if not icon.is_empty() and not icon in symbols:
				symbols.append(icon)
		if not symbols.is_empty():
			var icons := "  ".join(symbols.map(func(icon): return Util.imageToBbcode(stat_path(icon),30)))
			if not subject.descrLabel.text.begins_with(icons):
				subject.descrLabel.text = icons + "\n" + subject.descrLabel.text
	subject.rarityLabel.add_theme_color_override("font_color",Game.rarityColors[subject.item.getRarity()].darkened(0.60))

static func stat_path(key: String) -> String:
	return ART+"status/"+key+".png"
