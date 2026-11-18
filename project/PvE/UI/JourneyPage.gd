extends RefCounted
const ROUTE = preload("res://PvE/UI/RouteScreenPresenter.gd")
var owner
var ui
var section="abilities"
func _init(host,shell):owner=host;ui=shell
func portrait_path(node:Dictionary)->String:
	if node.get("type","")=="merchant":return preload("res://PvE/Art/SuppliedArt.gd").ui_path("merchant")
	if node.get("type","")=="rest":return preload("res://PvE/Art/SuppliedArt.gd").ui_path("camp")
	var key=preload("res://PvE/Art/NewArtCatalog.gd").enemy_key(node)
	return preload("res://PvE/Art/SuppliedArt.gd").actor_path(key)
func portrait(node:Dictionary)->Texture2D:
	return load(portrait_path(node))
func choose_route():
	if not owner.flow.run.get("route_candidates", []).is_empty():
		if owner.native_routes != null:
			_open_editable_route()
		else:
			preload("res://PvE/UI/RouteLayout.gd").show_page(self)
		return
	ui.open("ROUTE_SELECT",ui.words("选择路线","Choose route"))
	var choices=ui.row()
	for index in owner.flow.run.route_candidates.size():
		var node=owner.flow.run.route_candidates[index];var column=ui.column(choices)
		var card=ui.card(column,owner.enemy_name(node) if node.type.ends_with("combat") or node.type=="boss" else owner.t(node.name_key),portrait(node),func():owner.perform(owner.flow.choose_route(index)),owner.t(node.name_key))
		card.set_meta("route_index",index);card.custom_minimum_size.y=265
		var badges=ui.row(column)
		for reward in owner.db.rows("reward_entries"):
			if reward.reward_table_id==str(node.get("reward_table_id","reward_none")) and int(reward.act_min)<=int(owner.flow.run.act) and int(reward.act_max)>=int(owner.flow.run.act):
				var badge=owner.label(reward_badge(reward),badges,24);badge.tooltip_text=owner.effect_text(reward.reward_type,reward.params)
		ui.action(column,ui.words("查看敌情","Intel"),func():section="abilities";show_page(node))
	var bosses=ui.row()
	for boss in owner.db.rows("bosses"):
		if boss.act_id=="act_"+str(owner.flow.run.act):
			ui.action(bosses,ui.words("本章首领","Act boss"),func():section="abilities";show_page({"type":"boss","boss_id":boss.id,"enemy_id":"","affix_id":""}))

func _open_editable_route() -> void:
	var root: Control = ui.open_canvas("ROUTE_SELECT",ui.words("征战旅途","Journey"))
	var ticket: int = owner.popup_epoch
	var mounted := await ROUTE.mount(self,owner.menus.new_journey_model(),root,ticket)
	if ticket != owner.popup_epoch or not is_instance_valid(root):
		return
	if mounted:
		owner.focus_popup()
		return
	# A failed current mount must not leave an empty modal or consume a route.
	owner.close_popup()
	owner.notice("native_asset_missing")
func show_page(node:Dictionary={},phase:int=1):
	if not owner.active:owner.show_codex();return
	var selected=node if not node.is_empty() else owner.flow.run.get("current_node",{})
	if selected.is_empty() and not owner.flow.run.get("route_candidates",[]).is_empty():selected=owner.flow.run.route_candidates[0]
	if not selected.is_empty() and (str(selected.get("type","")).ends_with("combat") or selected.get("type","") == "boss"):
		preload("res://PvE/UI/EnemyIntelLayout.gd").show_page(self,selected,phase)
		return
	ui.open("INTEL",ui.words("敌情与路线","Journey"))
	var controls=ui.row()
	var tabs=ui.row(controls);tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ui.segment(tabs,ui.words("能力","Abilities"),func():section="abilities";show_page(selected,phase),section=="abilities")
	ui.segment(tabs,ui.words("背包","Backpack"),func():section="build";show_page(selected,phase),section=="build")
	var track=ui.row(controls)
	for index in 5:
		var mark="✓" if index<owner.flow.run.completed_nodes.size()%5 else "●" if index==int(owner.flow.run.step)-1 else "○"
		var label=owner.label(mark+" "+str(index+1),track,24)
		label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.custom_minimum_size.x=74
		label.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	if section=="abilities":
		var content=VBoxContainer.new();owner.popup_content.add_child(content);inline_intel(selected,content,false)
	else:
		owner.label(owner.enemy_name(selected),null,27)
		var snapshot=owner.detail_views.enemy_snapshot(selected);var phases=ui.row()
		for entry in snapshot.get("boss_phases",[]):ui.segment(phases,str(entry.phase),func():show_page(selected,int(entry.phase)),int(entry.phase)==phase)
		owner.detail_views.grid(owner.enemy_build(selected,phase),owner.popup_content)
func ability_text(node:Dictionary)->String:
	var boss=str(node.get("boss_id",""))
	var data=owner.db.get_row("bosses",boss) if not boss.is_empty() else owner.db.get_row("enemy_builds",str(node.get("enemy_id","")))
	var lines:Array[String]=[]
	for pair in [["threat_tags","⚔"],["weakness_tags","◎"]]:
		var terms:Array[String]=[]
		for id in owner.db.list_values(data.get(pair[0],"")):terms.append(owner.detail_views.tag_name(id))
		if not terms.is_empty():lines.append(pair[1]+"  "+" / ".join(terms))
	for id in owner.db.list_values(node.get("affix_ids",node.get("affix_id",data.get("affix_id","")))):
		var affix=owner.db.get_row("encounter_affixes",id)
		if not affix.is_empty():lines.append(owner.detail_views.rules.affix(affix,TranslationServer.get_locale()))
	if not boss.is_empty():lines.append(owner.detail_views.rules.boss(boss,TranslationServer.get_locale(),str(owner.flow.run.get("difficulty_id","standard"))))
	return "\n\n".join(lines)
func inline_intel(node:Dictionary,parent:Node,compact:bool=true):
	ui.clear(parent)
	var row=ui.row(parent);ui.picture(row,portrait(node),Vector2(120,120))
	var detail=ui.column(row);owner.label(owner.enemy_name(node),detail,27)
	var snapshot=owner.detail_views.enemy_snapshot(node)
	if snapshot.get("ok",false):owner.label("♥ "+str(snapshot.base_stats.max_health)+"   ◆ "+str(snapshot.base_stats.stamina_max),detail,24)
	ui.text_pages(parent,ability_text(node),560 if compact else 1420,280 if compact else 330,22 if compact else 24)
func reward_badge(reward:Dictionary)->String:
	var kind=str(reward.reward_type);var params=owner.db.parse_params(reward.params);var number=str(params.get("amount",params.get("count",1)))
	if kind.contains("gold"):return "◉ +"+number
	if kind.contains("heal"):return "♥ +"+str(roundi(float(params.get("amount",0))*100))+"%"
	if kind.contains("refresh"):return "↻ ×"+number
	if kind.contains("recipe"):return "⚒ +1"
	if kind.contains("bag"):return "▣ ×1"
	if kind.contains("item"):return "◇ ×1"
	return "+"+number
