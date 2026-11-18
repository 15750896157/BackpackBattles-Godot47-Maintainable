extends RefCounted
## Timeline facts drive both the visible counts and precise hover timing.
const CATALOG=preload("res://PvE/Art/SuppliedArt.gd")
const ICONS={"poison":"poison","burn":"burn","regeneration":"stamina_regen","lifesteal":"lifesteal","slow":"cooldown","vulnerable":"resistance","fortified":"armor","haste":"cooldown","thorns":"spikes","resistance":"resistance","armor":"armor"}
static func update(art,hud:Dictionary,actor):
	render(hud, actor.get_meta("pve_status_timeline", {}), int(actor.get_meta("pve_armor_timeline", 0)), art.text, {
		"is_negative": func(id): return Expedition.db.get_row("statuses", id).get("polarity", "") == "negative",
		"texture": func(key): return AssetStream.resources.get(CATALOG.status_path(key)),
		"name": func(id): return Expedition.t("status."+id+".name") if id != "armor" else art.local("护甲"),
	}, TranslationServer.get_locale().begins_with("zh"))

static func render(hud: Dictionary, statuses: Dictionary, armor: int, text: Callable, source: Dictionary, chinese: bool) -> void:
	var values := statuses.duplicate(true)
	if armor>0:values["armor"]={"stacks":armor,"cap":0,"remaining_duration":-1,"next_tick":0}
	var ids=values.keys();ids.sort()
	ids=ids.filter(func(id):return int(values[id].get("stacks",0))>0)
	var signature=str(ids)
	if signature!=hud.status_signature:
		for strip in [hud.status_icons,hud.get("debuff_icons")]:
			if not is_instance_valid(strip):continue
			for child in strip.get_children():strip.remove_child(child);child.queue_free()
		for id in ids:
			var negative: bool = source.is_negative.call(id)
			var strip=hud.get("debuff_icons",hud.status_icons) if negative else hud.status_icons
			var badge=Control.new();badge.name="Status_"+id;badge.set_meta("status_id",id);badge.custom_minimum_size=Vector2(39,29);strip.add_child(badge)
			var icon=TextureRect.new();icon.texture=source.texture.call(ICONS.get(id,"armor"));icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.size=Vector2(25,25);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_child(icon)
			icon.modulate=Color({"slow":"#9bcfff","regeneration":"#a5f6a0","vulnerable":"#ff9a9a","resistance":"#9cbfff","haste":"#ffe283"}.get(id,"#ffffff"))
			var amount: Label = text.call("", Rect2(17,7,23,22), badge, 16);amount.name="Amount"
			if id in ["slow","regeneration","vulnerable","resistance"]:
				text.call("↓" if id in ["slow","resistance"] else "↑", Rect2(1,0,14,17), badge, 13)
		hud.status_signature=signature
	for strip in [hud.status_icons,hud.get("debuff_icons")]:
		if not is_instance_valid(strip):continue
		for badge in strip.get_children():
			var id=str(badge.get_meta("status_id",""));var state:Dictionary=values.get(id,{})
			badge.get_node("Amount").text=str(int(state.get("stacks",0)))
			var name: String = source.name.call(id)
			var info=name+"  "+str(int(state.get("stacks",0)))
			if int(state.get("cap",0))>0:info+=" / "+str(int(state.cap))
			if float(state.get("next_tick",0))>0:info+=("\n下次结算：%.1f 秒" if chinese else "\nNext tick: %.1f s")%float(state.next_tick)
			if float(state.get("remaining_duration",-1))>=0:info+=("\n剩余：%.1f 秒" if chinese else "\nRemaining: %.1f s")%float(state.remaining_duration)
			badge.tooltip_text=info
	hud.statuses.text=""
