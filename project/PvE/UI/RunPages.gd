extends RefCounted
## Saved runs resume from their mode entrance. Only Begin replaces progress.
var owner
var ui
var role="armorer"
var loadout="armorer_blades"
var difficulty="tutorial"
var seed_value=0
var selected_recipe:Dictionary={}
func _init(host,shell): owner=host;ui=shell
func setup(mode: int = -1):
	if seed_value==0: seed_value=Time.get_ticks_usec()&0xffffffff
	if mode>=0:difficulty="tutorial" if mode==Game.Mode.Unranked else "standard"
	if mode>=0:
		var saved=owner.flow.saves.load_save("run")
		var valid=saved.ok and owner.flow.saves.validate_run(saved.get("data",{}),owner.db).ok and saved.data.get("last_safe_state",saved.data.get("state",""))!="RUN_RESULT"
		if valid:
			entry_choice(saved.data)
			return
	new_setup()
func entry_choice(saved:Dictionary):
	ui.open("SETUP",ui.words("教学战斗","Tutorial") if difficulty=="tutorial" else ui.words("标准战斗","Standard battle"))
	var heading=ui.row();ui.picture(heading,ui.image("continue"),Vector2(150,150))
	var summary=ui.column(heading)
	owner.label(owner.t("difficulty."+str(saved.difficulty_id)+".name"),summary,28)
	owner.label(ui.words("第 %d 章 · 第 %d 站","Act %d · Node %d")%[int(saved.act),int(saved.step)]+"   ♥ "+str(int(saved.health)),summary,26)
	var actions=ui.row()
	var resume=ui.card(actions,ui.words("继续游戏","Continue game"),ui.image("continue"),owner.continue_run)
	resume.name="ResumeSavedRun";resume.custom_minimum_size=Vector2(500,280)
	resume.get_child(0).get_child(0).custom_minimum_size.y=150
	var fresh=ui.card(actions,ui.words("新游戏","New game"),ui.image("new_run"),new_setup)
	fresh.name="NewGameChoice";fresh.custom_minimum_size=Vector2(500,280)
	fresh.get_child(0).get_child(0).custom_minimum_size.y=150
	owner.label(ui.words("新游戏出发后替换上局进度","Starting a new expedition replaces the previous run."),null,22)
func new_setup():
	ui.open("SETUP",ui.words("出发","New expedition"))
	var roles=ui.row()
	for id in ["armorer","alchemist"]:
		var data=owner.db.get_row("characters",id)
		var button=ui.card(roles,owner.t(data.name_key),load("res://Art/20261022/hero.png"),func():role=id;loadout="";setup(),"♥ "+str(data.max_health))
		button.modulate=Color.WHITE if role==id else Color(0.76,0.76,0.76)
	var choices=ui.row()
	for data in owner.db.rows("character_loadouts"):
		if data.character_id!=role:continue
		if loadout.is_empty() or not loadout.begins_with(role):loadout=data.id
		ui.action(choices,owner.t(data.name_key),func():loadout=data.id;setup(),loadout==data.id)
	var levels=ui.row()
	for data in owner.db.rows("difficulty_levels"):
		if data.id in owner.flow.profile_service.profile.unlocks:
			ui.segment(levels,owner.t(data.name_key),func():difficulty=data.id;setup(),difficulty==data.id)
	var bottom=ui.row()
	ui.action(bottom,ui.words("换一张地图","Shuffle map"),func():seed_value=Time.get_ticks_usec()&0xffffffff;new_setup()).name="ShuffleSeed"
	var begin=ui.action(bottom,owner.t("ui.begin_expedition"),func():
		if seed_value<0 or seed_value>4294967295:owner.notice("ui.invalid_seed");return
		owner.perform(owner.flow.new_run(role,loadout,difficulty,seed_value,true)))
	begin.name="BeginExpedition"
func confirm_new(new_role: String,new_loadout: String,new_difficulty: String,new_seed: int):
	role=new_role;loadout=new_loadout;seed_value=new_seed
	difficulty=new_difficulty
	var saved=owner.flow.saves.load_save("run")
	if saved.ok:entry_choice(saved.data)
	else:new_setup()
