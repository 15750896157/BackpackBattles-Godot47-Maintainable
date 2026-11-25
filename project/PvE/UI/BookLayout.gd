extends RefCounted
## A two-page, read-only catalogue. Craft calls the existing explicit transaction.
const REF=preload("res://PvE/UI/ReferenceCanvas.gd")
const CODEX = preload("res://Code/Runtime/ViewModel/CodexVM.gd")
const PAGE_SIZE = CODEX.PAGE_SIZE
const CATEGORIES=[["items","造物录","Items"],["bags","行囊录","Bags"],["recipes","合成手札","Recipes"],["enemies","异闻录","Enemies"],["characters","英雄录","Heroes"],["rules","规则辞典","Rules"],["records","远征记录","Records"]]
const KEYS=["camp","book_cover","book_pages","bookmark_blue","bookmark_purple","bookmark_gold","bookmark_red","bookmark_green","button","button_blue","button_red","close","previous","next","book_entry","book_detail","badge_blue","badge_green","badge_gold","badge_purple","badge_red","result_reward_paper","recipe_row","recipe_detail","detail_title","entry","hero_description","bag_description"]
var owner
var ui
var category="items"
var query=""
var page=0
var only_seen=false
var only_available=false
var record_mode=0
var owner_filter="all"
var rarity_filter="all"
var tag_filter="all"
var rotation=0
var selection=""
var detail_entry:Dictionary={}
var listing:VBoxContainer
var detail:VBoxContainer
var root:Control
var body:Control
var matches:Array=[]
var blueprint:Control
var tabs:Dictionary={}
var model: CODEX

func _init(host, shell):
	owner = host
	ui = shell
	model = CODEX.new(host.flow, host.detail_views.rules, host.t, ui.words,
		host.detail_views.definition_text, host.detail_views.tag_name, CraftingManager.pve_candidates)
func show_page(section:String=""):
	if not section.is_empty() and section!=category:
		category=section;page=0;selection="";rotation=0;only_available=false;owner_filter="all";rarity_filter="all";tag_filter="all"
	owner.detail_views.category=category
	root=ui.open_canvas("CRAFTING" if category=="recipes" and can_craft() else "CODEX",ui.words("图鉴与合成","Collection & crafting"))
	var ticket=owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(KEYS),"popup") or ticket!=owner.popup_epoch:return
	REF.picture(root,"camp",Rect2(0,0,1920,1080),true)
	REF.picture(root,"book_cover",Rect2(127,80,1438,960),true)
	REF.picture(root,"book_pages",Rect2(163,116,1364,885),true)
	REF.button(root,"close",Rect2(1668,73,92,96),owner.view_return).name="CloseMenu"
	var colors=["blue","gold","green","red","purple","blue","gold"]
	tabs.clear()
	for index in CATEGORIES.size():
		var entry=CATEGORIES[index];var tab=REF.button(root,"bookmark_"+colors[index],Rect2(1505,148+index*82,168,72),func():switch_page(entry[0]),ui.words(entry[1],entry[2]),24)
		tab.name="BookTab_"+entry[0];tab.modulate=Color.WHITE if category==entry[0] else Color(0.78,0.78,0.78)
		tabs[entry[0]]=tab
	REF.text(root,ui.words("冒险者造物与异闻手记","Adventurer's field journal"),Rect2(206,142,620,52),31)
	body=Control.new();body.name="BookSpread";root.add_child(body)
	populate();REF.fade_in(root)
func can_craft() -> bool: return model.snapshot().can_craft
## 页签切换沿用角色选择页的过渡：整本书留在原地，只重画左右两页，
## 不再重建画布、也不整屏淡入。
func switch_page(section:String):
	if section==category:return
	category=section;page=0;selection="";rotation=0;detail_entry={}
	only_available=false;owner_filter="all";rarity_filter="all";tag_filter="all"
	owner.detail_views.category=category
	owner.current_page="CRAFTING" if category=="recipes" and can_craft() else "CODEX"
	refresh_tabs()
	populate()
func refresh_tabs():
	for key in tabs:
		var tab=tabs[key]
		if is_instance_valid(tab):tab.modulate=Color.WHITE if key==category else Color(0.78,0.78,0.78)
func cycle_filter(key:String,values:Array):
	var value=get(key);set(key,values[(values.find(value)+1)%values.size()]);page=0;selection="";populate()
func filter_button(caption:String,rect:Rect2,callback:Callable,name:String):
	var button=REF.button(body,"button",rect,callback,caption,20);button.name=name
	for label in button.get_children():
		if label is Label:label.add_theme_color_override("font_color",REF.INK);label.add_theme_constant_override("outline_size",0)
