extends RefCounted
## Saved runs resume from their mode entrance. Only Begin replaces progress.
var owner
var ui
var role="armorer"
var loadout="armorer_blades"
var difficulty="tutorial"
var seed_value=0
var selected_recipe:Dictionary={}
var selection
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
	if selection == null: selection = preload("res://PvE/UI/SelectionLayout.gd").new(self)
	selection.show_page()

func confirm_new(new_role: String,new_loadout: String,new_difficulty: String,new_seed: int):
	role=new_role;loadout=new_loadout;seed_value=new_seed
	difficulty=new_difficulty
	var saved=owner.flow.saves.load_save("run")
	if saved.ok:entry_choice(saved.data)
	else:new_setup()
func result():
	preload("res://PvE/UI/LootLayout.gd").show_page(self)
func rewards():
	preload("res://PvE/UI/LootLayout.gd").show_page(self)
func pending_controls():
	for index in owner.flow.run.pending_rewards.size():
		var pending=owner.flow.run.pending_rewards[index]
		var row=ui.row();var icon=ui.picture(row,null,Vector2(100,100));owner.detail_views.fill_icon(weakref(icon),pending.definition_id,owner.popup_epoch)
		owner.label(owner.t(owner.flow.placement.definition(pending.definition_id).name_key),row,24)
		for action in ["place","storage","sell","discard"]:
			ui.action(row,owner.t("ui."+action),func():owner.perform(owner.flow.handle_pending(index,action)),action=="storage" and owner.flow.run.build.storage.size()>=int(owner.flow.run.build.storage_capacity))
func pending():ui.open("PENDING",ui.words("收纳战利品","Store rewards"));pending_controls()
func event():
	if owner.flow.screen_state=="REST":
		Sound.playBGM(Sound.postFightBGM_survival,-8)
		preload("res://PvE/UI/CampLayout.gd").show_page(self)
		return
	var model = owner.menus.new_journey_model()
	var event: Dictionary = model.snapshot().choice_page.event
	ui.open("EVENT",owner.t(event.title_key))
	owner.label(owner.t(event.description_key),null,24)
	var grid=ui.grid(owner.popup_content,2)
	populate_choices(grid,false,580,model)
func populate_choices(grid:Node,rest:bool,width:float=580,existing_model=null):
	var model = existing_model if existing_model != null else owner.menus.new_journey_model()
	var page: Dictionary = model.snapshot().choice_page
	var ticket: int = owner.popup_epoch
	for projected in page.get("choices",[]):
		var choice: Dictionary = projected.rule
		var column=ui.column(grid,width)
		owner.label(owner.t(str(choice.get("name_key" if rest else "text_key",""))),column,27)
		var options:Array=[{}];var names:Array=[]
		for effect in projected.effects:
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
		if options.is_empty():
			for effect in projected.effects:
				if float(owner.db.parse_params(effect.params).get("fallback_discount",0))>0:options=[{}]
		var selected={"index":0}
		if not names.is_empty():
			var select=ui.action(column,names[0],func():pass)
			select.pressed.connect(func():selected.index=(int(selected.index)+1)%names.size();select.text=names[selected.index])
		ui.action(column,owner.t("ui.confirm"),func():
			if ticket == owner.popup_epoch and not options.is_empty():
				model.choose_event_action(str(choice.id),options[selected.index]),not projected.requirements.ok or options.is_empty())
func summary():
	var act=owner.flow.screen_state=="ACT_RESULT"
	var cleared=not act and int(owner.flow.run.act)==3 and not owner.flow.run.completed_nodes.is_empty() and owner.flow.run.completed_nodes.back().type=="boss"
	ui.open(owner.flow.screen_state,owner.t("ui.act_cleared" if act else "ui.run_cleared" if cleared else "ui.run_failed"))
	owner.label("⚑ "+str(owner.flow.run.completed_nodes.size())+"   ◉ "+str(owner.flow.run.gold),null,34)
	if act:ui.action(owner.popup_content,owner.t("ui.next_act"),func():owner.perform(owner.flow.next_act()))
	else:
		owner.back_action = owner.return_to_title
		ui.action(owner.popup_content,ui.words("返回主页","Return home"),owner.return_to_title).name = "RunSummaryReturnHome"
		ui.action(owner.popup_content,owner.t("ui.new_run"),func():setup(Game.Mode.Unranked))
func craft(candidate: Dictionary):
	selected_recipe=candidate
	owner.menus.library.show_page("recipes")
func log_page(page: int = 0, full: bool = false):
	if not full:
		preload("res://PvE/UI/BattleStatsLayout.gd").show_page(self, owner.combat_log_vm.statistics())
		return
	ui.open("COMBAT_LOG", ui.words("战斗记录", "Battle record"))
	var tabs = ui.row()
	ui.action(tabs, ui.words("统计", "Stats"), func(): log_page(0, false), not full)
	ui.action(tabs, ui.words("事件", "Events"), func(): log_page(0, true), full)
	var projected: Dictionary = owner.combat_log_vm.events_page(page)
	var controls = ui.row()
	var previous = ui.symbol(controls, "previous", ui.words("上一页", "Previous"), func(): log_page(projected.page - 1, true))
	previous.name = "LogPrevious"
	previous.disabled = projected.page == 0
	owner.label(str(projected.page + 1) + " / " + str(projected.pages), controls, 26)
	var next = ui.symbol(controls, "next", ui.words("下一页", "Next"), func(): log_page(projected.page + 1, true))
	next.name = "LogNext"
	next.disabled = projected.page + 1 >= projected.pages
	for row in projected.rows:
		var deck = ui.text_pages(owner.popup_content, row.text, 1400, 64, 22)
		deck.label.set_meta("pve_combat_event_time", row.time)