func result():
	var data=owner.flow.combat_result
	ui.open("COMBAT_RESULT",owner.t("ui.victory" if int(data.get("winner_side",data.get("winner",1)))==0 else "ui.defeat"))
	var top=ui.row();ui.picture(top,ui.image("battle"),Vector2(280,155))
	var info=ui.column(top)
	owner.label(owner.enemy_name(owner.flow.run.current_node),info,30)
	owner.label("♥ "+str(int(owner.flow.run.health))+"   ⏱ "+str(snappedf(float(data.elapsed_time),0.1))+"s",info,28)
	ui.action(info,owner.t("ui.next"),owner.advance_result).name="ResultNext"
	var stats=ui.column(owner.popup_content)
	for side in 2:
		var entries=data.get("item_stats_by_instance_id",{}).values().filter(func(row):return int(row.get("side",-1))==side)
		entries.sort_custom(func(a,b):return float(a.get("damage",0))>float(b.get("damage",0)))
		var row=ui.row(stats)
		owner.label(owner.t("native.player_side" if side==0 else "native.enemy_side"),row,24)
		for index in mini(3,entries.size()):
			owner.label(owner.source_name(entries[index])+"  ⚔ "+str(snappedf(float(entries[index].get("damage",0)),0.1)),row,22)
func rewards():
	ui.open("REWARD_SELECT",ui.words("战利品","Rewards"))
	if bool(owner.flow.run.reward_selected):
		pending_controls();ui.action(owner.popup_content,owner.t("ui.continue_route"),func():owner.perform(owner.flow.complete_node()),not owner.flow.run.pending_rewards.is_empty());return
	var grid=ui.grid(owner.popup_content,3)
	for index in owner.flow.run.reward_choices.size():
		var reward=owner.flow.run.reward_choices[index]
		var id=str(reward.get("definition_id",""))
		var title=owner.t(owner.flow.placement.definition(id).name_key) if not id.is_empty() else owner.effect_text(reward.type,reward.params)
		var card=ui.card(grid,title,ui.image("codex"),func():owner.perform(owner.flow.choose_reward(index)))
		if not id.is_empty():owner.detail_views.fill_icon(weakref(card.get_child(0).get_child(0)),id,owner.popup_epoch)
	var consent=CheckBox.new();consent.text=ui.words("放弃本次奖励","Skip this reward");consent.custom_minimum_size.y=72;owner.popup_content.add_child(consent)
	ui.action(owner.popup_content,owner.t("ui.skip_reward"),func():
		if consent.button_pressed:owner.perform(owner.flow.skip_reward(true)))
func pending_controls():
	for index in owner.flow.run.pending_rewards.size():
		var pending=owner.flow.run.pending_rewards[index]
		var row=ui.row();var icon=ui.picture(row,null,Vector2(100,100));owner.detail_views.fill_icon(weakref(icon),pending.definition_id,owner.popup_epoch)
		owner.label(owner.t(owner.flow.placement.definition(pending.definition_id).name_key),row,24)
		for action in ["place","storage","sell","discard"]:
			ui.action(row,owner.t("ui."+action),func():owner.perform(owner.flow.handle_pending(index,action)),action=="storage" and owner.flow.run.build.storage.size()>=int(owner.flow.run.build.storage_capacity))