func populate():
	if not is_instance_valid(body) or not body.is_inside_tree():return
	ui.clear(body);owner.popup_epoch+=1;owner.bindings.texture_cache.clear()
	# Keep only this sheet's frame, then request its visible thumbnails. Previous
	# pages cancel through the same revision/epoch guards as every other popup.
	AssetStream.hold(REF.paths(KEYS),"popup")
	if category in ["rules","records"]:other_pages();return
	var requested_recipe := str(owner.menus.runs.selected_recipe.get("recipe_id", "")) if category == "recipes" else ""
	var result := model.catalogue(category, {
		"seen": only_seen, "available": only_available, "pool": owner_filter,
		"rarity": rarity_filter, "tag": tag_filter, "query": query,
	}, page, selection, requested_recipe)
	if not requested_recipe.is_empty():
		owner.menus.runs.selected_recipe = {}
	matches = result.matches
	page = result.page
	owner_filter = result.pool
	var selected: Dictionary = result.selected
	if not selected.is_empty():
		selection = selected.id
	filters()
	var use_rows: bool = category in ["bags","recipes"]
	for index: int in result.visible.size():
		var entry: Dictionary = result.visible[index]
		var column := index % 2
		var y := 288 + (index / 2) * 290
		var card=Button.new();card.position=Vector2(207+column*316,y);card.size=Vector2(304,282);card.name="BookEntry_"+entry.id;card.set_meta("definition_id",entry.id)
		if use_rows:
			card.position = Vector2(207,288 + index*144)
			card.size = Vector2(620,134)
		var normal:=StyleBoxFlat.new()
		normal.bg_color=Color(0.97,0.89,0.71,0.96)
		normal.set_corner_radius_all(10)
		normal.set_border_width_all(2)
		normal.border_color=Color(0.45,0.32,0.18,0.55)
		var hover:=normal.duplicate() as StyleBoxFlat;hover.bg_color=Color(1.0,0.95,0.80,0.98);hover.border_color=Color(0.66,0.46,0.18,0.75)
		var highlighted:=normal.duplicate() as StyleBoxFlat;highlighted.bg_color=Color(1.0,0.94,0.76,1.0);highlighted.set_border_width_all(3);highlighted.border_color=Color(0.78,0.54,0.18,0.95)
		var focus:=normal.duplicate() as StyleBoxFlat;focus.border_color=Color(0.78,0.54,0.18,0.8)
		card.add_theme_stylebox_override("normal",highlighted if entry.id==selection else normal)
		card.add_theme_stylebox_override("hover",hover)
		card.add_theme_stylebox_override("pressed",highlighted)
		card.add_theme_stylebox_override("focus",focus)
		card.add_theme_stylebox_override("disabled",normal)
		body.add_child(card);card.pressed.connect(func():selection=entry.id;rotation=0;populate())
		var image=ui.picture(card,null,Vector2.ZERO);image.position=Vector2(63,91);image.size=Vector2(178,145)
		image.name = "BookEntryIcon"
		if use_rows:
			image.position = Vector2(440,9)
			image.size = Vector2(156,116)
		if category=="enemies":image.texture=owner.menus.journey.portrait(enemy_node(entry.data))
		elif category=="characters":owner.detail_views.fill_picture(weakref(image),REF.path("select_"+str(entry.id)),owner.popup_epoch)
		else:owner.detail_views.fill_icon(weakref(image),entry.id,owner.popup_epoch)
		if not entry.known:image.modulate=Color(0.16,0.14,0.11)
		if entry.known: draw_badge(card,entry)
		var title=REF.text(card,entry.title,Rect2(16,48,410 if use_rows else 272,39),25)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if use_rows: title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		REF.text(card, model.subtitle(category, entry), Rect2(12,91 if use_rows else 241,414 if use_rows else 280,32),20,Color("70502f")).horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	page_buttons(body, result.count, populate)
	if not selected.is_empty():show_detail(selected)
	else:REF.text(body,ui.words("暂无符合条件的内容","No matching entries"),Rect2(938,440,540,150),28)
