extends RefCounted
## Supplied journey PSD composition; all enemy and reward facts stay live.
const REF=preload("res://PvE/UI/ReferenceCanvas.gd")
const KEYS=["route_background","route_card","route_card_elite","route_motif","route_tab","route_tab_danger","route_tab_elite","route_threat","route_warning","route_go","settings","back","route_coin","camp_heart","route_header_chip","route_reward_slot","possible_rewards_zh","codex"]
static func show_page(page):
	var owner=page.owner;var ui=page.ui
	var root=ui.open_canvas("ROUTE_SELECT",ui.words("征战旅途","Journey"))
	var ticket=owner.popup_epoch
	var paths=REF.paths(KEYS)
	for node in owner.flow.run.route_candidates:paths.append(page.portrait_path(node))
	if not await AssetStream.prepare(paths,"popup") or ticket!=owner.popup_epoch:return
	if bool(owner.flow.run.get("route_pending",false)):
		var shade=ColorRect.new();shade.color=Color(0.02,0.015,0.025,0.68);shade.size=Vector2(1920,1080);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(shade)
	else:REF.picture(root,"route_background",Rect2(0,0,1920,1080),true)
	header(root,owner)
	var count=owner.flow.run.route_candidates.size()
	for index in count:
		var node:Dictionary=owner.flow.run.route_candidates[index]
		var left: float = 104.0+index*606.0 if count==3 else 310.0+index*780.0
		var frame := Rect2(left,217,521,658)
		var elite: bool = node.type == "elite_combat" or node.type == "boss"
		var art_frame: Rect2 = Rect2(left-38,178,598,736) if elite else frame
		REF.picture(root,"route_card_elite" if elite else "route_card",art_frame,true)
		if not elite: REF.picture(root,"route_motif",Rect2(left+36,221,427,423))
		var action=REF.zone(root,frame,func():owner.perform(owner.flow.choose_route(index)))
		action.name="RouteChoice_"+str(index);action.set_meta("route_index",index)
		var tab="route_tab_elite" if elite else "route_tab_danger" if node.type=="danger_combat" else "route_tab"
		REF.picture(root,tab,Rect2(left+120,158,254,104))
		REF.text(root,owner.t(node.name_key),Rect2(left+130,170,234,50),37)
		REF.text(root,owner.enemy_name(node) if node.type.ends_with("combat") or node.type=="boss" else ui.words("补给与抉择","Supplies & choices"),Rect2(left+125,222,244,33),22)
		var actor=TextureRect.new();actor.name="RoutePortrait_"+str(index);actor.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;actor.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;actor.texture=page.portrait(node);actor.position=Vector2(left+85,297);actor.size=Vector2(350,314);actor.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(actor)
		actor.modulate=preload("res://PvE/Art/NewArtCatalog.gd").enemy_variant(node).tint
		REF.picture(root,"route_threat",Rect2(left+108,639,291,40))
		var enemy=owner.db.get_row("enemy_builds",str(node.get("enemy_id","")))
		var tags=owner.db.list_values(enemy.get("threat_tags",""));var names:Array[String]=[]
		for tag in tags.slice(0,2):names.append(owner.detail_views.tag_name(tag))
		var threat=ui.words("主要威胁 · ","Threat · ")+" / ".join(names) if not names.is_empty() else ui.words("补给与休整","Supplies & recovery")
		REF.text(root,threat,Rect2(left+110,640,287,38),21)
		REF.button(root,"route_warning",Rect2(left+408,631,55,55),func():page.section="abilities";page.show_page(node)).tooltip_text=ui.words("查看完整敌情","Inspect enemy details")
		if TranslationServer.get_locale().begins_with("zh"):
			REF.picture(root,"possible_rewards_zh",Rect2(left-16,678,113,40))
		else:
			REF.text(root,"Possible rewards",Rect2(left-16,676,142,42),23,Color("f9e9c7"),2)
		var intentions=reward_intentions(owner,node)
		for slot in 4:
			REF.picture(root,"route_reward_slot",Rect2(left+24+slot*121,724,100,100))
			if slot < intentions.size(): REF.text(root,intentions[slot],Rect2(left+24+slot*121,755,100,36),22)
		REF.button(root,"route_go",Rect2(left+144,834,230,70),func():owner.perform(owner.flow.choose_route(index)),ui.words("准备出发","Prepare"),32).name="RouteGo_"+str(index)
	REF.fade_in(root)
static func reward_intentions(owner,node:Dictionary)->Array:
	var words:Callable=owner.bilingual
	if node.type=="rest":return [words.call("恢复","Heal"),words.call("整备","Refit")]
	if node.type=="merchant":return [words.call("商店","Shop")]
	if node.type=="event":return [words.call("事件抉择","Event choice")]
	var labels:Array=[]
	var names={"item_pool":words.call("装备","Gear"),"bag_pool":words.call("背包","Bag"),"gold":words.call("金币","Gold"),"heal_pct":words.call("恢复","Heal"),"free_refresh":words.call("刷新","Refresh"),"recipe_discovery":words.call("配方","Recipe"),"upgrade_item":words.call("升级","Upgrade")}
	if node.type=="elite_combat":labels.append(words.call("罪徽","Crest"))
	for reward in owner.db.rows("reward_entries"):
		if reward.reward_table_id!=str(node.get("reward_table_id","reward_none")) or int(reward.act_min)>int(owner.flow.run.act) or int(reward.act_max)<int(owner.flow.run.act):continue
		var title=str(names.get(reward.reward_type,words.call("奖励","Reward")))
		if title not in labels:labels.append(title)
	return labels.slice(0,4)
static func header(root:Control,owner,back_key: String = "back",with_codex: bool = true):
	REF.picture(root,"route_header_chip",Rect2(89,43,126,39),true)
	REF.picture(root,"route_header_chip",Rect2(230,43,148,39),true)
	REF.picture(root,"route_coin",Rect2(75,42,39,39));REF.text(root,str(int(owner.flow.run.gold)),Rect2(120,43,95,39),26,Color("fff0cd"),2)
	REF.picture(root,"camp_heart",Rect2(219,43,45,36));REF.text(root,"%d/%d"%[int(owner.flow.run.health),int(owner.flow.run.max_health)],Rect2(268,43,110,39),26,Color("fff0cd"),2)
	REF.text(root,owner.bilingual("第 %d 章 · 第 %d 站","Act %d · Node %d")%[int(owner.flow.run.act),int(owner.flow.run.step)],Rect2(395,43,300,39),25,Color("ffe0af"),2)
	if bool(owner.flow.run.get("route_pending",false)):
		REF.button(root,back_key,Rect2(52,938,117,86),owner.close_popup).name="RouteCancel"
		REF.text(root,owner.bilingual("可先整理商店 · 开战前须选定路线","Shop first · Choose a route before battle"),Rect2(450,954,980,45),28,Color("ffe7bf"),2)
	else:REF.button(root,back_key,Rect2(52,938,117,86),owner.return_to_title).name="JourneyReturn"
	REF.button(root,"settings",Rect2(1822,14,59,59),owner.show_settings).name="JourneySettings"
	if with_codex:REF.button(root,"codex",Rect2(1550,930,216,106),owner.show_codex).name="JourneyCodex"