func pending():ui.open("PENDING",ui.words("收纳战利品","Store rewards"));pending_controls()
func event():
	var rest=owner.flow.screen_state=="REST"
	if rest:Sound.playBGM(Sound.postFightBGM_survival,-8)
	var event=owner.db.get_row("events",str(owner.flow.run.current_node.get("event_id","")))
	ui.open(owner.flow.screen_state,owner.t("ui.rest") if rest else owner.t(event.title_key))
	if not rest:owner.label(owner.t(event.description_key),null,24)
	var grid=ui.grid(owner.popup_content,2)
	for choice in owner.db.rows("rest_actions" if rest else "event_choices"):
		if not rest and choice.event_id!=event.id:continue
		var column=ui.column(grid,580)
		owner.label(owner.t(str(choice.get("name_key" if rest else "text_key",""))),column,27)
		var options:Array=[{}];var names:Array=[]
		for effect in owner.db.rows("rest_action_effects" if rest else "event_choice_effects"):
			if str(effect.get("rest_action_id" if rest else "choice_id",""))!=choice.id:continue
			owner.label(owner.effect_text(effect.effect_type,effect.params),column,22)
			if effect.effect_type=="remove_item":
				options=[]
				for entry in owner.flow.effects.eligible_items(owner.flow.run,str(owner.db.parse_params(effect.params).get("selector","player_choice"))):
					options.append({"item_uid":entry.uid});names.append(owner.t(owner.flow.placement.definition(entry.definition_id).name_key))
			elif effect.effect_type in ["upgrade_item","recipe_upgrade"]:
				options=[]
				for candidate in owner.flow.crafting.upgrade_candidates(owner.flow.run.build,int(owner.flow.run.act)):
					options.append({"item_uid":candidate.source_uid,"recipe_id":candidate.recipe_id});names.append(owner.t(owner.flow.placement.definition(candidate.result_item_id).name_key))
			elif effect.effect_type=="execute_recipe":
				options=[]
				for candidate in owner.flow.crafting.candidates(owner.flow.run.build,int(owner.flow.run.act)):
					var recipe=owner.db.get_row("recipes",candidate.recipe_id)
					if int(recipe.tier)>int(owner.db.parse_params(effect.params).get("tier_max",2)):continue
					options.append({"recipe_id":recipe.id,"material_uids":candidate.material_uids});names.append(owner.t(owner.flow.placement.definition(recipe.result_item_id).name_key))
		var selected={"index":0}
		if not names.is_empty():
			var select=ui.action(column,names[0],func():pass)
			select.pressed.connect(func():selected.index=(int(selected.index)+1)%names.size();select.text=names[selected.index])
		var legal=owner.flow.effects.requirements(owner.flow.run,str(choice.requirements))
		ui.action(column,owner.t("ui.confirm"),func():owner.perform(owner.flow.event_choice(choice.id,options[selected.index])),not legal.ok or options.is_empty())
func summary():
	var act=owner.flow.screen_state=="ACT_RESULT"
	var cleared=not act and int(owner.flow.run.act)==3 and not owner.flow.run.completed_nodes.is_empty() and owner.flow.run.completed_nodes.back().type=="boss"
	ui.open(owner.flow.screen_state,owner.t("ui.act_cleared" if act else "ui.run_cleared" if cleared else "ui.run_failed"))
	owner.label("⚑ "+str(owner.flow.run.completed_nodes.size())+"   ◉ "+str(owner.flow.run.gold),null,34)
	if act:ui.action(owner.popup_content,owner.t("ui.next_act"),func():owner.perform(owner.flow.next_act()))
	else:ui.action(owner.popup_content,owner.t("ui.new_run"),func():setup(Game.Mode.Unranked))
func craft(candidate: Dictionary):
	selected_recipe=candidate
	owner.menus.library.show_page("recipes")
func log_page(page: int = 0, full: bool = false):
	ui.open("COMBAT_LOG",ui.words("战斗记录","Battle record"))
	var tabs=ui.row();ui.action(tabs,ui.words("统计","Stats"),func():log_page(0,false),not full);ui.action(tabs,ui.words("事件","Events"),func():log_page(0,true),full)
	var result=owner._combat_log_result();var events:Array=result.get("full_events",[])
	if owner.flow.screen_state=="COMBAT_RUNNING":events=events.filter(func(e):return float(e.get("time",0))<=owner.flow.playback_time)
	var pages=maxi(1,int(ceil(events.size()/6.0)));page=clampi(page,0,pages-1)
	if full:
		var controls=ui.row();ui.symbol(controls,"previous",ui.words("上一页","Previous"),func():log_page(page-1,true)).disabled=page==0;owner.label(str(page+1)+" / "+str(pages),controls,26);ui.symbol(controls,"next",ui.words("下一页","Next"),func():log_page(page+1,true)).disabled=page+1>=pages
		for index in range(page*6,mini((page+1)*6,events.size())):ui.text_pages(owner.popup_content,owner.combat_event_text(events[index],result),1400,64,22)
	else:owner.statistics_controls(result)