func filters():
	if category=="characters":
		REF.text(body,ui.words("英雄 · 旅途伙伴","Heroes · Expedition companions"),Rect2(207,198,620,54),27)
		return
	filter_bar(Rect2(203,198,628,52))
	var context := model.snapshot()
	var pools: Array = context.pools
	segment_button(ui.words("已发现" if only_seen else "全部条目","Discovered" if only_seen else "All entries"),Rect2(207,202,152,44),func():only_seen=not only_seen;only_available=false;page=0;populate(),"BookSeenFilter",only_seen)
	var pool_caption: String = ui.words("归属·全部","Pool·All") if owner_filter=="all" else ui.words("归属·公共","Pool·Public") if owner_filter=="public" else ui.words("归属·","Pool·")+owner.t("character."+owner_filter+".name")
	segment_button(pool_caption,Rect2(363,202,152,44),func():cycle_filter("owner_filter",pools),"BookPoolFilter",owner_filter!="all")
	var rarity_caption: String = ui.words("稀有·不限","Rarity·Any") if rarity_filter=="all" else ui.words("稀有·","Rarity·")+owner.t("rarity."+rarity_filter+".name")
	segment_button(rarity_caption,Rect2(519,202,152,44),func():cycle_filter("rarity_filter",["all","common","rare","legendary"]),"BookRarityFilter",rarity_filter!="all")
	var tag_ids: Array = context.tags
	var tag_caption: String = ui.words("标签·全部","Tag·All") if tag_filter=="all" else ui.words("标签·","Tag·")+owner.detail_views.tag_name(tag_filter)
	segment_button(tag_caption,Rect2(675,202,152,44),func():cycle_filter("tag_filter",tag_ids),"BookTagFilter",tag_filter!="all")
	var hint := ""
	if category in ["items","bags"]:hint=ui.words("点卡片查看详情 · 滚轮 / Q / E 旋转蓝图","Tap a card for details · Wheel / Q / E rotates")
	elif category=="recipes":hint=ui.words("点配方查看材料 · 选中后点「确认合成」","Pick a recipe · then confirm to craft")
	if not hint.is_empty():REF.text(body,hint,Rect2(207,254,620,28),20,Color("6b4a2d"))
	if category=="recipes" and can_craft():
		filter_button(ui.words("只看可合成" if not only_available else "查看全部","Craftable only" if not only_available else "All recipes"),Rect2(1070,887,300,56),func():only_available=not only_available;page=0;populate(),"BookCraftableFilter")
func filter_bar(rect:Rect2):
	var bar=Panel.new();bar.name="BookFilterBar";bar.position=rect.position;bar.size=rect.size
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new()
	style.bg_color=Color(0.36,0.25,0.13,0.13)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color=Color(0.42,0.30,0.16,0.25)
	bar.add_theme_stylebox_override("panel",style)
	body.add_child(bar)
func segment_button(caption:String,rect:Rect2,callback:Callable,name:String,active:bool):
	var button=Button.new();button.name=name;button.text=caption
	button.position=rect.position;button.size=rect.size
	button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode=Control.FOCUS_ALL
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",Expedition.ui_font)
	button.add_theme_font_size_override("font_size",20)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(key,REF.INK)
	var normal=StyleBoxFlat.new()
	normal.bg_color=Color(0.94,0.83,0.60,0.92) if active else Color(1,1,1,0.22)
	normal.set_corner_radius_all(9)
	normal.set_border_width_all(1)
	normal.border_color=Color(0.47,0.34,0.19,0.45 if active else 0.20)
	var hover=normal.duplicate() as StyleBoxFlat;hover.bg_color=Color(0.97,0.90,0.72,0.95);hover.border_color=Color(0.47,0.34,0.19,0.5)
	var pressed=normal.duplicate() as StyleBoxFlat;pressed.bg_color=Color(0.88,0.75,0.51,0.95)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("focus",normal)
	button.add_theme_stylebox_override("disabled",normal)
	button.pressed.connect(callback)
	body.add_child(button)
	return button
func page_buttons(parent:Node,count:int,callback:Callable):
	var previous=REF.button(parent,"previous",Rect2(341,920,64,54),func():page=maxi(0,page-1);selection="";callback.call());previous.name="ListPrevious";previous.disabled=page==0
	REF.text(parent,str(page+1)+" / "+str(count),Rect2(413,920,160,54),24)
	var next=REF.button(parent,"next",Rect2(581,920,64,54),func():page=mini(count-1,page+1);selection="";callback.call());next.name="ListNext";next.disabled=page+1>=count
func rotate_blueprint(clockwise:bool)->bool:
	if category not in ["items","bags"] or selection.is_empty() or detail_entry.is_empty():return false
	if not is_instance_valid(blueprint) or blueprint.cells.is_empty():return false
	rotation=posmod(rotation+(90 if clockwise else -90),360)
	Sound.playSound(load("res://Audio/Sound/Grind.wav"),-6)
	blueprint.spin(clockwise,refresh_blueprint)
	return true
## 只刷新蓝图本身，避免整页重建打断阅读。
func refresh_blueprint():
	if not is_instance_valid(blueprint) or detail_entry.is_empty():return
	var projected := model.detail(category,detail_entry,rotation)
	blueprint.configure(detail_entry.id,rotation,detail_entry.known,projected.cells,projected.effects)
	blueprint.fill_art(detail_entry.id,owner.popup_epoch,projected.base_cells)
func make_column(rect:Rect2)->VBoxContainer:
	var result=VBoxContainer.new();result.position=rect.position;result.size=rect.size;body.add_child(result);return result
func show_detail(entry:Dictionary):
	detail_entry=entry
	if category=="enemies":
		var portrait: TextureRect = ui.picture(body,owner.menus.journey.portrait(enemy_node(entry.data)),Vector2.ZERO)
		portrait.position=Vector2(1002,233);portrait.size=Vector2(389,371)
		if not entry.known:portrait.modulate=Color(0.12,0.10,0.08)
		REF.picture(body,"detail_title",Rect2(913,181,400,54),true)
		REF.text(body,entry.title,Rect2(922,181,390,54),32)
		REF.picture(body,"hero_description",Rect2(924,711,553,151),true)
		detail=make_column(Rect2(937,724,524,123))
		if entry.known:
			var snapshot: Dictionary = owner.detail_views.enemy_snapshot(enemy_node(entry.data))
			if snapshot.get("ok",false):REF.text(body,"HP  %s   ◆  %s" % [snapshot.base_stats.max_health,snapshot.base_stats.stamina_max],Rect2(932,650,533,50),25)
			ui.text_pages(detail,owner.menus.journey.ability_text(enemy_node(entry.data)),514,118,21)
		else:ui.text_pages(detail,ui.words("在远征中遭遇后记录","Recorded after an encounter"),514,118,24)
		return
	if category=="characters":
		var portrait: TextureRect = ui.picture(body,null,Vector2.ZERO)
		portrait.position=Vector2(1002,204)
		portrait.size=Vector2(389,432)
		owner.detail_views.fill_picture(weakref(portrait),REF.path("select_"+str(entry.id)),owner.popup_epoch)
		REF.text(body,entry.title,Rect2(940,646,520,56),34)
		REF.picture(body,"hero_description",Rect2(924,711,553,151),true)
		REF.text(body,"HP  %s   ◆  %s" % [entry.data.max_health,entry.data.stamina_max],Rect2(940,720,520,43),24)
		detail=make_column(Rect2(937,778,524,72))
		ui.text_pages(detail,owner.t(entry.data.description_key),514,68,22)
		return
	REF.text(body,entry.title,Rect2(916,153,580,59),34)
	var projected := model.detail(category, entry, rotation)
	if category=="recipes":
		REF.picture(body,"recipe_detail",Rect2(901,282,593,297),true)
		detail=make_column(Rect2(927,616,565,230))
		ui.text_pages(detail,projected.description,555,210,23)
		if entry.known:
			craft_detail(entry,projected.ingredients)
		return
	REF.picture(body,"bag_description",Rect2(906,229,593,656),true)
	REF.text(body,ui.words("占格与作用范围蓝图","Footprint & effect blueprint"),Rect2(926,236,300,30),20,Color("7a5736"))
	REF.text(body,ui.words("滚轮 / Q / E 旋转","Wheel / Q / E to rotate"),Rect2(1180,236,300,30),20,Color("7a5736"))
	blueprint=preload("res://PvE/UI/Blueprint.gd").new();blueprint.position=Vector2(970,287);blueprint.size=Vector2(420,320);body.add_child(blueprint)
	blueprint.configure(entry.id, rotation, entry.known, projected.cells, projected.effects)
	blueprint.fill_art(entry.id, owner.popup_epoch, projected.base_cells)
	var rarity_name: String = owner.t("rarity."+str(entry.definition.get("rarity","common"))+".name") if entry.known else ui.words("未发现","Unknown")
	var price_text: String = ("%d" % int(entry.definition.get("base_price",0))) if entry.known else "—"
	info_chip(Rect2(917,614,180,60),ui.words("稀有度","Rarity"),rarity_name)
	info_chip(Rect2(1112,614,180,60),ui.words("占用格数","Cells"),"%d %s" % [projected.cells.size(),ui.words("格","cells")])
	info_chip(Rect2(1307,614,180,60),ui.words("基础价格","Base price"),price_text)
	detail=make_column(Rect2(927,690,565,120))
	ui.text_pages(detail, projected.description, 555, 110 if entry.known else 118, 22)

func info_chip(rect:Rect2,caption:String,value:String):
	var chip=Panel.new();chip.position=rect.position;chip.size=rect.size
	chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new()
	style.bg_color=Color(0.97,0.90,0.72,0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color=Color(0.47,0.34,0.19,0.40)
	chip.add_theme_stylebox_override("panel",style)
	body.add_child(chip)
	REF.text(chip,caption,Rect2(4,4,rect.size.x-8,24),20,Color("7a5736"))
	REF.text(chip,value,Rect2(4,27,rect.size.x-8,30),24,REF.INK)

func draw_badge(card: Control, entry: Dictionary) -> void:
	var caption: String
	var key := "badge_gold"
	if category == "enemies":
		var boss: bool = entry.data.has("persistent_rule_id")
		key = "badge_red" if boss else "badge_blue"
		caption = ui.words("首领","Boss") if boss else ui.words("敌人","Enemy")
	elif category == "characters":
		caption = ui.words("英雄","Hero")
	else:
		var rarity := str(entry.definition.get("rarity","common"))
		key = "badge_green" if not entry.candidate.is_empty() else "badge_purple" if rarity == "legendary" else "badge_blue" if rarity == "rare" else "badge_gold"
		caption = owner.t("rarity."+rarity+".name")
	var extent := Rect2(13,10,116,37)
	REF.picture(card,key,extent,true)
	REF.text(card,caption,extent,19,Color("fff7d6") if key in ["badge_red","badge_purple"] else REF.INK)

func craft_detail(entry: Dictionary, ingredients: Array):
	var epoch: int = owner.popup_epoch
	var ids := ingredients.duplicate()
	ids.append(entry.id)
	var card_width := 540.0 / ids.size() - 12.0
	for index in ids.size():
		var card := REF.picture(body,"result_reward_paper",Rect2(931+index*(card_width+12),282,card_width,276),true)
		var icon: TextureRect = ui.picture(card,null,Vector2.ZERO)
		icon.position = Vector2(9,51)
		icon.size = Vector2(card_width-18,135)
		owner.detail_views.fill_icon(weakref(icon),ids[index],epoch)
		var result: bool = index == ingredients.size()
		var caption: String = ui.words("合成产物","Result") if result else ui.words("材料 %d","Material %d") % (index+1)
		REF.text(card,caption,Rect2(4,13,card_width-8,35),22)
		var definition: Dictionary = owner.flow.placement.definition(ids[index])
		REF.text(card,owner.t(definition.get("name_key",ids[index])),Rect2(7,205,card_width-14,42),22)
	var candidate: Dictionary = entry.candidate
	if candidate.is_empty():
		return
	var craft = REF.button(body, "button_red", Rect2(1138,931,300,58), func():
		if epoch != owner.popup_epoch:
			return
		var result := model.craft(candidate)
		owner.menus.runs.selected_recipe = {}
		owner.perform(result)
		if result.ok:
			Sound.playSound(load("res://Audio/Sound/Craft.ogg"), -8)
			show_page("recipes"), ui.words("确认合成", "Confirm craft"), 26)
	craft.name = "BookConfirmCraft"
	craft.disabled = not bool(candidate.get("preview_ok", false))

func enemy_node(data:Dictionary)->Dictionary:return {"type":"boss" if data.has("persistent_rule_id") else "normal_combat","boss_id":data.id if data.has("persistent_rule_id") else "","enemy_id":data.id,"affix_id":data.get("affix_id","")}
func other_pages():
	listing = make_column(Rect2(217,281,600,580))
	detail = make_column(Rect2(927,268,565,580))
	if category == "rules":
		var projected := model.rules_page(page)
		page = projected.page
		if not projected.rule.is_empty():
			owner.label(str(projected.rule.term), listing, 31)
			ui.text_pages(listing, str(projected.rule.definition), 590, 400, 25)
		page_buttons(body, projected.count, populate)
		if not projected.affixes.is_empty():
			ui.text_pages(detail, "\n\n".join(projected.affixes), 555, 420, 23)
	else:
		var projected := model.records_page(record_mode, page)
		page = projected.page
		segment_button(ui.words("成就" if record_mode==0 else "历程","Achievements" if record_mode==0 else "History"),
			Rect2(207,198,270,48), func(): record_mode=1-record_mode;page=0;populate(), "BookRecordMode", true)
		for line in projected.rows:
			owner.label(line, listing, 24)
		page_buttons(body, projected.count, populate)
		for line in projected.stars:
			owner.label(line, detail, 26)
		ui.action(detail, ui.words("战斗记录", "Battle record"), owner.show_combat_log)
